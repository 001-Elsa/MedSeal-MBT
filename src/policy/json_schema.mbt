///|
priv struct KeyFrame {
  keys : Map[String, Bool]
  object : Bool
  mut expects_key : Bool
}

///|
fn reject_duplicate_keys(text : String) -> Unit raise @model.MedSealError {
  if @utf8.encode(text).length() > 1024 * 1024 {
    raise @model.MedSealError::PolicyError("policy exceeds 1 MiB")
  }
  let chars = text.to_array()
  let stack : Array[KeyFrame] = []
  let mut i = 0
  while i < chars.length() {
    match chars[i] {
      '{' | '[' => {
        if stack.length() > 64 {
          raise @model.MedSealError::PolicyError(
            "policy JSON nesting exceeds 64",
          )
        }
        stack.push({
          keys: Map([]),
          object: chars[i] == '{',
          expects_key: chars[i] == '{',
        })
      }
      '}' | ']' => if !stack.is_empty() { ignore(stack.pop()) }
      ',' =>
        if stack.last() is Some(frame) && frame.object {
          frame.expects_key = true
        }
      '"' => {
        let start = i
        i = i + 1
        while i < chars.length() {
          if chars[i] == '\\' {
            i = i + 2
          } else if chars[i] == '"' {
            break
          } else {
            i = i + 1
          }
        }
        if i >= chars.length() {
          raise @model.MedSealError::PolicyError("unterminated JSON string")
        }
        if stack.last() is Some(frame) && frame.object && frame.expects_key {
          let key_json = String::from_array(chars[start:i + 1].to_owned())
          let key = match (@json.parse(key_json) catch { _ => Json::null() }) {
            Json::String(key) => key
            _ => raise @model.MedSealError::PolicyError("invalid JSON key")
          }
          if frame.keys.contains(key) {
            raise @model.MedSealError::PolicyError("duplicate JSON key")
          }
          frame.keys.set(key, true)
          frame.expects_key = false
        }
      }
      _ => ()
    }
    i = i + 1
  }
}

///|
fn strict_json(values : Map[String, Json]) -> Policy raise @model.MedSealError {
  for key in values.keys() {
    if !["version", "mode", "namespace", "date_shift_days", "path_rules"].contains(
        key,
      ) {
      raise @model.MedSealError::PolicyError("unknown strict policy field")
    }
  }
  if string(values.get("mode")) != "strict" {
    raise @model.MedSealError::PolicyError("version 2 requires strict mode")
  }
  let scope_name = string(values.get("namespace"))
  let days = match values.get("date_shift_days") {
    Some(Json::Number(n, ..)) if n >= -3650.0 &&
      n <= 3650.0 &&
      n.to_int().to_double() == n => n.to_int()
    _ => raise @model.MedSealError::PolicyError("invalid date_shift_days")
  }
  let items = match values.get("path_rules") {
    None => []
    Some(Json::Array(items)) if items.length() <= 1000 => items
    _ =>
      raise @model.MedSealError::PolicyError(
        "path_rules must be an array within 1000 entries",
      )
  }
  let rules : Array[PathRule] = []
  for item in items {
    let fields = object(item)
    for key in fields.keys() {
      if ![
          "id", "path", "action", "value", "priority", "when_sop", "when_present",
        ].contains(key) {
        raise @model.MedSealError::PolicyError("unknown strict rule field")
      }
    }
    let action = match string(fields.get("action")) {
      "empty" => Empty
      "remove" => Remove
      "replace" => Replace(string(fields.get("value")))
      _ =>
        raise @model.MedSealError::PolicyError(
          "strict action must be empty/remove/replace",
        )
    }
    if !(action is Replace(_)) && fields.contains("value") {
      raise @model.MedSealError::PolicyError("only replace accepts value")
    }
    let priority = match fields.get("priority") {
      Some(Json::Number(n, ..)) if n >= -1000.0 &&
        n <= 1000.0 &&
        n.to_int().to_double() == n => n.to_int()
      _ =>
        raise @model.MedSealError::PolicyError(
          "priority must be an integer within 1000",
        )
    }
    let sop = if fields.contains("when_sop") {
      Some(string(fields.get("when_sop")))
    } else {
      None
    }
    let present = if fields.contains("when_present") {
      Some(parse_tag(string(fields.get("when_present"))))
    } else {
      None
    }
    rules.push({
      id: string(fields.get("id")),
      path: string(fields.get("path")),
      action,
      priority,
      sop,
      present,
    })
  }
  strict(scope_name~, date_shift_days=days, path_rules=rules)
}
