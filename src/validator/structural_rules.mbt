///|
fn valid_uid(value : String) -> Bool {
  !value.is_empty() &&
  value.length() <= 64 &&
  value.all(fn(char) { char == '.' || char.is_digit(10U) })
}

///|
fn validate_elements(
  dataset : @model.DataSet,
  issues : Array[ValidationIssue],
) -> Unit {
  for element in dataset.elements {
    match element.value {
      @model.ElementValue::Text(value) => {
        if element.vr == @model.Vr::UI && !valid_uid(value) {
          issues.push(
            ValidationIssue::new(
              Error,
              "MEDSEAL-E210",
              "UI value must contain only digits and dots and be at most 64 characters",
              tag=Some(element.tag),
            ),
          )
        }
        if value.length() > 1024 * 1024 {
          issues.push(
            ValidationIssue::new(
              Error,
              "MEDSEAL-E211",
              "text value exceeds the safe semantic length",
              tag=Some(element.tag),
            ),
          )
        }
      }
      @model.ElementValue::Sequence(items) =>
        for item in items {
          validate_elements(item, issues)
        }
      _ => ()
    }
  }
}
