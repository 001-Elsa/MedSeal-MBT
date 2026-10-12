///|
test "temporal-precision-valid and temporal-precision-invalid: independent calendar, precision and offset boundaries" {
  for
    (value, expected, precision, fraction, zone) in [
      (
        "20240229235959.123456+0800",
        "20240314235959.123456+0800",
        14,
        6,
        Some(480),
      ),
      ("2024022923-1200", "2024031423-1200", 10, 0, Some(-720)),
      ("20240229+1400", "20240314+1400", 8, 0, Some(840)),
      ("20240229123456.0+0000", "20240314123456.0+0000", 14, 1, Some(0)),
      ("202402291234", "202403141234", 12, 0, None),
      ("202402", "", 6, 0, None),
      ("2007-0500", "", 4, 0, Some(-300)),
    ] {
    let parsed = @date.parse_dt(value).unwrap()
    assert_eq(parsed.precision, precision)
    assert_eq(parsed.fractional_digits, fraction)
    assert_eq(parsed.zone_minutes, zone)
    assert_eq(@date.shift_dt(value, 14), expected)
  }
  assert_eq(@date.shift_dt("20000229235959", 1), "20000301235959")
  assert_eq(@date.shift_dt("19000228235959", 1), "19000301235959")
  assert_eq(@date.shift_dt("20240101000000", -1), "20231231000000")
  assert_eq(@date.shift_dt("", 14), "")
  assert_true(@date.parse_dt("") is None)
  assert_true(@date.parse_tm("") is None)
  for
    invalid in [
      "202", "202413", "19000229", "20230229", "2024022924", "20240229235961", "20240229235959.",
      "20240229235959.1234567", "20240229235959-0000", "20240229235959+1401", "20240229235959-1201",
      "20240229235959+1260", "20240229.1", " 20240229", "2024 229",
    ] {
    assert_false(@date.valid_dt(invalid), msg=invalid)
  }
  for value in ["00", "0000", "000000", "235959.123456", "235960"] {
    assert_true(@date.valid_tm(value), msg=value)
  }
  for
    value in [
      "2", "2400", "12.5", "123456.", "123456.1234567", "12:34:56", "1260", "235961",
      "123456+0800",
    ] {
    assert_false(@date.valid_tm(value), msg=value)
  }
  assert_true(@date.parse_dt("20161231235960+0000").unwrap().leap_second)
  assert_true(@date.parse_tm("235960").unwrap().leap_second)
  let refused = try {
    ignore(@date.shift_dt("20161231235960+0000", 14))
    false
  } catch {
    @model.MedSealError::RuleViolation(
      "temporal-precision",
      _,
      "unknown",
      "temporal"
    ) => true
    _ => false
  }
  assert_true(refused)
  for value in ["00010101", "99991231"] {
    let rejected = try {
      ignore(
        @date.shift_dt(value, if value.has_prefix("0001") { -1 } else { 1 }),
      )
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
