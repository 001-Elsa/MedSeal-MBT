///|
fn write_meta_group_length(writer : @byteio.ByteWriter, length : Int) -> Unit {
  writer.write_u16_le(0x0002U)
  writer.write_u16_le(0x0000U)
  writer.write_ascii("UL")
  writer.write_u16_le(4U)
  writer.write_u32_le(length.reinterpret_as_uint())
}

///|
fn encode_file_meta(
  file_meta : @model.DataSet,
) -> Bytes raise @model.MedSealError {
  let rest = @byteio.ByteWriter::new()
  for element in file_meta.elements {
    if element.tag != @model.Tag::new(0x0002U, 0x0000U) {
      write_element(rest, element)
    }
  }
  let rest_bytes = rest.to_bytes()
  let output = @byteio.ByteWriter::new()
  write_meta_group_length(output, rest_bytes.length())
  output.write_bytes(rest_bytes)
  output.to_bytes()
}

///|
pub fn write_bytes(
  parsed : @parser.ParsedFile,
  dataset? : @model.DataSet = parsed.dataset,
) -> Bytes raise @model.MedSealError {
  let count = [0]
  let size = 132 +
    encoded_size(parsed.file_meta, 0, count) +
    encoded_size(dataset, 0, count)
  if size > 256 * 1024 * 1024 {
    raise @model.MedSealError::InvalidModel("file exceeds 256 MiB")
  }
  let writer = @byteio.ByteWriter::new()
  if parsed.preamble.length() == 128 {
    writer.write_bytes(parsed.preamble)
  } else {
    writer.write_bytes(Bytes::make(128, b'\x00'))
  }
  writer.write_ascii("DICM")
  writer.write_bytes(encode_file_meta(parsed.file_meta))
  writer.write_bytes(encode_dataset(dataset))
  writer.to_bytes()
}
