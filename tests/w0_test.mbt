///|
async test "W0 state constructors reject invalid authority configuration" {
  let rejected = try {
    ignore(@authorization.Verifier::new("python", "wrong.py", []))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "W0 immutable validated snapshot and verified conversion through public facade" {
  let parsed = @parser.parse(
    object_bytes("A", "1.2.3", "1.2.10", "1.2.20", "20240228"),
  )
  let bytes = @dicom_writer.write_bytes(parsed, dataset=strict_dataset())
  let input = @typed.validate(bytes)
  assert_true(
    @explain.collection([input]).stringify().contains("collection-validated"),
  )
  assert_true(
    @explain.collection([input, input]).stringify().contains("blocked"),
  )
  let detached = input.private_dataset()
  detached.elements.clear()
  let original = input.private_dataset()
  assert_true(original.elements.length() > 0)
  let context = @identity.Context::new("12345", @policy.strict(), [14])
  context.prepare([original])
  let result = @typed.convert(input, context) catch {
    @model.MedSealError::RuleViolation(id, path, condition, stage) =>
      fail("\{id} \{path} \{condition} \{stage}")
    error => fail(error.code())
  }
  @conformance.check(
    @parser.parse(result.private_bytes()).dataset,
    full_pixels=true,
  )
  let explanation = result.public_decisions().stringify()
  assert_false(explanation.contains("SECRET"))
  assert_false(explanation.contains("20240228"))
  let legacy_context = @identity.Context::new("12345", @policy.research(), [14])
  legacy_context.prepare([original])
  let rejected = try {
    ignore(@typed.convert(input, legacy_context))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "W0 public errors do not reflect patient canaries or forged locations" {
  for
    error in [
      @model.MedSealError::IoError("/CANARY-PATIENT/input.dcm"),
      @model.MedSealError::UnsupportedTransferSyntax("CANARY-PATIENT"),
      @model.MedSealError::PolicyError("CANARY-PATIENT"),
      @model.MedSealError::RuleViolation(
        "CANARY-PATIENT", "dataset/0010,0010", "met", "vr",
      ),
      @model.MedSealError::RuleViolation(
        "attr-00100010", "dataset/CANARY-PATIENT", "met", "vr",
      ),
      @model.MedSealError::RuleViolation(
        "attr-00100010", "dataset/0010,0010", "CANARY-PATIENT", "vr",
      ),
    ] {
    assert_false(
      @explain.public_error(error).stringify().contains("CANARY-PATIENT"),
    )
  }
  assert_true(
    @explain.public_error(
      @model.MedSealError::RuleViolation(
        "attr-00100010", "dataset/0010,0010", "met", "vr",
      ),
    )
    .stringify()
    .contains("dataset/0010,0010"),
  )
}
