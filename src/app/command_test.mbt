///|
test "parse anonymize options" {
  let command = @app.parse_command([
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
    ignore(@app.parse_command(["anonymize", "in.dcm"]))
    false
  } catch {
    @model.MedSealError::InvalidArgument(_) => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "inspect and validate accept JSON output" {
  assert_true(
    @app.parse_command(["inspect", "in.dcm", "--json"])
    is Inspect("in.dcm", true),
  )
  assert_true(
    @app.parse_command(["validate", "in.dcm", "--json"])
    is Validate("in.dcm", true),
  )
  assert_true(
    @app.parse_command(["inspect", "in.dcm"]) is Inspect("in.dcm", false),
  )
  assert_true(
    @app.parse_command(["validate", "in.dcm"]) is Validate("in.dcm", false),
  )
}

///|
test "top-level help and version aliases are recognized" {
  assert_true(@app.parse_command([]) is Help(None))
  assert_true(@app.parse_command(["--help"]) is Help(None))
  assert_true(@app.parse_command(["-h"]) is Help(None))
  assert_true(@app.parse_command(["--version"]) is Version)
  assert_true(@app.parse_command(["-V"]) is Version)
}

///|
test "subcommand help is recognized before input validation" {
  assert_true(
    @app.parse_command(["inspect", "--help"]) is Help(Some("inspect")),
  )
  assert_true(@app.parse_command(["validate", "-h"]) is Help(Some("validate")))
  assert_true(
    @app.parse_command(["anonymize", "--help"]) is Help(Some("anonymize")),
  )
}

///|
fn rejects_arguments(args : Array[String]) -> Bool {
  try {
    ignore(@app.parse_command(args))
    false
  } catch {
    @model.MedSealError::InvalidArgument(_) => true
    _ => false
  }
}

///|
test "missing input is rejected for every operational command" {
  assert_true(rejects_arguments(["inspect"]))
  assert_true(rejects_arguments(["validate"]))
  assert_true(rejects_arguments(["anonymize"]))
}

///|
test "unknown commands and options are rejected" {
  assert_true(rejects_arguments(["scan", "in.dcm"]))
  assert_true(rejects_arguments(["inspect", "in.dcm", "--force"]))
  assert_true(rejects_arguments(["validate", "in.dcm", "extra.dcm"]))
  assert_true(
    rejects_arguments(["anonymize", "in.dcm", "--output", "out.dcm", "--json"]),
  )
}

///|
test "options requiring values reject a missing value" {
  assert_true(rejects_arguments(["anonymize", "in.dcm", "--output"]))
  assert_true(
    rejects_arguments(["anonymize", "in.dcm", "--output", "out.dcm", "--report"]),
  )
}

///|
test "anonymize flags can appear in any supported order" {
  let command = @app.parse_command([
    "anonymize", "in.dcm", "--remove-private", "--report", "audit.json", "--force",
    "--output", "out.dcm",
  ])
  assert_true(
    command is Anonymize("in.dcm", "out.dcm", Some("audit.json"), true, true),
  )
}

///|
test "help text documents all stable entry points" {
  let root = @app.help_text(None)
  assert_true(root.contains("medseal inspect"))
  assert_true(root.contains("medseal validate"))
  assert_true(root.contains("medseal anonymize"))
  assert_true(root.contains("medseal --version"))
  assert_true(@app.help_text(Some("inspect")).contains("[--json]"))
  assert_true(@app.help_text(Some("validate")).contains("[--json]"))
  let anonymize = @app.help_text(Some("anonymize"))
  assert_true(anonymize.contains("--output <output>"))
  assert_true(anonymize.contains("--remove-private"))
  assert_true(anonymize.contains("--force"))
}
