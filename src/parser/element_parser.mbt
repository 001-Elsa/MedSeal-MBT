///|
priv struct ParseState {
  mut count : Int
  mut implicit_vr : Bool
}

///|
fn ParseState::next(self : ParseState) -> Int raise @model.MedSealError {
  self.count = self.count + 1
  if self.count > 100000 {
    raise @model.MedSealError::TooManyElements(self.count)
  }
  self.count - 1
}

///|
fn read_tag(
  reader : @byteio.ByteReader,
) -> @model.Tag raise @model.MedSealError {
  @model.Tag::new(reader.read_u16_le(), reader.read_u16_le())
}

///|
fn read_vr(reader : @byteio.ByteReader) -> @model.Vr raise @model.MedSealError {
  let offset = reader.position()
  let bytes = reader.read_bytes(2)
  let raw = String::from_array([bytes[0].to_char(), bytes[1].to_char()])
  match @model.Vr::from_string(raw) {
    Some(vr) => vr
    None => raise @model.MedSealError::InvalidVr(raw, offset)
  }
}

///|
fn read_length(
  reader : @byteio.ByteReader,
  vr : @model.Vr,
) -> UInt raise @model.MedSealError {
  if vr.uses_u32_length() {
    let reserved = reader.read_u16_le()
    if reserved != 0U {
      raise @model.MedSealError::InvalidLength(
        @model.Tag::new(0U, 0U),
        reserved,
        reader.position() - 2,
      )
    }
    reader.read_u32_le()
  } else {
    reader.read_u16_le()
  }
}

///|
fn trim_text(bytes : Bytes) -> String raise @model.MedSealError {
  let decoded = @utf8.decode(bytes) catch {
    _ => raise @model.MedSealError::InvalidTextEncoding
  }
  decoded.trim_end(chars=" \u{0000}").to_owned()
}

///|
fn decode_us(bytes : Bytes) -> Array[UInt] {
  let result : Array[UInt] = []
  let mut index = 0
  while index < bytes.length() {
    result.push(bytes[index].to_uint() | (bytes[index + 1].to_uint() << 8))
    index = index + 2
  }
  result
}

///|
fn decode_ss(bytes : Bytes) -> Array[Int] {
  decode_us(bytes).map(fn(value) {
    if value >= 0x8000U {
      value.reinterpret_as_int() - 65536
    } else {
      value.reinterpret_as_int()
    }
  })
}

///|
fn decode_ul(bytes : Bytes) -> Array[UInt] {
  let result : Array[UInt] = []
  let mut index = 0
  while index < bytes.length() {
    result.push(
      bytes[index].to_uint() |
      (bytes[index + 1].to_uint() << 8) |
      (bytes[index + 2].to_uint() << 16) |
      (bytes[index + 3].to_uint() << 24),
    )
    index = index + 4
  }
  result
}

///|
fn decode_value(
  vr : @model.Vr,
  bytes : Bytes,
) -> @model.ElementValue raise @model.MedSealError {
  if bytes.is_empty() {
    return @model.ElementValue::Empty
  }
  if vr.is_text() {
    @model.ElementValue::Text(trim_text(bytes))
  } else {
    match vr {
      US => @model.ElementValue::UnsignedShort(decode_us(bytes))
      SS => @model.ElementValue::SignedShort(decode_ss(bytes))
      UL => @model.ElementValue::UnsignedLong(decode_ul(bytes))
      SL =>
        @model.ElementValue::SignedLong(
          decode_ul(bytes).map(fn(value) { value.reinterpret_as_int() }),
        )
      _ => @model.ElementValue::Raw(bytes)
    }
  }
}

///|
fn check_value_length(
  reader : @byteio.ByteReader,
  tag : @model.Tag,
  length : UInt,
  value_offset : Int,
) -> Int raise @model.MedSealError {
  if length > 0x08000000U {
    raise @model.MedSealError::ElementTooLarge(length, value_offset)
  }
  let int_length = length.reinterpret_as_int()
  if int_length < 0 || int_length > reader.remaining() {
    raise @model.MedSealError::InvalidLength(tag, length, value_offset)
  }
  int_length
}

