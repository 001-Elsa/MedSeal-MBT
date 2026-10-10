///|
fn encode_dataset(dataset : @model.DataSet) -> Bytes raise @model.MedSealError {
  let writer = @byteio.ByteWriter::new()
  for element in dataset.elements {
    write_element(writer, element)
  }
  writer.to_bytes()
}

///|
fn encode_sequence(
  items : Array[@model.DataSet],
) -> Bytes raise @model.MedSealError {
  let writer = @byteio.ByteWriter::new()
  for item in items {
    let bytes = encode_dataset(item)
    writer.write_u16_le(0xFFFEU)
    writer.write_u16_le(0xE000U)
    writer.write_u32_le(bytes.length().reinterpret_as_uint())
    writer.write_bytes(bytes)
  }
  writer.to_bytes()
}
