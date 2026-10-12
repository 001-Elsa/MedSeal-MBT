///|
pub(all) enum Action {
  Keep
  Empty
  Remove
  Replace(String)
} derive(Eq, Debug)

///|
pub(all) struct Rule {
  tag : @model.Tag
  action : Action
}

///|
pub struct Policy {
  scope_name : String
  date_shift_days : Int
  allow_external_references : Bool
  priv rules : Array[Rule]
  strict_metadata : Bool
  retain_dt : Bool
  priv path_rules : Array[PathRule]
}

///|
pub fn research(
  scope_name? : String = "research",
  date_shift_days? : Int = 30,
  allow_external_references? : Bool = false,
  rules? : Array[Rule] = [],
) -> Policy raise @model.MedSealError {
  if scope_name.is_empty() || scope_name.length() > 128 {
    raise @model.MedSealError::PolicyError(
      "scope_name must have 1 to 128 characters",
    )
  }
  if date_shift_days == 0 || date_shift_days < -3650 || date_shift_days > 3650 {
    raise @model.MedSealError::PolicyError(
      "date_shift_days must be nonzero and within 3650 days",
    )
  }
  let seen : Map[@model.Tag, Bool] = Map([])
  for rule in rules {
    if seen.contains(rule.tag) {
      raise @model.MedSealError::PolicyError("duplicate tag rule")
    }
    // Custom rules may reduce retained public descriptive metadata. Identity,
    // dates, pixel bytes and structural tags belong to built-in invariants.
    if !customizable(rule.tag) {
      raise @model.MedSealError::PolicyError(
        "custom rule tag is outside the supported descriptive fields",
      )
    }
    match rule.action {
      Replace(value) if value.any(fn(c) { c.to_int() > 127 || c.to_int() < 32 }) ||
        value.length() > 64 =>
        raise @model.MedSealError::PolicyError(
          "replacement must be printable ASCII within 64 characters",
        )
      _ => ()
    }
    seen.set(rule.tag, true)
  }
  {
    scope_name,
    date_shift_days,
    allow_external_references,
    rules: rules.copy(),
    strict_metadata: false,
    retain_dt: false,
    path_rules: [],
  }
}

///|
pub fn customizable(tag : @model.Tag) -> Bool {
  [
    @model.Tag::new(0x0008U, 0x1030U),
    @model.Tag::new(0x0008U, 0x103EU),
    @model.Tag::new(0x0018U, 0x1030U),
  ].contains(tag)
}

///|
pub fn Policy::action(self : Policy, tag : @model.Tag) -> Action? {
  for rule in self.rules {
    if rule.tag == tag {
      return Some(rule.action)
    }
  }
  if customizable(tag) {
    Some(Empty)
  } else {
    None
  }
}

///|
fn object(json : Json) -> Map[String, Json] raise @model.MedSealError {
  match json {
    Json::Object(value) => value
    _ => raise @model.MedSealError::PolicyError("expected JSON object")
  }
}

///|
fn string(json : Json?) -> String raise @model.MedSealError {
  match json {
    Some(Json::String(value)) => value
    _ => raise @model.MedSealError::PolicyError("expected string field")
  }
}

///|
pub fn parse_tag(value : String) -> @model.Tag raise @model.MedSealError {
  if value.length() != 8 {
    raise @model.MedSealError::PolicyError(
      "tag must have eight hexadecimal characters",
    )
  }
  let mut number = 0U
  for c in value {
    let digit = if c >= '0' && c <= '9' {
      c.to_int() - 48
    } else if c >= 'A' && c <= 'F' {
      c.to_int() - 55
    } else if c >= 'a' && c <= 'f' {
      c.to_int() - 87
    } else {
      -1
    }
    if digit < 0 {
      raise @model.MedSealError::PolicyError("tag is not hexadecimal")
    }
    number = number * 16U + digit.reinterpret_as_uint()
  }
  @model.Tag::new(number >> 16, number & 0xFFFFU)
}

///|
pub fn from_json(text : String) -> Policy raise @model.MedSealError {
  reject_duplicate_keys(text)
  let json = @json.parse(text) catch {
    _ => raise @model.MedSealError::PolicyError("invalid JSON")
  }
  let values = object(json)
  if values.get("version") == Some(Json::number(2.0)) {
    return strict_json(values)
  }
  for key in values.keys() {
    if ![
        "version", "mode", "namespace", "date_shift_days", "allow_external_references",
        "rules",
      ].contains(key) {
      raise @model.MedSealError::PolicyError("unknown policy field")
    }
  }
  if values.get("version") != Some(Json::number(1.0)) ||
    string(values.get("mode")) != "research" {
    raise @model.MedSealError::PolicyError(
      "only policy version 1 and research mode are supported",
    )
  }
  let scope_name = string(values.get("namespace"))
  let days = match values.get("date_shift_days") {
    Some(Json::Number(number, ..)) if number >= -3650.0 &&
      number <= 3650.0 &&
      number.to_int().to_double() == number => number.to_int()
    _ =>
      raise @model.MedSealError::PolicyError(
        "date_shift_days must be an integer",
      )
  }
  let external = match values.get("allow_external_references") {
    Some(Json::True) => true
    Some(Json::False) | None => false
    _ =>
      raise @model.MedSealError::PolicyError(
        "allow_external_references must be boolean",
      )
  }
  let rules : Array[Rule] = []
  match values.get("rules") {
    Some(Json::Array(items)) =>
      for item in items {
        let fields = object(item)
        for key in fields.keys() {
          if !["tag", "action", "value"].contains(key) {
            raise @model.MedSealError::PolicyError("unknown rule field")
          }
        }
        let tag = parse_tag(string(fields.get("tag")))
        let action = match string(fields.get("action")) {
          "keep" => Keep
          "empty" => Empty
          "remove" => Remove
          "replace" => Replace(string(fields.get("value")))
          _ => raise @model.MedSealError::PolicyError("unsupported action")
        }
        if !(action is Replace(_)) && fields.contains("value") {
          raise @model.MedSealError::PolicyError("only replace accepts a value")
        }
        rules.push({ tag, action, })
      }
    None => ()
    _ => raise @model.MedSealError::PolicyError("rules must be an array")
  }
  research(
    scope_name~,
    date_shift_days=days,
    allow_external_references=external,
    rules~,
  )
}

///|
pub extend Action with Eq::{equal, not_equal}

///|
pub extend Action with Debug::{to_repr}
