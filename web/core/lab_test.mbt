///|
test "lab bridge rejects malformed input and policy without echoing source text" {
  for input in ["not-json", "[]", "[1]", "[\"not-hex\"]", "[\"0000\"]"] {
    let result = @json.parse(@core.analyze(input, "SECRET-POLICY-CANARY"))
    match result {
      Json::Object(fields) => {
        assert_eq(fields.get("status"), Some(Json::string("blocked")))
        assert_eq(fields.get("release_authorized"), Some(Json::boolean(false)))
        assert_true(!result.stringify().contains("SECRET-POLICY-CANARY"))
        assert_true(!result.stringify().contains("not-hex"))
      }
      _ => fail("expected structured error")
    }
  }
}

///|
test "lab bridge rejects transport and policy budgets before decoding" {
  let input = String::make(2 * 1024 * 1024 + 1, 'x')
  assert_true(@core.analyze(input, "{}").contains("MEDSEAL-E501"))
  assert_true(
    @core.analyze("[]", String::make(16 * 1024 + 1, 'x')).contains(
      "MEDSEAL-E501",
    ),
  )
}
