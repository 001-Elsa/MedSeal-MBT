///|
fn text_element(
  group : UInt,
  element : UInt,
  vr : @model.Vr,
  value : String,
  order : Int,
) -> @model.DataElement {
  @model.DataElement::new(
    @model.Tag::new(group, element),
    vr,
    @utf8.encode(value).length().reinterpret_as_uint(),
    @model.ElementValue::Text(value),
    order,
  )
}

///|
test "direct identifiers are replaced without audit leakage" {
  let source = @model.DataSet::new([
    text_element(0x0010U, 0x0010U, @model.Vr::PN, "SECRET^NAME", 0),
    text_element(0x0010U, 0x0020U, @model.Vr::LO, "SECRET-ID", 1),
    text_element(0x0010U, 0x0030U, @model.Vr::DA, "19700101", 2),
  ])
  let result = @deid.anonymize(source)
  assert_true(
    result.dataset.elements[0].value is @model.ElementValue::Text("ANONYMOUS"),
  )
  assert_true(
    result.dataset.elements[1].value is @model.ElementValue::Text("MEDSEAL-ID"),
  )
  assert_true(result.dataset.elements[2].value is @model.ElementValue::Empty)
  let report = @deid.audit_json(
    result, "in.dcm", "out.dcm", "1.2.840.10008.1.2.1", 3,
  )
  assert_false(report.contains("SECRET"))
}

///|
test "private removal and nested sequence processing" {
  let nested = @model.DataSet::new([
    text_element(0x0010U, 0x0010U, @model.Vr::PN, "NESTED", 0),
  ])
  let sequence = @model.DataElement::new(
    @model.Tag::new(0x0040U, 0x0100U),
    @model.Vr::SQ,
    0U,
    @model.ElementValue::Sequence([nested]),
    0,
  )
  let private = text_element(0x0011U, 0x0010U, @model.Vr::LO, "PRIVATE", 1)
  let result = @deid.anonymize(
    @model.DataSet::new([sequence, private]),
    remove_private=true,
  )
  assert_eq(result.private_elements_removed, 1)
  assert_eq(result.dataset.elements.length(), 1)
  match result.dataset.elements[0].value {
    @model.ElementValue::Sequence(items) =>
      assert_true(
        items[0].elements[0].value is @model.ElementValue::Text("ANONYMOUS"),
      )
    _ => fail("expected sequence")
  }
}

///|
test "basic de-identification is idempotent" {
  let source = @model.DataSet::new([
    text_element(0x0010U, 0x0010U, @model.Vr::PN, "SECRET^NAME", 0),
    text_element(0x0010U, 0x0020U, @model.Vr::LO, "SECRET-ID", 1),
    text_element(0x0010U, 0x0030U, @model.Vr::DA, "19700101", 2),
  ])
  let first = @deid.anonymize(source)
  let second = @deid.anonymize(first.dataset)
  assert_eq(first.elements_changed, 3)
  assert_eq(second.elements_changed, 0)
  assert_eq(second.elements_removed, 0)
  assert_true(second.changes.is_empty())
}

///|
test "private elements are retained by default with a risk warning" {
  let private = text_element(0x0011U, 0x1010U, @model.Vr::LO, "PRIVATE", 0)
  let result = @deid.anonymize(@model.DataSet::new([private]))
  assert_eq(result.dataset.elements.length(), 1)
  assert_eq(result.private_elements_removed, 0)
  assert_true(
    result.warnings.any(fn(warning) { warning.code == "MEDSEAL-W102" }),
  )
}

///|
test "pixel data bytes are preserved exactly" {
  let pixels = b"\x00\x01\x7f\x80\xfe\xff"
  let pixel = @model.DataElement::new(
    @model.pixel_data_tag,
    @model.Vr::OB,
    pixels.length().reinterpret_as_uint(),
    @model.ElementValue::Raw(pixels),
    0,
  )
  let result = @deid.anonymize(
    @model.DataSet::new([pixel]),
    remove_private=true,
  )
  assert_eq(result.elements_changed, 0)
  assert_eq(result.elements_removed, 0)
  assert_true(
    result.dataset.elements[0].value
    is @model.ElementValue::Raw(b"\x00\x01\x7f\x80\xfe\xff"),
  )
}

///|
test "audit report never exposes value fields" {
  let result = @deid.anonymize(
    @model.DataSet::new([
      text_element(0x0010U, 0x0010U, @model.Vr::PN, "LEAK-CHECK", 0),
    ]),
  )
  let report = @deid.audit_json(
    result, "in.dcm", "out.dcm", "1.2.840.10008.1.2.1", 1,
  )
  assert_false(report.contains("LEAK-CHECK"))
  assert_false(report.contains("old_value"))
  assert_false(report.contains("new_value"))
}
