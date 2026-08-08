///|
test "all committed valid samples parse and validate" {
  for
    name in [
      "minimal-valid.dcm", "patient-fields.dcm", "private-tags.dcm", "nested-sequence.dcm",
      "pixel-data.dcm",
    ] {
    let parsed = @parser.parse(@fs.read_file_to_bytes("samples/valid/\{name}"))
    let report = @validator.validate(parsed)
    assert_true(report.is_valid())
  }
}

///|
test "unsupported transfer syntax is rejected" {
  let rejected = try {
    ignore(
      @parser.parse(
        @fs.read_file_to_bytes(
          "samples/invalid/unsupported-transfer-syntax.dcm",
        ),
      ),
    )
    false
  } catch {
    @model.MedSealError::UnsupportedTransferSyntax(_) => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "malformed samples are rejected structurally" {
  for
    name in ["truncated-element.dcm", "invalid-vr.dcm", "invalid-sequence.dcm"] {
    let rejected = try {
      ignore(@parser.parse(@fs.read_file_to_bytes("samples/invalid/\{name}")))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
