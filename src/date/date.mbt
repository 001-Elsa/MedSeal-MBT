///|
fn leap(year : Int) -> Bool {
  year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

///|
fn days_in_month(year : Int, month : Int) -> Int {
  match month {
    2 => if leap(year) { 29 } else { 28 }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
}

///|
fn parse_date(value : String) -> (Int, Int, Int)? {
  if value.length() != 8 || !value.all(fn(c) { c >= '0' && c <= '9' }) {
    return None
  }
  let digits = value.to_array().map(fn(c) { c.to_int() - 48 })
  let year = digits[0] * 1000 + digits[1] * 100 + digits[2] * 10 + digits[3]
  let month = digits[4] * 10 + digits[5]
  let day = digits[6] * 10 + digits[7]
  if year < 1 ||
    month < 1 ||
    month > 12 ||
    day < 1 ||
    day > days_in_month(year, month) {
    None
  } else {
    Some((year, month, day))
  }
}

///|
pub fn valid(value : String) -> Bool {
  value.is_empty() || parse_date(value) is Some(_)
}

///|
pub fn shift(value : String, days : Int) -> String raise @model.MedSealError {
  if value.is_empty() {
    return value
  }
  if days < -3650 || days > 3650 {
    raise @model.MedSealError::PolicyError(
      "date shift must be within 3650 days",
    )
  }
  let (initial_year, initial_month, initial_day) = match parse_date(value) {
    Some(date) => date
    None => raise @model.MedSealError::IdentityError("invalid full DA value")
  }
  let mut year = initial_year
  let mut month = initial_month
  let mut day = initial_day
  for i = 0; i < days.abs(); i = i + 1 {
    if days > 0 {
      day = day + 1
      if day > days_in_month(year, month) {
        day = 1
        month = month + 1
        if month > 12 {
          month = 1
          year = year + 1
        }
      }
    } else {
      day = day - 1
      if day == 0 {
        month = month - 1
        if month == 0 {
          month = 12
          year = year - 1
        }
        day = days_in_month(year, month)
      }
    }
    if year < 1 || year > 9999 {
      raise @model.MedSealError::IdentityError("shifted date is out of range")
    }
  }
  let y = if year < 10 {
    "000\{year}"
  } else if year < 100 {
    "00\{year}"
  } else if year < 1000 {
    "0\{year}"
  } else {
    year.to_string()
  }
  let m = if month < 10 { "0\{month}" } else { month.to_string() }
  let d = if day < 10 { "0\{day}" } else { day.to_string() }
  "\{y}\{m}\{d}"
}
