///|
fn sop_identity(
  dataset : @dicom.DataSet,
  element : UInt,
) -> String raise @dicom.MedSealError {
  match dataset.find(@dicom.Tag::new(0x0008U, element)) {
    Some({ vr: @dicom.Vr::UI, value: @dicom.ElementValue::Text(uid), .. }) if !uid.is_empty() &&
      uid.length() <= 64 &&
      !uid.contains("\\") &&
      uid
      .split(".")
      .all(part => {
        !part.is_empty() &&
        part.all(c => c >= '0' && c <= '9') &&
        (part.length() == 1 || !part.has_prefix("0"))
      }) => uid
    _ => raise invalid("Part 10 requires scalar SOP Class and Instance UIDs")
  }
}

///|
/// Wrap one JSON Dataset in a fresh Explicit VR Little Endian Part 10 file.
/// Preserves private values. This does not de-identify or validate the IOD.
pub fn to_part10(text : String) -> Bytes raise @dicom.MedSealError {
  let dataset = decode(text)
  let sop_class = sop_identity(dataset, 0x0016U)
  let sop_instance = sop_identity(dataset, 0x0018U)
  fn meta(element : UInt, value : String) -> @dicom.DataElement {
    @dicom.DataElement::new(
      @dicom.Tag::new(0x0002U, element),
      @dicom.Vr::UI,
      0U,
      @dicom.ElementValue::Text(value),
      0,
    )
  }
  let file : @dicom.ParsedFile = {
    preamble: Bytes::make(128, b'\x00'),
    file_meta: @dicom.DataSet::new([
      @dicom.DataElement::new(
        @dicom.Tag::new(0x0002U, 0x0001U),
        @dicom.Vr::OB,
        2U,
        @dicom.ElementValue::Raw(b"\x00\x01"),
        0,
      ),
      meta(0x0002U, sop_class),
      meta(0x0003U, sop_instance),
      meta(0x0010U, "1.2.840.10008.1.2.1"),
      meta(0x0012U, "2.25.329800735698586629295641978511506172928"),
    ]),
    dataset,
    transfer_syntax: "1.2.840.10008.1.2.1",
    element_count: dataset.count_recursive(),
  }
  let bytes = @dicom.write(file)
  // Reuse the actual parser's charset, length and structural checks. A JSON
  // string never implicitly selects a source binary character set.
  ignore(@dicom.parse(bytes))
  bytes
}
