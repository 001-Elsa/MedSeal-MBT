///|
async fn main {
  let source = @parser.parse(@storage.read("samples/valid/pixel-data.dcm"))
  @async_fs.mkdir("tmp", allow_exist=true)
  let root = "tmp/demo-\{@storage.token()}"
  @storage.mkdir(root)
  let input = "\{root}/input"
  @storage.mkdir(input)
  for index = 0; index < 4; index = index + 1 {
    let sop = "1.2.826.0.1.3680043.10.543.1.\{index + 1}"
    let patient = if index < 2 { "DEMO-A" } else { "DEMO-B" }
    let study = if index < 2 {
      "1.2.826.0.1.3680043.10.543.2.1"
    } else {
      "1.2.826.0.1.3680043.10.543.2.2"
    }
    let series = "1.2.826.0.1.3680043.10.543.3.\{index + 1}"
    let dataset = source.dataset
      .replace_text(@model.Tag::new(0x0010U, 0x0020U), patient)
      .replace_text(@model.Tag::new(0x0008U, 0x0018U), sop)
      .replace_text(@model.Tag::new(0x0020U, 0x000DU), study)
      .replace_text(@model.Tag::new(0x0020U, 0x000EU), series)
    let date = if index % 2 == 0 { "20240228" } else { "20240313" }
    let elements = dataset.elements.copy()
    elements.push(
      @model.DataElement::new(
        @model.Tag::new(0x0008U, 0x0020U),
        @model.Vr::DA,
        0U,
        @model.ElementValue::Text(date),
        0,
      ),
    )
    if index % 2 == 0 {
      let target = "1.2.826.0.1.3680043.10.543.1.\{index + 2}"
      let item = @model.DataSet::new([
        @model.DataElement::new(
          @model.Tag::new(0x0008U, 0x1150U),
          @model.Vr::UI,
          0U,
          @model.ElementValue::Text("1.2.840.10008.5.1.4.1.1.7"),
          0,
        ),
        @model.DataElement::new(
          @model.Tag::new(0x0008U, 0x1155U),
          @model.Vr::UI,
          0U,
          @model.ElementValue::Text(target),
          0,
        ),
      ])
      elements.push(
        @model.DataElement::new(
          @model.Tag::new(0x0008U, 0x1140U),
          @model.Vr::SQ,
          0U,
          @model.ElementValue::Sequence([item]),
          0,
        ),
      )
    }
    let file : @parser.ParsedFile = {
      ..source,
      dataset: @model.DataSet::new(elements),
      file_meta: source.file_meta.replace_text(
        @model.Tag::new(0x0002U, 0x0003U),
        sop,
      ),
    }
    @storage.write_new(
      "\{input}/source-\{index + 1}.dcm",
      @dicom_writer.write_bytes(file),
    )
  }
  let policy = @policy.research()
  let job = @batch.plan(input, policy)
  println(job.preview())
  println(job.execute("\{root}/output"))
  println(@batch.verify("\{root}/output"))
  println("Synthetic demonstration saved to \{root}")
}
