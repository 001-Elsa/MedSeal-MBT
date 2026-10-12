///|
fn valid_uid(value : String) -> Bool {
  value
  .split("\\")
  .all(fn(uid) {
    !uid.is_empty() &&
    uid.length() <= 64 &&
    uid
    .split(".")
    .all(fn(part) {
      !part.is_empty() &&
      part.all(fn(c) { c >= '0' && c <= '9' }) &&
      (part.length() == 1 || !part.has_prefix("0"))
    })
  })
}

///|
fn text_vr_limit(vr : @model.Vr) -> Int? {
  match vr {
    AE | CS | DS | SH => Some(16)
    AS => Some(4)
    DA => Some(18)
    DT => Some(54)
    IS => Some(12)
    LO | PN | UI => Some(64)
    ST => Some(1024)
    LT => Some(10240)
    TM => Some(28)
    _ => None
  }
}

///|
fn valid_code_string(value : String) -> Bool {
  value.all(fn(char) {
    char == ' ' ||
    char == '_' ||
    char.is_digit(10U) ||
    (char >= 'A' && char <= 'Z')
  })
}

///|
fn valid_age_string(value : String) -> Bool {
  value.length() == 4 &&
  value[0:3].all(fn(char) { char.is_digit(10U) }) &&
  (value[3] == 'D' || value[3] == 'W' || value[3] == 'M' || value[3] == 'Y')
}

///|
fn valid_date(value : String) -> Bool {
  value.split("\\").all(fn(part) { @date.valid(part.to_owned()) })
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
        match text_vr_limit(element.vr) {
          Some(limit) if value
            .split("\\")
            .any(fn(part) {
              if element.vr == @model.Vr::PN {
                part.split("=").any(fn(group) { group.char_length() > limit })
              } else {
                part.char_length() > limit
              }
            }) =>
            issues.push(
              ValidationIssue::new(
                Error,
                "MEDSEAL-E212",
                "\{element.vr.to_string()} value exceeds \{limit} characters",
                tag=Some(element.tag),
              ),
            )
          _ => ()
        }
        if element.vr == @model.Vr::CS &&
          !value
          .split("\\")
          .all(fn(part) { valid_code_string(part.to_owned()) }) {
          issues.push(
            ValidationIssue::new(
              Error,
              "MEDSEAL-E213",
              "CS value contains characters outside A-Z, 0-9, space and underscore",
              tag=Some(element.tag),
            ),
          )
        }
        if element.vr == @model.Vr::AS && !valid_age_string(value) {
          issues.push(
            ValidationIssue::new(
              Error,
              "MEDSEAL-E214",
              "AS value must contain three digits followed by D, W, M or Y",
              tag=Some(element.tag),
            ),
          )
        }
        if element.vr == @model.Vr::DA && !valid_date(value) {
          issues.push(
            ValidationIssue::new(
              Error,
              "MEDSEAL-E215",
              "DA value must be empty or contain exactly eight digits",
              tag=Some(element.tag),
            ),
          )
        }
        if (
            element.vr == @model.DT &&
            !value.split("\\").all(fn(part) { @date.valid_dt(part.to_owned()) })
          ) ||
          (
            element.vr == @model.TM &&
            !value.split("\\").all(fn(part) { @date.valid_tm(part.to_owned()) })
          ) ||
          (
            element.tag == @model.Tag::new(0x0008U, 0x0201U) &&
            !value.is_empty() &&
            !@date.valid_zone(value)
          ) {
          issues.push(
            ValidationIssue::new(
              Error,
              "MEDSEAL-E216",
              "invalid temporal precision, offset or value",
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
