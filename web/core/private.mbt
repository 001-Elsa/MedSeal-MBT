///|
fn private_blocked(error : @dicom.MedSealError) -> String {
  Json::object(
    Map::from_array([
      ("schema", Json::number(1.0)),
      ("status", Json::string("blocked")),
      ("release_authorized", Json::boolean(false)),
      ("issue", @explain.public_error(error)),
    ]),
  ).stringify()
}

///|
fn private_budget(inputs : Array[Bytes]) -> Unit raise @dicom.MedSealError {
  if inputs.is_empty() || inputs.length() > 16 {
    raise invalid()
  }
  let mut total = 0
  for bytes in inputs {
    if bytes.length() == 0 || bytes.length() > 8 * 1024 * 1024 {
      raise invalid()
    }
    total = total + bytes.length()
    if total > 16 * 1024 * 1024 {
      raise invalid()
    }
  }
}

///|
/// Read-only original-object validation. Never invokes identity conversion,
/// fixed seeds/date shifts, or returns original values in the public result.
pub fn inspect_private(inputs : Array[Bytes]) -> String {
  try {
    private_budget(inputs)
    let objects = inputs.map(@validation.validate)
    let report = @explain.collection(objects)
    match report {
      Json::Object(fields) if fields.get("status") ==
        Some(Json::string("collection-validated")) => ()
      _ => return report.stringify()
    }
    Json::object(
      Map::from_array([
        ("schema", Json::number(1.0)),
        ("status", Json::string("passed")),
        ("scope", Json::string("read-only-current-collection")),
        ("release_authorized", Json::boolean(false)),
        ("report", report),
        ("structures", Json::array(inputs.map(structure))),
      ]),
    ).stringify()
  } catch {
    error => private_blocked(error)
  }
}

///|
/// Explicit private-only text view; never used for public export. Revalidates
/// before revealing. Limit to 128 values / 160 UTF-16 units per selected object.
pub fn reveal_private(inputs : Array[Bytes], index : Int) -> String {
  try {
    private_budget(inputs)
    if index < 0 || index >= inputs.length() {
      raise invalid()
    }
    let dataset = @validation.validate(inputs[index]).private_dataset()
    let rows : Array[Json] = []
    let mut truncated = false
    fn visit(ds : @dicom.DataSet, prefix : String) -> Unit {
      for element in ds.elements {
        if rows.length() >= 128 {
          truncated = true
          return
        }
        let path = prefix + "/" + element.tag.compact()
        match element.value {
          @dicom.ElementValue::Text(value) => {
            let shown = if value.length() > 160 {
              truncated = true
              value[:160].to_owned()
            } else {
              value
            }
            rows.push(
              Json::object(
                Map::from_array([
                  ("path", Json::string(path)),
                  ("vr", Json::string(element.vr.to_string())),
                  ("value", Json::string(shown)),
                ]),
              ),
            )
          }
          @dicom.ElementValue::Sequence(items) =>
            for item_index, item in items {
              if rows.length() >= 128 {
                truncated = true
                return
              }
              visit(item, "\{path}[\{item_index}]")
            }
          _ => () // No raw pixels/binary/numeric array serialization.
        }
      }
    }
    visit(dataset, "dataset")
    Json::object(
      Map::from_array([
        ("schema", Json::number(1.0)),
        ("status", Json::string("private-view")),
        ("rows", Json::array(rows)),
        ("truncated", Json::boolean(truncated)),
        ("release_authorized", Json::boolean(false)),
      ]),
    ).stringify()
  } catch {
    error => private_blocked(error)
  }
}
