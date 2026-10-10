///|
fn count_private(dataset : @model.DataSet) -> Int {
  let mut count = 0
  for element in dataset.elements {
    if element.tag.is_private() {
      count = count + 1
    }
    match element.value {
      @model.ElementValue::Sequence(items) =>
        for item in items {
          count = count + count_private(item)
        }
      _ => ()
    }
  }
  count
}

///|
pub fn validate_dataset(dataset : @model.DataSet) -> ValidationReport {
  let issues : Array[ValidationIssue] = []
  validate_elements(dataset, issues)
  if dataset.find(@dictionary.patient_name_tag()) is None {
    issues.push(
      ValidationIssue::new(
        Warning,
        "MEDSEAL-W101",
        "file does not contain Patient Name",
        tag=Some(@dictionary.patient_name_tag()),
      ),
    )
  }
  let private_count = count_private(dataset)
  if private_count > 0 {
    issues.push(
      ValidationIssue::new(
        Warning,
        "MEDSEAL-W102",
        "file contains \{private_count} private element(s)",
      ),
    )
  }
  for
    tag in [
      @model.Tag::new(0x0008U, 0x1030U),
      @model.Tag::new(0x0008U, 0x103EU),
      @model.Tag::new(0x0018U, 0x1030U),
    ] {
    match (dataset.find(tag), @dictionary.sensitive_rule(tag)) {
      (Some(_), Some(@dictionary.SensitiveRule::KeepWithWarning(code, message))) =>
        issues.push(ValidationIssue::new(Warning, code, message, tag=Some(tag)))
      _ => ()
    }
  }
  validate_image_metadata(dataset, issues)
  { issues, elements_checked: dataset.count_recursive(), }
}

///|
pub fn validate(parsed : @parser.ParsedFile) -> ValidationReport {
  validate_dataset(parsed.dataset)
}

///|
pub fn private_element_count(dataset : @model.DataSet) -> Int {
  count_private(dataset)
}
