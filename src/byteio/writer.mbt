///|
pub struct ByteWriter {
  buffer : Buffer
}

///|
pub fn ByteWriter::new() -> ByteWriter {
  { buffer: Buffer::Buffer(), }
}

///|
pub fn ByteWriter::position(self : ByteWriter) -> Int {
  self.buffer.length()
}

///|
pub fn ByteWriter::write_u8(self : ByteWriter, value : UInt) -> Unit {
  self.buffer.write_byte(value.to_byte())
}

///|
pub fn ByteWriter::write_u16_le(self : ByteWriter, value : UInt) -> Unit {
  self.buffer.write_uint16_le(value.to_uint16())
}

///|
pub fn ByteWriter::write_u32_le(self : ByteWriter, value : UInt) -> Unit {
  self.buffer.write_uint_le(value)
}

///|
pub fn ByteWriter::write_bytes(self : ByteWriter, value : Bytes) -> Unit {
  self.buffer.write_bytes(value)
}

///|
pub fn ByteWriter::write_view(self : ByteWriter, value : BytesView) -> Unit {
  self.buffer.write_bytesview(value)
}

///|
pub fn ByteWriter::write_ascii(self : ByteWriter, value : String) -> Unit {
  self.buffer.write_string_utf8(value)
}

///|
pub fn ByteWriter::to_bytes(self : ByteWriter) -> Bytes {
  self.buffer.to_bytes()
}
