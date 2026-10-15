///|
fn write_element(
  writer : @byteio.ByteWriter,
  group : UInt,
  element : UInt,
  vr : String,
  value : Bytes,
) -> Unit {
  let value = if vr != "UI" || value.length() % 2 == 0 {
    value
  } else {
    value + b"\x00"
  }
  writer.write_u16_le(group)
  writer.write_u16_le(element)
  writer.write_ascii(vr)
  let parsed_vr = @model.Vr::from_string(vr).unwrap()
  if parsed_vr.uses_u32_length() {
    writer.write_u16_le(0U)
    writer.write_u32_le(value.length().reinterpret_as_uint())
  } else {
    writer.write_u16_le(value.length().reinterpret_as_uint())
  }
  writer.write_bytes(value)
}

///|
fn minimal_file(ts : String) -> Bytes {
  let writer = @byteio.ByteWriter::new()
  writer.write_bytes(Bytes::make(128, b'\x00'))
  writer.write_ascii("DICM")
  let meta = @byteio.ByteWriter::new()
  write_element(
    meta,
    0x0002U,
    0x0002U,
    "UI",
    @utf8.encode("1.2.840.10008.5.1.4.1.1.7\u{0000}"),
  )
  write_element(
    meta,
    0x0002U,
    0x0003U,
    "UI",
    @utf8.encode("1.2.826.0.1.3680043.10.999.1\u{0000}"),
  )
  let uid = if ts.length() % 2 == 0 { ts } else { "\{ts}\u{0000}" }
  write_element(meta, 0x0002U, 0x0010U, "UI", @utf8.encode(uid))
  write_element(
    meta,
    0x0002U,
    0x0012U,
    "UI",
    @utf8.encode("1.2.826.0.1.3680043.10.999\u{0000}"),
  )
  let meta_bytes = meta.to_bytes()
  let group_length = @byteio.ByteWriter::new()
  group_length.write_u32_le(meta_bytes.length().reinterpret_as_uint())
  write_element(writer, 0x0002U, 0x0000U, "UL", group_length.to_bytes())
  writer.write_bytes(meta_bytes)
  write_element(writer, 0x0010U, 0x0010U, "PN", b"ALPHA^TEST")
  writer.to_bytes()
}

///|
test "parse valid explicit VR little endian file" {
  let parsed = @parser.parse(
    minimal_file(@parser.explicit_vr_little_endian_uid),
  )
  assert_eq(parsed.transfer_syntax, @parser.explicit_vr_little_endian_uid)
  assert_eq(parsed.dataset.elements.length(), 1)
  assert_true(
    parsed.dataset.elements[0].value is @model.ElementValue::Text("ALPHA^TEST"),
  )
}

