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
  let report = @validator.validate_dataset(dataset)
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
  let report = @validator.validate_dataset(@model.DataSet::new([uid]))
  assert_true(report.issues.any(fn(issue) { issue.code == "MEDSEAL-E210" }))
}

///|
fn text_value(
  vr : @model.Vr,
  value : String,
  order : Int,
) -> @model.DataElement {
  @model.DataElement::new(
    @model.Tag::new(0x0008U, 0x0100U + order.reinterpret_as_uint()),
    vr,
    value.length().reinterpret_as_uint(),
    @model.ElementValue::Text(value),
    order,
  )
}

///|
test "UI rejects empty components and edge dots" {
  for value in [".1.2", "1.2.", "1..2"] {
    let report = @validator.validate_dataset(
      @model.DataSet::new([text_value(@model.Vr::UI, value, 0)]),
    )
    assert_true(report.issues.any(fn(issue) { issue.code == "MEDSEAL-E210" }))
  }
}

///|
test "bounded text VRs enforce their character limits" {
  let report = @validator.validate_dataset(
    @model.DataSet::new([
      text_value(@model.Vr::AE, "12345678901234567", 0),
      text_value(@model.Vr::SH, "12345678901234567", 1),
      text_value(
        @model.Vr::LO,
        "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
        2,
      ),
    ]),
  )
  assert_eq(
    report.issues.filter(fn(issue) { issue.code == "MEDSEAL-E212" }).length(),
    3,
  )
}

///|
test "CS AS and DA syntax checks have stable error codes" {
  let report = @validator.validate_dataset(
    @model.DataSet::new([
      text_value(@model.Vr::CS, "lower-case", 0),
      text_value(@model.Vr::AS, "12Y", 1),
      text_value(@model.Vr::DA, "2026-08-08", 2),
    ]),
  )
  assert_true(report.issues.any(fn(issue) { issue.code == "MEDSEAL-E213" }))
  assert_true(report.issues.any(fn(issue) { issue.code == "MEDSEAL-E214" }))
  assert_true(report.issues.any(fn(issue) { issue.code == "MEDSEAL-E215" }))
}

///|
test "valid constrained text values pass their syntax rules" {
  let report = @validator.validate_dataset(
    @model.DataSet::new([
      text_value(@model.Vr::UI, "1.2.840.10008.1.2.1", 0),
      text_value(@model.Vr::CS, "ORIGINAL_PRIMARY", 1),
      text_value(@model.Vr::AS, "032Y", 2),
      text_value(@model.Vr::DA, "20260808", 3),
    ]),
  )
  assert_false(
    report.issues.any(fn(issue) {
      issue.code == "MEDSEAL-E210" ||
      issue.code == "MEDSEAL-E212" ||
      issue.code == "MEDSEAL-E213" ||
      issue.code == "MEDSEAL-E214" ||
      issue.code == "MEDSEAL-E215"
    }),
  )
}
