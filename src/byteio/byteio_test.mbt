///|
test "read u8, u16 and u32 little endian" {
  let reader = ByteReader::new(b"\x01\x02\x03\x04\x05\x06\x07")
  assert_eq(reader.read_u8(), 1U)
  assert_eq(reader.read_u16_le(), 0x0302U)
  assert_eq(reader.read_u32_le(), 0x07060504U)
  assert_eq(reader.remaining(), 0)
}

///|
test "zero length read does not move cursor" {
  let reader = ByteReader::new(b"abc")
  assert_eq(reader.read_bytes(0), b"")
  assert_eq(reader.position(), 0)
}

///|
test "out of bounds read is structured" {
  let reader = ByteReader::new(b"\x01")
  let structured = try {
    ignore(reader.read_u16_le())
    false
  } catch {
    @model.MedSealError::UnexpectedEndOfFile(0) => true
    _ => false
  }
  assert_true(structured)
}
