///|
/// Private value semantics. This type is never serialized in public reports.
pub struct Temporal {
  precision : Int
  fractional_digits : Int
  zone_minutes : Int?
  leap_second : Bool
  priv value : String
}

///|
fn decimal(value : String, start : Int, count : Int) -> Int {
  let mut n = 0
  for i in start..<(start + count) {
    n = n * 10 + value[i].to_int() - 48
  }
  n
}

///|
fn digits(value : String) -> Bool {
  !value.is_empty() && value.all(fn(c) { c >= '0' && c <= '9' })
}

///|
/// DICOM offsets range from -1200 through +1400; -0000 is forbidden.
pub fn valid_zone(value : String) -> Bool {
  if value.length() != 5 ||
    !(value[0] == '+' || value[0] == '-') ||
    !digits(value[1:].to_owned()) {
    return false
  }
  let hours = decimal(value, 1, 2)
  let minutes = decimal(value, 3, 2)
  let total = hours * 60 + minutes
  minutes < 60 &&
  (if value[0] == '-' { total > 0 && total <= 720 } else { total <= 840 })
}

///|
fn clock(value : String, datetime : Bool) -> (Int, Int, Bool)? {
  let parts = value.split(".").to_array()
  if parts.length() > 2 {
    return None
  }
  let body = parts[0].to_owned()
  let size = body.length()
  if !digits(body) ||
    !(if datetime {
      [4, 6, 8, 10, 12, 14].contains(size)
    } else {
      [2, 4, 6].contains(size)
    }) {
    return None
  }
  let fractional = if parts.length() == 2 {
    if size != (if datetime { 14 } else { 6 }) ||
      parts[1].length() > 6 ||
      !digits(parts[1].to_owned()) {
      return None
    }
    parts[1].length()
  } else {
    0
  }
  let start = if datetime { 8 } else { 0 }
  if datetime {
    let year = decimal(body, 0, 4)
    if year < 1 {
      return None
    } // selected Gregorian research domain, years 1..9999
    if size >= 6 {
      let month = decimal(body, 4, 2)
      if month < 1 || month > 12 {
        return None
      }
    }
    if size >= 8 && !valid(body[0:8].to_owned()) {
      return None
    }
  }
  if size >= start + 2 && decimal(body, start, 2) > 23 {
    return None
  }
  if size >= start + 4 && decimal(body, start + 2, 2) > 59 {
    return None
  }
  if size >= start + 6 && decimal(body, start + 4, 2) > 60 {
    return None
  }
  Some(
    (size, fractional, size >= start + 6 && decimal(body, start + 4, 2) == 60),
  )
}

///|
/// Empty, missing and truncated precision are distinct; None means empty.
pub fn parse_dt(value : String) -> Temporal? raise @model.MedSealError {
  if value.is_empty() {
    return None
  }
  let (body, zone) = if value.length() >= 5 &&
    (value[value.length() - 5] == '+' || value[value.length() - 5] == '-') {
    let suffix = value[value.length() - 5:].to_owned()
    if !valid_zone(suffix) {
      raise @model.MedSealError::IdentityError("invalid DT offset")
    }
    let magnitude = decimal(suffix, 1, 2) * 60 + decimal(suffix, 3, 2)
    (
      value[0:value.length() - 5].to_owned(),
      Some(if suffix[0] == '-' { -magnitude } else { magnitude }),
    )
  } else {
    (value, None)
  }
  let (precision, fractional_digits, leap_second) = match clock(body, true) {
    Some(info) => info
    None =>
      raise @model.MedSealError::IdentityError("invalid DT precision or value")
  }
  Some({ precision, fractional_digits, zone_minutes: zone, leap_second, value, })
}

///|
pub fn parse_tm(value : String) -> Temporal? raise @model.MedSealError {
  if value.is_empty() {
    return None
  }
  let (precision, fractional_digits, leap_second) = match clock(value, false) {
    Some(info) => info
    None =>
      raise @model.MedSealError::IdentityError("invalid TM precision or value")
  }
  Some({ precision, fractional_digits, zone_minutes: None, leap_second, value, })
}

///|
pub fn valid_dt(value : String) -> Bool {
  try {
    ignore(parse_dt(value))
    true
  } catch {
    _ => false
  }
}

///|
pub fn valid_tm(value : String) -> Bool {
  try {
    ignore(parse_tm(value))
    true
  } catch {
    _ => false
  }
}

///|
/// Shift only a present full calendar day. Never add precision or invent UTC.
/// Low precision is cleared. Leap seconds require an explicit separate profile.
pub fn shift_dt(value : String, days : Int) -> String raise @model.MedSealError {
  if days < -3650 || days > 3650 {
    raise @model.MedSealError::PolicyError("DT shift outside budget")
  }
  match parse_dt(value) {
    None => ""
    Some(parsed) if parsed.precision < 8 => ""
    Some(parsed) if parsed.leap_second && days != 0 =>
      raise @model.MedSealError::RuleViolation(
        "temporal-precision", "dataset/0008,002A", "unknown", "temporal",
      )
    Some(parsed) =>
      shift(parsed.value[0:8].to_owned(), days) + parsed.value[8:].to_owned()
  }
}