///|
test "reject missing DICM marker" {
  let rejected = try {
    ignore(@parser.parse(Bytes::make(132, b'\x00')))
    false
  } catch {
    @model.MedSealError::MissingDicmMarker => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "reject unsupported transfer syntax" {
  let rejected = try {
    ignore(@parser.parse(minimal_file("1.2.840.10008.1.2.2")))
    false
  } catch {
    @model.MedSealError::UnsupportedTransferSyntax("1.2.840.10008.1.2.2") =>
      true
    _ => false
  }
  assert_true(rejected)
}

///|
test "reject missing required File Meta Information" {
  let writer = @byteio.ByteWriter::new()
  writer.write_bytes(Bytes::make(128, b'\x00'))
  writer.write_ascii("DICM")
  let rejected = try {
    ignore(@parser.parse(writer.to_bytes()))
    false
  } catch {
    @model.MedSealError::MissingRequiredFileMeta(tag) =>
      tag == @model.Tag::new(0x0002U, 0x0000U)
    _ => false
  }
  assert_true(rejected)
}

///|
test "reject incorrect File Meta Information Group Length" {
  let bytes = minimal_file(@parser.explicit_vr_little_endian_uid).to_array()
  bytes[140] = b'\x01'
  let rejected = try {
    ignore(@parser.parse(Bytes::from_array(bytes)))
    false
  } catch {
    @model.MedSealError::InvalidFileMetaGroupLength(_, _) => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "parse unsigned short dataset value" {
  let writer = @byteio.ByteWriter::new()
  write_element(writer, 0x0028U, 0x0010U, "US", b"\x00\x02")
  let dataset = @parser.parse_dataset_bytes(writer.to_bytes())
  assert_true(
    dataset.elements[0].value is @model.ElementValue::UnsignedShort([512U]),
  )
}

///|
test "parse undefined length sequence and item" {
  let writer = @byteio.ByteWriter::new()
  writer.write_u16_le(0x0040U)
  writer.write_u16_le(0x0275U)
  writer.write_ascii("SQ")
  writer.write_u16_le(0U)
  writer.write_u32_le(0xFFFFFFFFU)
  writer.write_u16_le(0xFFFEU)
  writer.write_u16_le(0xE000U)
  writer.write_u32_le(0xFFFFFFFFU)
  write_element(writer, 0x0010U, 0x0010U, "PN", b"TEST")
  writer.write_u16_le(0xFFFEU)
  writer.write_u16_le(0xE00DU)
  writer.write_u32_le(0U)
  writer.write_u16_le(0xFFFEU)
  writer.write_u16_le(0xE0DDU)
  writer.write_u32_le(0U)
  let dataset = @parser.parse_dataset_bytes(writer.to_bytes())
  match dataset.elements[0].value {
    @model.ElementValue::Sequence(items) => {
      assert_eq(items.length(), 1)
      assert_true(
        items[0].elements[0].value is @model.ElementValue::Text("TEST"),
      )
    }
    _ => fail("expected sequence")
  }
}

///|
test "reject sequence nesting deeper than 32" {
  let writer = @byteio.ByteWriter::new()
  for index = 0; index < 33; index = index + 1 {
    writer.write_u16_le(0x0040U)
    writer.write_u16_le(0x0275U)
    writer.write_ascii("SQ")
    writer.write_u16_le(0U)
    writer.write_u32_le(0xFFFFFFFFU)
    writer.write_u16_le(0xFFFEU)
    writer.write_u16_le(0xE000U)
    writer.write_u32_le(0xFFFFFFFFU)
  }
  let rejected = try {
    ignore(@parser.parse_dataset_bytes(writer.to_bytes()))
    false
  } catch {
    @model.MedSealError::ExcessiveNesting(33) => true
    _ => false
  }
  assert_true(rejected)
}

///|
fn write_item(
  writer : @byteio.ByteWriter,
  value : Bytes,
  undefined? : Bool = false,
) -> Unit {
  writer.write_u16_le(0xFFFEU)
  writer.write_u16_le(0xE000U)
  writer.write_u32_le(
    if undefined {
      0xFFFFFFFFU
    } else {
      value.length().reinterpret_as_uint()
    },
  )
  writer.write_bytes(value)
  if undefined {
    writer.write_u16_le(0xFFFEU)
    writer.write_u16_le(0xE00DU)
    writer.write_u32_le(0U)
  }
}

///|
test "parse empty defined length sequence" {
  let writer = @byteio.ByteWriter::new()
  write_element(writer, 0x0040U, 0x0275U, "SQ", b"")
  let dataset = @parser.parse_dataset_bytes(writer.to_bytes())
  assert_true(dataset.elements[0].value is @model.ElementValue::Sequence([]))
}

///|
test "parse defined length sequence with two items" {
  let first = @byteio.ByteWriter::new()
  write_element(first, 0x0010U, 0x0010U, "PN", b"FIRST ")
  let second = @byteio.ByteWriter::new()
  write_element(second, 0x0010U, 0x0020U, "LO", b"SECOND")
  let sequence_value = @byteio.ByteWriter::new()
  write_item(sequence_value, first.to_bytes())
  write_item(sequence_value, second.to_bytes())
  let writer = @byteio.ByteWriter::new()
  write_element(writer, 0x0040U, 0x0275U, "SQ", sequence_value.to_bytes())
  let dataset = @parser.parse_dataset_bytes(writer.to_bytes())
  match dataset.elements[0].value {
    @model.ElementValue::Sequence(items) => {
      assert_eq(items.length(), 2)
      assert_true(
        items[0].elements[0].value is @model.ElementValue::Text("FIRST"),
      )
      assert_true(
        items[1].elements[0].value is @model.ElementValue::Text("SECOND"),
      )
    }
    _ => fail("expected sequence")
  }
}

///|
test "parse multiple undefined length sequence items" {
  let writer = @byteio.ByteWriter::new()
  writer.write_u16_le(0x0040U)
  writer.write_u16_le(0x0275U)
  writer.write_ascii("SQ")
  writer.write_u16_le(0U)
  writer.write_u32_le(0xFFFFFFFFU)
  for value in [b"ONE ", b"TWO "] {
    let item = @byteio.ByteWriter::new()
    write_element(item, 0x0010U, 0x0010U, "PN", value)
    write_item(writer, item.to_bytes(), undefined=true)
  }
  writer.write_u16_le(0xFFFEU)
  writer.write_u16_le(0xE0DDU)
  writer.write_u32_le(0U)
  let dataset = @parser.parse_dataset_bytes(writer.to_bytes())
  match dataset.elements[0].value {
    @model.ElementValue::Sequence(items) => assert_eq(items.length(), 2)
    _ => fail("expected sequence")
  }
}

///|
test "reject undefined sequence without sequence delimiter" {
  let writer = @byteio.ByteWriter::new()
  writer.write_u16_le(0x0040U)
  writer.write_u16_le(0x0275U)
  writer.write_ascii("SQ")
  writer.write_u16_le(0U)
  writer.write_u32_le(0xFFFFFFFFU)
  let rejected = try {
    ignore(@parser.parse_dataset_bytes(writer.to_bytes()))
    false
  } catch {
    @model.MedSealError::InvalidSequence(_) => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "reject undefined item without item delimiter" {
  let writer = @byteio.ByteWriter::new()
  writer.write_u16_le(0x0040U)
  writer.write_u16_le(0x0275U)
  writer.write_ascii("SQ")
  writer.write_u16_le(0U)
  writer.write_u32_le(0xFFFFFFFFU)
  writer.write_u16_le(0xFFFEU)
  writer.write_u16_le(0xE000U)
  writer.write_u32_le(0xFFFFFFFFU)
  write_element(writer, 0x0010U, 0x0010U, "PN", b"TEST")
  let rejected = try {
    ignore(@parser.parse_dataset_bytes(writer.to_bytes()))
    false
  } catch {
    @model.MedSealError::InvalidSequence(_) => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "reject non-zero reserved field for long VR" {
  let writer = @byteio.ByteWriter::new()
  writer.write_u16_le(0x7FE0U)
  writer.write_u16_le(0x0010U)
  writer.write_ascii("OB")
  writer.write_u16_le(1U)
  writer.write_u32_le(0U)
  let rejected = try {
    ignore(@parser.parse_dataset_bytes(writer.to_bytes()))
    false
  } catch {
    @model.MedSealError::InvalidLength(_, 1U, _) => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "reject numeric value lengths that are not element aligned" {
  for
    value in [
      ("US", b"\x01"),
      ("SS", b"\x01\x02\x03"),
      ("UL", b"\x01\x02"),
      ("SL", b"\x01\x02\x03"),
    ] {
    let (vr, bytes) = value
    let writer = @byteio.ByteWriter::new()
    write_element(writer, 0x0028U, 0x0010U, vr, bytes)
    let rejected = try {
      ignore(@parser.parse_dataset_bytes(writer.to_bytes()))
      false
    } catch {
      @model.MedSealError::InvalidLength(_, _, _) => true
      _ => false
    }
    assert_true(rejected)
  }
}

///|
test "OB OW and UN values remain raw bytes" {
  for value in [("OB", b"\x01\x02"), ("OW", b"\x03\x04"), ("UN", b"\x05\x06")] {
    let (vr, bytes) = value
    let writer = @byteio.ByteWriter::new()
    write_element(writer, 0x7776U, 0x0010U, vr, bytes)
    let dataset = @parser.parse_dataset_bytes(writer.to_bytes())
    match dataset.elements[0].value {
      @model.ElementValue::Raw(actual) => assert_eq(actual, bytes)
      _ => fail("expected raw bytes")
    }
  }
}

///|
test "invalid VR reports the VR byte offset" {
  let writer = @byteio.ByteWriter::new()
  writer.write_u16_le(0x0010U)
  writer.write_u16_le(0x0010U)
  writer.write_ascii("ZZ")
  writer.write_u16_le(0U)
  let rejected = try {
    ignore(@parser.parse_dataset_bytes(writer.to_bytes()))
    false
  } catch {
    @model.MedSealError::InvalidVr("ZZ", 4) => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "truncated ordinary element reports its tag and value offset" {
  let writer = @byteio.ByteWriter::new()
  writer.write_u16_le(0x0010U)
  writer.write_u16_le(0x0010U)
  writer.write_ascii("PN")
  writer.write_u16_le(4U)
  writer.write_ascii("AB")
  let rejected = try {
    ignore(@parser.parse_dataset_bytes(writer.to_bytes()))
    false
  } catch {
    @model.MedSealError::InvalidLength(tag, 4U, 8) =>
      tag == @model.Tag::new(0x0010U, 0x0010U)
    _ => false
  }
  assert_true(rejected)
}
