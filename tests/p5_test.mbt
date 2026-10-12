///|
test "P5 NO flags never waive pixel review and SC always requires visual review" {
  let elements = strict_dataset().elements.copy()
  for
    tag in [
      @model.Tag::new(0x0028U, 0x0301U),
      @model.Tag::new(0x0028U, 0x0302U),
    ] {
    elements.push(
      @model.DataElement::new(
        tag,
        @model.Vr::CS,
        2U,
        @model.ElementValue::Text("NO"),
        0,
      ),
    )
  }
  let dataset = @model.DataSet::new(elements)
  let risks = @pixel_review.classify(dataset)
  assert_true(risks.contains("pixel-content-unchecked"))
  assert_true(risks.contains("secondary-capture-visual-review"))
  assert_true(risks.contains("public-metadata-subset-only"))
  assert_true(!risks.contains("burned-in-annotation-unresolved"))
  let original = @pixel_review.classify(strict_dataset())
  assert_true(original.contains("burned-in-annotation-unresolved"))
  assert_true(original.contains("recognizable-features-unresolved"))
}
