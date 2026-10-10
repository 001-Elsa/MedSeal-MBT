///|
test "read u8, u16 and u32 little endian" {
  let reader = @byteio.ByteReader::new(b"\x01\x02\x03\x04\x05\x06\x07")
  assert_eq(reader.read_u8(), 1U)
  assert_eq(reader.read_u16_le(), 0x0302U)
  assert_eq(reader.read_u32_le(), 0x07060504U)
  assert_eq(reader.remaining(), 0)
}

///|
test "zero length read does not move cursor" {
  let reader = @byteio.ByteReader::new(b"abc")
  assert_eq(reader.read_bytes(0), b"")
  assert_eq(reader.position(), 0)
}

///|
test "out of bounds read is structured" {
  let reader = @byteio.ByteReader::new(b"\x01")
  let structured = try {
    ignore(reader.read_u16_le())
    false
  } catch {
    @model.MedSealError::UnexpectedEndOfFile(0) => true
    _ => false
  }
  assert_true(structured)
}

///|
test "failed reads leave the cursor unchanged" {
  let reader = @byteio.ByteReader::new(b"\x01\x02\x03")
  assert_eq(reader.read_u8(), 1U)
  let rejected = try {
    ignore(reader.read_u32_le())
    false
  } catch {
    @model.MedSealError::UnexpectedEndOfFile(1) => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(reader.position(), 1)
  assert_eq(reader.remaining(), 2)
}

///|
test "read_bytes can consume exactly to end of input" {
  let reader = @byteio.ByteReader::new(b"abcdef")
  assert_eq(reader.read_bytes(6), b"abcdef")
  assert_eq(reader.position(), 6)
  assert_eq(reader.remaining(), 0)
}

///|
test "negative read and skip lengths are rejected" {
  let reader = @byteio.ByteReader::new(b"abc")
  let read_rejected = try {
    ignore(reader.read_bytes(-1))
    false
  } catch {
    @model.MedSealError::UnexpectedEndOfFile(0) => true
    _ => false
  }
  let skip_rejected = try {
    reader.skip(-1)
    false
  } catch {
    @model.MedSealError::UnexpectedEndOfFile(0) => true
    _ => false
  }
  assert_true(read_rejected)
  assert_true(skip_rejected)
  assert_eq(reader.position(), 0)
}

///|
test "seek accepts boundaries and rejects positions outside the buffer" {
  let reader = @byteio.ByteReader::new(b"abcd")
  reader.seek(4)
  assert_eq(reader.remaining(), 0)
  reader.seek(0)
  assert_eq(reader.read_u8(), 0x61U)
  let negative = try {
    reader.seek(-1)
    false
  } catch {
    @model.MedSealError::UnexpectedEndOfFile(1) => true
    _ => false
  }
  let beyond = try {
    reader.seek(5)
    false
  } catch {
    @model.MedSealError::UnexpectedEndOfFile(1) => true
    _ => false
  }
  assert_true(negative)
  assert_true(beyond)
  assert_eq(reader.position(), 1)
}

///|
test "peek reads without moving and reports end of input" {
  let reader = @byteio.ByteReader::new(b"\x34\x12\xff")
  assert_eq(reader.peek_u16_le(), 0x1234U)
  assert_eq(reader.position(), 0)
  reader.skip(2)
  let rejected = try {
    ignore(reader.peek_u16_le())
    false
  } catch {
    @model.MedSealError::UnexpectedEndOfFile(2) => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(reader.position(), 2)
}

///|
test "little endian reads preserve unsigned high bits" {
  let reader = @byteio.ByteReader::new(b"\xff\xff\xff\xff\xff\xff")
  assert_eq(reader.read_u16_le(), 0xFFFFU)
  assert_eq(reader.read_u32_le(), 0xFFFFFFFFU)
}
