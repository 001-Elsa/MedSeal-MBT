///|
fn meta_text(
  tag : @model.Tag,
  value : String,
  vr? : @model.Vr = @model.Vr::UI,
) -> @model.DataElement {
  @model.DataElement::new(tag, vr, 0U, @model.ElementValue::Text(value), 0)
}

///|
fn identity_value(
  dataset : @model.DataSet,
  meta : @model.DataSet,
  tag : @model.Tag,
  meta_tag : @model.Tag,
) -> String raise @model.MedSealError {
  let element = match dataset.find(tag) {
    Some(element) => Some(element)
    None => meta.find(meta_tag)
  }
  match element {
    Some(element) =>
      match element.value {
        @model.ElementValue::Text(value) if !value.is_empty() => value
        _ => raise @model.MedSealError::InvalidModel("missing SOP identity")
      }
    None => raise @model.MedSealError::InvalidModel("missing SOP identity")
  }
}

///|
// A de-identifying write reconstructs File Meta rather than retaining source
// application identifiers, private information or the source preamble.
pub fn write_deidentified(
  parsed : @parser.ParsedFile,
  dataset : @model.DataSet,
) -> Bytes raise @model.MedSealError {
  let sop_class = identity_value(
    dataset,
    parsed.file_meta,
    @model.Tag::new(0x0008U, 0x0016U),
    @model.Tag::new(0x0002U, 0x0002U),
  )
  let sop_instance = identity_value(
    dataset,
    parsed.file_meta,
    @model.Tag::new(0x0008U, 0x0018U),
    @model.Tag::new(0x0002U, 0x0003U),
  )
  let file_meta = @model.DataSet::new([
    @model.DataElement::new(
      @model.Tag::new(0x0002U, 0x0001U),
      @model.Vr::OB,
      2U,
      @model.ElementValue::Raw(b"\x00\x01"),
      0,
    ),
    meta_text(@model.Tag::new(0x0002U, 0x0002U), sop_class),
    meta_text(@model.Tag::new(0x0002U, 0x0003U), sop_instance),
    meta_text(
      @model.transfer_syntax_uid_tag, @parser.explicit_vr_little_endian_uid,
    ),
    meta_text(
      @model.Tag::new(0x0002U, 0x0012U),
      "2.25.329800735698586629295641978511506172928",
    ),
    meta_text(
      @model.Tag::new(0x0002U, 0x0013U),
      "MEDSEAL_020",
      vr=@model.Vr::SH,
    ),
  ])
  let clean : @parser.ParsedFile = {
    ..parsed,
    preamble: Bytes::make(128, b'\x00'),
    file_meta,
    dataset,
  }
  write_bytes(clean)
}
