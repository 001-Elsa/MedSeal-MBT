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
  let result = anonymize(source)
  assert_true(
    result.dataset.elements[0].value is @model.ElementValue::Text("ANONYMOUS"),
  )
  assert_true(
    result.dataset.elements[1].value is @model.ElementValue::Text("MEDSEAL-ID"),
  )
  assert_true(result.dataset.elements[2].value is @model.ElementValue::Empty)
  let report = audit_json(result, "in.dcm", "out.dcm", "1.2.840.10008.1.2.1", 3)
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
  let result = anonymize(
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
