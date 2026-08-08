///|
test "parse anonymize options" {
  let command = parse_command([
    "anonymize", "in.dcm", "--output", "out.dcm", "--report", "report.json", "--remove-private",
    "--force",
  ])
  assert_true(
    command is Anonymize("in.dcm", "out.dcm", Some("report.json"), true, true),
  )
}

///|
test "missing output is an argument error" {
  let rejected = try {
    ignore(parse_command(["anonymize", "in.dcm"]))
    false
  } catch {
    @model.MedSealError::InvalidArgument(_) => true
    _ => false
  }
  assert_true(rejected)
}
