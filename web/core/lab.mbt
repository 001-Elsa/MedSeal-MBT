///|
fn invalid() -> @dicom.MedSealError {
  @dicom.MedSealError::InvalidArgument("lab input budget or shape")
}

///|
fn decode_inputs(text : String) -> Array[Bytes] raise @dicom.MedSealError {
  // Hex transport is intentionally simple and bounded; UI supplies only the
  // bundled synthetic corpus. Never send patient files to a public demo.
  if text.length() > 2 * 1024 * 1024 {
    raise invalid()
  }
  let json = @json.parse(text) catch { _ => raise invalid() }
  let items = match json {
    Json::Array(items) if !items.is_empty() && items.length() <= 16 => items
    _ => raise invalid()
  }
  items.map(item => {
    let hex = match item {
      Json::String(value) => value
      _ => raise invalid()
    }
    @hex.decode(hex) catch {
      _ => raise invalid()
    }
  })
}

///|
fn structure(bytes : Bytes) -> Json raise @dicom.MedSealError {
  let rows : Array[Json] = []
  let mut truncated = false
  fn visit(dataset : @dicom.DataSet, prefix : String) -> Unit {
    for element in dataset.elements {
      if rows.length() >= 512 {
        truncated = true
        return
      }
      let path = prefix + "/" + element.tag.compact()
      rows.push(
        Json::object(
          Map::from_array([
            ("path", Json::string(path)),
            ("vr", Json::string(element.vr.to_string())),
          ]),
        ),
      )
      if element.value is @dicom.ElementValue::Sequence(items) {
        for index, item in items {
          if rows.length() >= 512 {
            truncated = true
            return
          }
          visit(item, "\{path}[\{index}]")
        }
      }
    }
  }
  visit(@dicom.parse(bytes).dataset, "dataset")
  Json::object(
    Map::from_array([
      ("rows", Json::array(rows)),
      ("truncated", Json::boolean(truncated)),
    ]),
  )
}

///|
/// JSON-in / JSON-out bridge. All semantics call public MoonBit SDK packages.
/// Synthetic identity settings are fixed here and never authorize release.
pub fn analyze(inputs_json : String, policy_json : String) -> String {
  try {
    if policy_json.length() > 16 * 1024 ||
      @utf8.encode(policy_json).length() > 16 * 1024 {
      raise invalid()
    }
    let inputs = decode_inputs(inputs_json)
    let policy = @policy.from_json(policy_json)
    let converted = @validation.convert_collection(
      inputs,
      policy,
      "987654321",
      Array::make(16, 1),
    )
    Json::object(
      Map::from_array([
        ("schema", Json::number(1.0)),
        ("status", Json::string("passed")),
        ("release_authorized", Json::boolean(false)),
        ("report", converted.public_report()),
        ("structures", Json::array(inputs.map(structure))),
      ]),
    ).stringify()
  } catch {
    error =>
      Json::object(
        Map::from_array([
          ("schema", Json::number(1.0)),
          ("status", Json::string("blocked")),
          ("release_authorized", Json::boolean(false)),
          ("issue", @explain.public_error(error)),
        ]),
      ).stringify()
  }
}
