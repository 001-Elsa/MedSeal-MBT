///|
fn main {
  try {
    let inputs = linked_pair()
    let datasets = inputs.map(input => @dicom.parse(input).dataset)
    let columns : Array[@query.Column] = [
      {
        name: "modality",
        path: [@query.Step::Field(@dicom.Tag::new(0x0008U, 0x0060U))],
      },
      {
        name: "rows",
        path: [@query.Step::Field(@dicom.Tag::new(0x0028U, 0x0010U))],
      },
    ]
    let selected = @query.select(datasets, [
      @query.Predicate::Equals(columns[0].path, "OT"),
      @query.Predicate::IntegerRange(columns[1].path, 2L, 2L),
    ])
    if selected != [0, 1] {
      abort("selection contract")
    }
    println(@query.summary(datasets, columns).stringify())
    println(@query.project(datasets, columns).private_csv())
    println(@query.project(datasets, columns).private_jsonl())
    let quality = @quality.check(inputs)
    if !quality.ready() {
      abort("quality contract")
    }
    println(quality.public_json().stringify())
    let options = @validation.ConversionOptions::new(
      policy=@policy.strict(),
      uid_seed="987654321",
      date_offsets=[7],
    )
    let plan = @validation.plan_collection(inputs, options)
    println(plan.public_report().stringify())
    let result = plan.execute()
    for i in 0..<result.length() {
      println("synthetic-output-\{i}:\{@hex.encode(result.private_bytes(i))}")
    }
    println("data-pipeline-ok")
  } catch {
    _ => abort("data pipeline failed")
  }
}
