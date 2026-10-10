///|
test "full dates enforce calendars and leap years" {
  assert_true(@date.valid("20000229"))
  assert_false(@date.valid("19000229"))
  assert_false(@date.valid("20261301"))
  assert_false(@date.valid("20260431"))
  assert_false(@date.valid("00000101"))
}

///|
test "shifts preserve intervals across leap days and year ends" {
  assert_eq(@date.shift("20240228", 1), "20240229")
  assert_eq(@date.shift("20240229", 1), "20240301")
  assert_eq(@date.shift("20240101", -1), "20231231")
  assert_eq(@date.shift("20231231", 14), "20240114")
  assert_eq(@date.shift(@date.shift("20240229", 365), -365), "20240229")
  assert_eq(@date.shift("", 30), "")
}

///|
test "invalid and out of range dates fail explicitly" {
  let invalid = try {
    ignore(@date.shift("20250229", 1))
    false
  } catch {
    _ => true
  }
  let underflow = try {
    ignore(@date.shift("00010101", -1))
    false
  } catch {
    _ => true
  }
  let overflow = try {
    ignore(@date.shift("99991231", 1))
    false
  } catch {
    _ => true
  }
  assert_true(invalid && underflow && overflow)
}
