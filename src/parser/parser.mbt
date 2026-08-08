///|
fn parse_file_meta(
  reader : @byteio.ByteReader,
  state : ParseState,
) -> @model.DataSet raise @model.MedSealError {
  let elements : Array[@model.DataElement] = []
  while reader.remaining() >= 4 {
    let saved = reader.position()
    let group = reader.read_u16_le()
    reader.seek(saved)
    if group != 0x0002U {
      break
    }
    elements.push(parse_element(reader, state, 0))
  }
  @model.DataSet::new(elements)
}

///|
fn transfer_syntax_of(file_meta : @model.DataSet) -> String {
  match file_meta.find(@model.transfer_syntax_uid_tag) {
    Some(element) =>
      match element.value {
        @model.ElementValue::Text(value) => value
        _ => ""
      }
    None => ""
  }
}

///|
pub fn parse(data : Bytes) -> ParsedFile raise @model.MedSealError {
  if data.length() > 256 * 1024 * 1024 {
    raise @model.MedSealError::FileTooLarge(data.length())
  }
  check_preamble(data)
  let preamble = data[0:128].to_owned()
  let reader = @byteio.ByteReader::new(data)
  reader.skip(132)
  let state : ParseState = { count: 0 }
  let file_meta = parse_file_meta(reader, state)
  let transfer_syntax = transfer_syntax_of(file_meta)
  if transfer_syntax != explicit_vr_little_endian_uid {
    raise @model.MedSealError::UnsupportedTransferSyntax(transfer_syntax)
  }
  let dataset = parse_dataset_to_end(reader, state, 0, reader.length())
  { preamble, file_meta, dataset, transfer_syntax, element_count: state.count }
}

///|
pub fn parse_dataset_bytes(
  data : Bytes,
) -> @model.DataSet raise @model.MedSealError {
  let reader = @byteio.ByteReader::new(data)
  let state : ParseState = { count: 0 }
  parse_dataset_to_end(reader, state, 0, reader.length())
}
