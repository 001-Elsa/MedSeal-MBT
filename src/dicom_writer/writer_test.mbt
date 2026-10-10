///|
fn meta_element(
  tag : @model.Tag,
  vr : @model.Vr,
  value : String,
  order : Int,
) -> @model.DataElement {
  @model.DataElement::new(
    tag,
    vr,
    @utf8.encode(value).length().reinterpret_as_uint(),
    @model.ElementValue::Text(value),
    order,
  )
}

///|
test "write then parse preserves order, sequence and pixel bytes" {
  let meta = @model.DataSet::new([
    meta_element(
      @model.Tag::new(0x0002U, 0x0002U),
      @model.Vr::UI,
      "1.2.840.10008.5.1.4.1.1.7",
      0,
    ),
    meta_element(
      @model.Tag::new(0x0002U, 0x0003U),
      @model.Vr::UI,
      "1.2.826.0.1.3680043.10.999.1",
      1,
    ),
    meta_element(
      @model.transfer_syntax_uid_tag,
      @model.Vr::UI,
      @parser.explicit_vr_little_endian_uid,
      2,
    ),
    meta_element(
      @model.Tag::new(0x0002U, 0x0012U),
      @model.Vr::UI,
      "1.2.826.0.1.3680043.10.999",
      3,
    ),
  ])
  let nested = @model.DataSet::new([
    meta_element(
      @model.Tag::new(0x0010U, 0x0010U),
      @model.Vr::PN,
      "ANONYMOUS",
      0,
    ),
  ])
  let sequence = @model.DataElement::new(
    @model.Tag::new(0x0040U, 0x0100U),
    @model.Vr::SQ,
    0U,
    @model.ElementValue::Sequence([nested]),
    0,
  )
  let pixel = @model.DataElement::new(
    @model.pixel_data_tag,
    @model.Vr::OB,
    4U,
    @model.ElementValue::Raw(b"\x01\x02\x03\x04"),
    1,
  )
  let parsed : @parser.ParsedFile = {
    preamble: Bytes::make(128, b'\x00'),
    file_meta: meta,
    dataset: @model.DataSet::new([sequence, pixel]),
    transfer_syntax: @parser.explicit_vr_little_endian_uid,
    element_count: 3,
  }
  let reparsed = @parser.parse(@dicom_writer.write_bytes(parsed))
  assert_eq(reparsed.dataset.elements.length(), 2)
  assert_eq(reparsed.dataset.elements[0].tag, sequence.tag)
  assert_eq(reparsed.dataset.elements[1].tag, @model.pixel_data_tag)
  assert_true(
    reparsed.dataset.elements[1].value
    is @model.ElementValue::Raw(b"\x01\x02\x03\x04"),
  )
  match reparsed.dataset.elements[0].value {
    @model.ElementValue::Sequence(items) =>
      assert_true(
        items[0].elements[0].value is @model.ElementValue::Text("ANONYMOUS"),
      )
    _ => fail("expected sequence")
  }
}

///|
fn ordinary_element(
  group : UInt,
  element : UInt,
  vr : @model.Vr,
  value : @model.ElementValue,
) -> @model.DataElement {
  @model.DataElement::new(@model.Tag::new(group, element), vr, 0U, value, 0)
}

///|
test "odd length UI is padded with a null byte" {
  let writer = @byteio.ByteWriter::new()
  @dicom_writer.write_element(
    writer,
    ordinary_element(
      0x0008U,
      0x0018U,
      @model.Vr::UI,
      @model.ElementValue::Text("1.2"),
    ),
  )
  assert_eq(writer.to_bytes(), b"\x08\x00\x18\x00UI\x04\x001.2\x00")
}

///|
test "odd length ordinary text is padded with a space" {
  let writer = @byteio.ByteWriter::new()
  @dicom_writer.write_element(
    writer,
    ordinary_element(
      0x0010U,
      0x0020U,
      @model.Vr::LO,
      @model.ElementValue::Text("ABC"),
    ),
  )
  assert_eq(writer.to_bytes(), b"\x10\x00\x20\x00LO\x04\x00ABC ")
}

///|
test "long VR header contains reserved bytes and a u32 length" {
  let writer = @byteio.ByteWriter::new()
  @dicom_writer.write_element(
    writer,
    ordinary_element(
      0x7FE0U,
      0x0010U,
      @model.Vr::OB,
      @model.ElementValue::Raw(b"\x01\x02\x03\x04"),
    ),
  )
  assert_eq(
    writer.to_bytes(),
    b"\xe0\x7f\x10\x00OB\x00\x00\x04\x00\x00\x00\x01\x02\x03\x04",
  )
}

///|
test "numeric arrays are encoded little endian and reparse exactly" {
  let writer = @byteio.ByteWriter::new()
  @dicom_writer.write_element(
    writer,
    ordinary_element(
      0x0028U,
      0x0010U,
      @model.Vr::US,
      @model.ElementValue::UnsignedShort([1U, 0xFFFFU]),
    ),
  )
  @dicom_writer.write_element(
    writer,
    ordinary_element(
      0x7776U,
      0x0001U,
      @model.Vr::SS,
      @model.ElementValue::SignedShort([-32768, -1, 32767]),
    ),
  )
  @dicom_writer.write_element(
    writer,
    ordinary_element(
      0x7776U,
      0x0002U,
      @model.Vr::UL,
      @model.ElementValue::UnsignedLong([0U, 0xFFFFFFFFU]),
    ),
  )
  @dicom_writer.write_element(
    writer,
    ordinary_element(
      0x7776U,
      0x0003U,
      @model.Vr::SL,
      @model.ElementValue::SignedLong([-2147483648, 2147483647]),
    ),
  )
  let dataset = @parser.parse_dataset_bytes(writer.to_bytes())
  assert_true(
    dataset.elements[0].value
    is @model.ElementValue::UnsignedShort([1U, 0xFFFFU]),
  )
  assert_true(
    dataset.elements[1].value
    is @model.ElementValue::SignedShort([-32768, -1, 32767]),
  )
  assert_true(
    dataset.elements[2].value
    is @model.ElementValue::UnsignedLong([0U, 0xFFFFFFFFU]),
  )
  assert_true(
    dataset.elements[3].value
    is @model.ElementValue::SignedLong([-2147483648, 2147483647]),
  )
}

///|
test "writer recomputes empty and sequence lengths" {
  let empty_writer = @byteio.ByteWriter::new()
  @dicom_writer.write_element(
    empty_writer,
    ordinary_element(
      0x0010U,
      0x0030U,
      @model.Vr::DA,
      @model.ElementValue::Empty,
    ),
  )
  assert_eq(empty_writer.to_bytes(), b"\x10\x00\x30\x00DA\x00\x00")
  let nested = @model.DataSet::new([
    ordinary_element(
      0x0010U,
      0x0010U,
      @model.Vr::PN,
      @model.ElementValue::Text("A"),
    ),
  ])
  let sequence_writer = @byteio.ByteWriter::new()
  @dicom_writer.write_element(
    sequence_writer,
    ordinary_element(
      0x0040U,
      0x0275U,
      @model.Vr::SQ,
      @model.ElementValue::Sequence([nested]),
    ),
  )
  let reparsed = @parser.parse_dataset_bytes(sequence_writer.to_bytes())
  match reparsed.elements[0].value {
    @model.ElementValue::Sequence(items) => {
      assert_eq(items.length(), 1)
      assert_true(items[0].elements[0].value is @model.ElementValue::Text("A"))
    }
    _ => fail("expected sequence")
  }
}
