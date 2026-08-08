///|
fn us_element(
  group : UInt,
  element : UInt,
  value : UInt,
  order : Int,
) -> @model.DataElement {
  @model.DataElement::new(
    @model.Tag::new(group, element),
    @model.Vr::US,
    2U,
    @model.ElementValue::UnsignedShort([value]),
    order,
  )
}

///|
test "Bits Stored larger than Bits Allocated is invalid" {
  let dataset = @model.DataSet::new([
    us_element(0x0028U, 0x0010U, 1U, 0),
    us_element(0x0028U, 0x0011U, 1U, 1),
    us_element(0x0028U, 0x0002U, 1U, 2),
    us_element(0x0028U, 0x0100U, 8U, 3),
    us_element(0x0028U, 0x0101U, 12U, 4),
    us_element(0x0028U, 0x0103U, 0U, 5),
  ])
  let report = validate_dataset(dataset)
  assert_false(report.is_valid())
  assert_true(report.issues.any(fn(issue) { issue.code == "MEDSEAL-E221" }))
}

///|
test "invalid UID creates a stable error" {
  let uid = @model.DataElement::new(
    @model.Tag::new(0x0008U, 0x0018U),
    @model.Vr::UI,
    3U,
    @model.ElementValue::Text("abc"),
    0,
  )
  let report = validate_dataset(@model.DataSet::new([uid]))
  assert_true(report.issues.any(fn(issue) { issue.code == "MEDSEAL-E210" }))
}
