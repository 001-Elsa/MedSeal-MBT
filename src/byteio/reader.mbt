///|
pub struct ByteReader {
  data : Bytes
  mut position_ : Int
}

///|
pub fn ByteReader::new(data : Bytes) -> ByteReader {
  { data, position_: 0 }
}

///|
pub fn ByteReader::remaining(self : ByteReader) -> Int {
  self.data.length() - self.position_
}

///|
pub fn ByteReader::position(self : ByteReader) -> Int {
  self.position_
}

///|
pub fn ByteReader::length(self : ByteReader) -> Int {
  self.data.length()
}

///|
pub fn ByteReader::seek(
  self : ByteReader,
  position : Int,
) -> Unit raise @model.MedSealError {
  if position < 0 || position > self.data.length() {
    raise @model.MedSealError::UnexpectedEndOfFile(self.position_)
  }
  self.position_ = position
}

///|
fn ByteReader::ensure(
  self : ByteReader,
  length : Int,
) -> Unit raise @model.MedSealError {
  if length < 0 || length > self.remaining() {
    raise @model.MedSealError::UnexpectedEndOfFile(self.position_)
  }
}

///|
pub fn ByteReader::read_u8(self : ByteReader) -> UInt raise @model.MedSealError {
  self.ensure(1)
  let result = self.data[self.position_].to_uint()
  self.position_ = self.position_ + 1
  result
}

///|
pub fn ByteReader::read_u16_le(
  self : ByteReader,
) -> UInt raise @model.MedSealError {
  self.ensure(2)
  let low = self.data[self.position_].to_uint()
  let high = self.data[self.position_ + 1].to_uint()
  self.position_ = self.position_ + 2
  low | (high << 8)
}

///|
pub fn ByteReader::read_u32_le(
  self : ByteReader,
) -> UInt raise @model.MedSealError {
  self.ensure(4)
  let b0 = self.data[self.position_].to_uint()
  let b1 = self.data[self.position_ + 1].to_uint()
  let b2 = self.data[self.position_ + 2].to_uint()
  let b3 = self.data[self.position_ + 3].to_uint()
  self.position_ = self.position_ + 4
  b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
}

///|
pub fn ByteReader::read_bytes(
  self : ByteReader,
  length : Int,
) -> Bytes raise @model.MedSealError {
  self.ensure(length)
  let start = self.position_
  self.position_ = self.position_ + length
  self.data[start:self.position_].to_owned()
}

///|
pub fn ByteReader::skip(
  self : ByteReader,
  length : Int,
) -> Unit raise @model.MedSealError {
  self.ensure(length)
  self.position_ = self.position_ + length
}

///|
pub fn ByteReader::peek_u16_le(
  self : ByteReader,
) -> UInt raise @model.MedSealError {
  self.ensure(2)
  self.data[self.position_].to_uint() |
  (self.data[self.position_ + 1].to_uint() << 8)
}
