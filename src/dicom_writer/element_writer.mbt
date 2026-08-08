///|
fn encode_text(vr : @model.Vr, value : String) -> Bytes {
  let encoded = @utf8.encode(value)
  if encoded.length() % 2 == 0 {
    encoded
  } else {
    let writer = @byteio.ByteWriter::new()
    writer.write_bytes(encoded)
    writer.write_u8(if vr == @model.Vr::UI { 0U } else { 0x20U })
    writer.to_bytes()
  }
}

///|
fn encode_us(values : Array[UInt]) -> Bytes {
  let writer = @byteio.ByteWriter::new()
  for value in values {
    writer.write_u16_le(value)
  }
  writer.to_bytes()
}

///|
fn encode_ss(values : Array[Int]) -> Bytes {
  let writer = @byteio.ByteWriter::new()
  for value in values {
    writer.write_u16_le(value.reinterpret_as_uint() & 0xFFFFU)
  }
  writer.to_bytes()
}

///|
fn encode_ul(values : Array[UInt]) -> Bytes {
  let writer = @byteio.ByteWriter::new()
  for value in values {
    writer.write_u32_le(value)
  }
  writer.to_bytes()
}

///|
fn encode_sl(values : Array[Int]) -> Bytes {
  encode_ul(values.map(fn(value) { value.reinterpret_as_uint() }))
}

///|
fn encode_ordinary_value(element : @model.DataElement) -> Bytes {
  match element.value {
    @model.ElementValue::Text(value) => encode_text(element.vr, value)
    @model.ElementValue::UnsignedShort(values) => encode_us(values)
    @model.ElementValue::SignedShort(values) => encode_ss(values)
    @model.ElementValue::UnsignedLong(values) => encode_ul(values)
    @model.ElementValue::SignedLong(values) => encode_sl(values)
    @model.ElementValue::Raw(value) => value
    @model.ElementValue::Empty => b""
    @model.ElementValue::Sequence(_) => b""
  }
}

///|
fn write_header(
  writer : @byteio.ByteWriter,
  tag : @model.Tag,
  vr : @model.Vr,
  length : UInt,
) -> Unit {
  writer.write_u16_le(tag.group)
  writer.write_u16_le(tag.element)
  writer.write_ascii(vr.to_string())
  if vr.uses_u32_length() {
    writer.write_u16_le(0U)
    writer.write_u32_le(length)
  } else {
    writer.write_u16_le(length)
  }
}

///|
pub fn write_element(
  writer : @byteio.ByteWriter,
  element : @model.DataElement,
) -> Unit {
  match element.value {
    @model.ElementValue::Sequence(items) => {
      let value = encode_sequence(items)
      write_header(
        writer,
        element.tag,
        @model.Vr::SQ,
        value.length().reinterpret_as_uint(),
      )
      writer.write_bytes(value)
    }
    _ => {
      let value = encode_ordinary_value(element)
      write_header(
        writer,
        element.tag,
        element.vr,
        value.length().reinterpret_as_uint(),
      )
      writer.write_bytes(value)
    }
  }
}
