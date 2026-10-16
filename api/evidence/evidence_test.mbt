///|
test "receipt binds input, plan and output" {
  assert_eq(
    @evidence.sha256(b"abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
  let plan = @evidence.Plan::new(
    plan_id="plan-1",
    input_digest="in-1",
    rule_digest="rules-1",
    tool_version="0.6.0",
    steps=[{ id: "project", description: "select declared fields", }],
  )
  let receipt = @evidence.Receipt::new(
    plan,
    output_digest="out-1",
    input_records=2,
    output_records=[
      {
        id: "row-1",
        sources: [{ source: "input.jsonl", record: "1", step: "project", }],
        changed_fields: ["name"],
      },
    ],
  )
  let result = receipt.verify(plan, "in-1", "out-1")
  assert_true(result.valid)
  assert_eq(result.code, "OK")
  assert_true(
    receipt.to_json().stringify().contains("medseal-evidence-receipt-v1"),
  )
}

///|
test "receipt rejects changed input, output and plan" {
  let plan = @evidence.Plan::new(
    plan_id="plan-1",
    input_digest="in-1",
    rule_digest="rules-1",
    tool_version="0.6.0",
    steps=[],
  )
  let receipt = @evidence.Receipt::new(
    plan,
    output_digest="out-1",
    input_records=0,
    output_records=[],
  )
  assert_false(receipt.verify(plan, "in-2", "out-1").valid)
  assert_eq(receipt.verify(plan, "in-1", "out-2").code, "OUTPUT_CHANGED")
  let other = @evidence.Plan::new(
    plan_id="plan-2",
    input_digest="in-1",
    rule_digest="rules-2",
    tool_version="0.6.0",
    steps=[],
  )
  assert_eq(receipt.verify(other, "in-1", "out-1").code, "PLAN_MISMATCH")
  let incomplete = @evidence.Receipt::new(
    plan,
    output_digest="out-1",
    input_records=1,
    output_records=[{ id: "row-1", sources: [], changed_fields: [], }],
  )
  assert_eq(incomplete.verify(plan, "in-1", "out-1").code, "PROVENANCE")
}
