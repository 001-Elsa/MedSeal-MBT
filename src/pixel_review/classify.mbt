///|
fn text(dataset : @model.DataSet, group : UInt, element : UInt) -> String? {
  match dataset.find(@model.Tag::new(group, element)) {
    Some({ value: @model.ElementValue::Text(value), .. }) => Some(value)
    _ => None
  }
}

///|
/// Risk IDs contain no source text. NO/OCR-negative never clears the pixel gate.
pub fn classify(dataset : @model.DataSet) -> Array[String] {
  let risks = ["pixel-content-unchecked", "public-metadata-subset-only"]
  if text(dataset, 0x0008U, 0x0016U) == Some("1.2.840.10008.5.1.4.1.1.7") {
    risks.push("secondary-capture-visual-review")
  }
  if text(dataset, 0x0028U, 0x0301U) != Some("NO") {
    risks.push("burned-in-annotation-unresolved")
  }
  if text(dataset, 0x0028U, 0x0302U) != Some("NO") {
    risks.push("recognizable-features-unresolved")
  }
  if dataset.elements.any(fn(element) {
      element.tag.group >= 0x6000U && element.tag.group <= 0x60FFU
    }) {
    risks.push("overlay-source-unresolved")
  }
  risks.sort()
  risks
}
