///|
/// A small, domain-neutral receipt that can be checked by another process.
fn main {
  let plan = @evidence_api.Plan::new(
    plan_id="demo-plan",
    input_digest=@evidence_api.sha256(b"input"),
    rule_digest=@evidence_api.sha256(b"rules"),
    tool_version="0.6.0",
    steps=[
      { id: "project", description: "keep declared fields", },
      { id: "rename", description: "apply caller-owned rename", },
    ],
  )
  let receipt = @evidence_api.Receipt::new(
    plan,
    output_digest=@evidence_api.sha256(b"output"),
    input_records=2,
    output_records=[
      {
        id: "out-1",
        sources: [{ source: "input.jsonl", record: "1", step: "project", }],
        changed_fields: ["display_name"],
      },
    ],
  )
  println(receipt.to_json().stringify())
  println(
    receipt
    .verify(
      plan,
      @evidence_api.sha256(b"input"),
      @evidence_api.sha256(b"output"),
    )
    .to_json()
    .stringify(),
  )
}