///|
fn parse_element(
  reader : @byteio.ByteReader,
  state : ParseState,
  depth : Int,
) -> @model.DataElement raise @model.MedSealError {
  let element_offset = reader.position()
  let tag = read_tag(reader)
  if tag.group == 0xFFFEU {
    raise @model.MedSealError::InvalidSequence(element_offset)
  }
  let vr = if state.implicit_vr { implicit_vr_of(tag) } else { read_vr(reader) }
  let length = if state.implicit_vr {
    reader.read_u32_le()
  } else {
    read_length(reader, vr)
  }
  let order = state.next()
  if vr == @model.Vr::SQ {
    let items = parse_sequence(reader, state, depth + 1, length)
    return @model.DataElement::new(
      tag,
      vr,
      length,
      @model.ElementValue::Sequence(items),
      order,
    )
  }
  if length == 0xFFFFFFFFU {
    raise @model.MedSealError::InvalidLength(tag, length, reader.position())
  }
  let int_length = check_value_length(reader, tag, length, reader.position())
  if int_length % 2 != 0 {
    raise @model.MedSealError::InvalidLength(tag, length, reader.position())
  }
  if int_length % vr.value_unit_size() != 0 {
    raise @model.MedSealError::InvalidLength(tag, length, reader.position())
  }
  let bytes = reader.read_bytes(int_length)
  @model.DataElement::new(
    tag,
    vr,
    length,
    decode_value(vr, bytes),
    order,
    original_bytes=if vr.is_text() { Some(bytes) } else { None },
  )
}

///|
fn parse_dataset_to_end(
  reader : @byteio.ByteReader,
  state : ParseState,
  depth : Int,
  end : Int,
) -> @model.DataSet raise @model.MedSealError {
  let elements : Array[@model.DataElement] = []
  while reader.position() < end {
    elements.push(parse_element(reader, state, depth))
  }
  if reader.position() != end {
    raise @model.MedSealError::InvalidSequence(reader.position())
  }
  @model.DataSet::new(elements)
}

///|
fn next_is(
  reader : @byteio.ByteReader,
  group : UInt,
  element : UInt,
) -> Bool raise @model.MedSealError {
  if reader.remaining() < 4 {
    return false
  }
  let saved = reader.position()
  let found_group = reader.read_u16_le()
  let found_element = reader.read_u16_le()
  reader.seek(saved)
  found_group == group && found_element == element
}

///|
fn parse_undefined_item(
  reader : @byteio.ByteReader,
  state : ParseState,
  depth : Int,
) -> @model.DataSet raise @model.MedSealError {
  let elements : Array[@model.DataElement] = []
  while reader.remaining() > 0 {
    if next_is(reader, 0xFFFEU, 0xE00DU) {
      ignore(read_tag(reader))
      let delimiter_length = reader.read_u32_le()
      if delimiter_length != 0U {
        raise @model.MedSealError::InvalidSequence(reader.position() - 4)
      }
      return @model.DataSet::new(elements)
    }
    elements.push(parse_element(reader, state, depth))
  }
  raise @model.MedSealError::InvalidSequence(reader.position())
}

///|
fn parse_item(
  reader : @byteio.ByteReader,
  state : ParseState,
  depth : Int,
) -> @model.DataSet raise @model.MedSealError {
  let offset = reader.position()
  let item_tag = read_tag(reader)
  if item_tag.group != 0xFFFEU || item_tag.element != 0xE000U {
    raise @model.MedSealError::InvalidSequence(offset)
  }
  let item_length = reader.read_u32_le()
  if item_length == 0xFFFFFFFFU {
    parse_undefined_item(reader, state, depth)
  } else {
    if item_length > 0x08000000U {
      raise @model.MedSealError::ElementTooLarge(item_length, reader.position())
    }
    let length = item_length.reinterpret_as_int()
    if length > reader.remaining() {
      raise @model.MedSealError::InvalidSequence(reader.position())
    }
    parse_dataset_to_end(reader, state, depth, reader.position() + length)
  }
}

///|
fn parse_sequence(
  reader : @byteio.ByteReader,
  state : ParseState,
  depth : Int,
  length : UInt,
) -> Array[@model.DataSet] raise @model.MedSealError {
  if depth > 32 {
    raise @model.MedSealError::ExcessiveNesting(depth)
  }
  let items : Array[@model.DataSet] = []
  if length == 0xFFFFFFFFU {
    while reader.remaining() > 0 {
      if next_is(reader, 0xFFFEU, 0xE0DDU) {
        ignore(read_tag(reader))
        let delimiter_length = reader.read_u32_le()
        if delimiter_length != 0U {
          raise @model.MedSealError::InvalidSequence(reader.position() - 4)
        }
        return items
      }
      items.push(parse_item(reader, state, depth))
    }
    raise @model.MedSealError::InvalidSequence(reader.position())
  }
  let sequence_length = check_value_length(
    reader,
    @model.Tag::new(0U, 0U),
    length,
    reader.position(),
  )
  let end = reader.position() + sequence_length
  while reader.position() < end {
    items.push(parse_item(reader, state, depth))
  }
  if reader.position() != end {
    raise @model.MedSealError::InvalidSequence(reader.position())
  }
  items
}
