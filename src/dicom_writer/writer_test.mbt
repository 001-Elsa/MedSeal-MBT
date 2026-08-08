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
      @model.transfer_syntax_uid_tag,
      @model.Vr::UI,
      @parser.explicit_vr_little_endian_uid,
      0,
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
  let reparsed = @parser.parse(write_bytes(parsed))
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
