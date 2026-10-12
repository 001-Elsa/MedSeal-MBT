///|
/// Terminal native Pixel Data; metadata is parsed without allocating its value.
pub(all) struct PixelSpan {
  parsed : ParsedFile
  offset : Int
  length : Int
  vr : @model.Vr
}

///|
pub fn index_pixel_prefix(
  prefix : Bytes,
  file_size : Int64,
) -> PixelSpan raise @model.MedSealError {
  if file_size > 256L * 1024L * 1024L || prefix.length() > 2 * 1024 * 1024 {
    raise @model.MedSealError::InvalidArgument(
      "streaming file or metadata budget exceeded",
    )
  }
  check_preamble(prefix)
  let reader = @byteio.ByteReader::new(prefix)
  reader.skip(132)
  let state : ParseState = { count: 0, }
  let file_meta = parse_file_meta(reader, state)
  validate_file_meta(file_meta)
  let transfer_syntax = transfer_syntax_of(file_meta)
  if transfer_syntax != explicit_vr_little_endian_uid {
    raise @model.MedSealError::UnsupportedTransferSyntax(transfer_syntax)
  }
  let elements : Array[@model.DataElement] = []
  while reader.remaining() >= 12 {
    let saved = reader.position()
    let found = read_tag(reader)
    if found == @model.Tag::new(0x7FE0U, 0x0010U) {
      let vr = read_vr(reader)
      let length = read_length(reader, vr)
      if ![@model.Vr::OB, @model.Vr::OW].contains(vr) ||
        length == 0U ||
        length > 128U * 1024U * 1024U ||
        length % 2U != 0U ||
        reader.position().to_int64() + length.to_int64() != file_size {
        raise @model.MedSealError::InvalidArgument(
          "streaming requires terminal finite OB/OW Pixel Data",
        )
      }
      let dataset = @model.DataSet::new(elements)
      check_character_set(file_meta, "")
      check_character_set(dataset, "")
      let parsed : ParsedFile = {
        preamble: prefix[0:128].to_owned(),
        file_meta,
        dataset,
        transfer_syntax,
        element_count: state.count + 1,
      }
      return {
        parsed,
        offset: reader.position(),
        length: length.reinterpret_as_int(),
        vr,
      }
    }
    reader.seek(saved)
    elements.push(parse_element(reader, state, 0))
  }
  raise @model.MedSealError::InvalidArgument(
    "Pixel Data not found within bounded metadata prefix",
  )
}
