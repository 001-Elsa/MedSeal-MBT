///|
fn first_us(dataset : @model.DataSet, tag : @model.Tag) -> UInt? {
  match dataset.find(tag) {
    Some(element) =>
      match element.value {
        @model.ElementValue::UnsignedShort(values) => values.get(0)
        _ => None
      }
    None => None
  }
}

///|
fn warn_missing_number(
  dataset : @model.DataSet,
  issues : Array[ValidationIssue],
  tag : @model.Tag,
  name : String,
) -> UInt? {
  match first_us(dataset, tag) {
    Some(value) => Some(value)
    None => {
      issues.push(
        ValidationIssue::new(
          Warning,
          "MEDSEAL-W201",
          "missing or unsupported \{name}",
          tag=Some(tag),
        ),
      )
      None
    }
  }
}

///|
fn validate_image_metadata(
  dataset : @model.DataSet,
  issues : Array[ValidationIssue],
) -> Unit {
  let rows_tag = @model.Tag::new(0x0028U, 0x0010U)
  let columns_tag = @model.Tag::new(0x0028U, 0x0011U)
  let samples_tag = @model.Tag::new(0x0028U, 0x0002U)
  let allocated_tag = @model.Tag::new(0x0028U, 0x0100U)
  let stored_tag = @model.Tag::new(0x0028U, 0x0101U)
  let representation_tag = @model.Tag::new(0x0028U, 0x0103U)
  for
    pair in [
      (rows_tag, "Rows"),
      (columns_tag, "Columns"),
      (samples_tag, "Samples Per Pixel"),
    ] {
    let (tag, name) = pair
    match warn_missing_number(dataset, issues, tag, name) {
      Some(0U) =>
        issues.push(
          ValidationIssue::new(
            Error,
            "MEDSEAL-E220",
            "\{name} must be greater than zero",
            tag=Some(tag),
          ),
        )
      _ => ()
    }
  }
  let allocated = warn_missing_number(
    dataset, issues, allocated_tag, "Bits Allocated",
  )
  let stored = warn_missing_number(dataset, issues, stored_tag, "Bits Stored")
  match (allocated, stored) {
    (Some(a), Some(s)) if s > a =>
      issues.push(
        ValidationIssue::new(
          Error,
          "MEDSEAL-E221",
          "Bits Stored must not exceed Bits Allocated",
          tag=Some(stored_tag),
        ),
      )
    _ => ()
  }
  match
    warn_missing_number(
      dataset, issues, representation_tag, "Pixel Representation",
    ) {
    Some(value) if value != 0U && value != 1U =>
      issues.push(
        ValidationIssue::new(
          Error,
          "MEDSEAL-E222",
          "Pixel Representation must be 0 or 1",
          tag=Some(representation_tag),
        ),
      )
    _ => ()
  }
}
