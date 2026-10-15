///|
fn path(g : UInt, e : UInt) -> Array[@query.Step] {
  [@query.Step::Field(@dicom.Tag::new(g, e))]
}

///|
fn text_dataset(value : String) -> @dicom.DataSet {
  @dicom.DataSet::new([
    @dicom.DataElement::new(
      @dicom.Tag::new(0x0010U, 0x0010U),
      @dicom.Vr::PN,
      0U,
      @dicom.ElementValue::Text(value),
      0,
    ),
  ])
}

///|
test "query exact integer VM missing and type errors" {
  let dataset = @dicom.parse(object("1.2.3.4")).dataset
  assert_eq(@query.integer(dataset, path(0x0028U, 0x0010U)), 2L)
  assert_true(
    try {
      ignore(@query.scalar(dataset, path(0x0099U, 0x0001U)))
      false
    } catch {
      @query.QueryError::Missing => true
      _ => false
    },
  )
  assert_true(
    try {
      ignore(@query.values(dataset, path(0x7FE0U, 0x0010U)))
      false
    } catch {
      @query.QueryError::TypeMismatch => true
      _ => false
    },
  )
  assert_true(
    try {
      ignore(@query.scalar(text_dataset("A\\B"), path(0x0010U, 0x0010U)))
      false
    } catch {
      @query.QueryError::MultipleValues => true
      _ => false
    },
  )
  assert_eq(
    @query.integer(text_dataset("+9007199254740991"), path(0x0010U, 0x0010U)),
    9007199254740991L,
  )
  assert_eq(@query.integer(text_dataset("-12"), path(0x0010U, 0x0010U)), -12L)
  for bad in ["9007199254740992", "1.5", "1e2", "-", "--2", ""] {
    assert_true(
      try {
        ignore(@query.integer(text_dataset(bad), path(0x0010U, 0x0010U)))
        false
      } catch {
        @query.QueryError::InvalidNumber => true
        _ => false
      },
    )
  }
}

///|
test "nested sequence lookup is explicit and bounded" {
  let dataset = @dicom.parse(linked_pair()[1]).dataset
  let nested = [
    @query.Step::Item(@dicom.Tag::new(0x0008U, 0x1140U), 0),
    @query.Step::Field(@dicom.Tag::new(0x0008U, 0x1155U)),
  ]
  assert_eq(@query.scalar(dataset, nested), "1.2.826.0.1.999.1")
  assert_true(
    try {
      ignore(@query.lookup(dataset, []))
      false
    } catch {
      @query.QueryError::InvalidPath => true
      _ => false
    },
  )
  assert_true(
    try {
      ignore(
        @query.lookup(dataset, [
          @query.Step::Item(@dicom.Tag::new(0x0008U, 0x1140U), -1),
        ]),
      )
      false
    } catch {
      @query.QueryError::InvalidPath => true
      _ => false
    },
  )
}

///|
test "CSV quotes multiline values and guards formulas" {
  let columns : Array[@query.Column] = [
    { name: "name", path: path(0x0010U, 0x0010U), },
  ]
  let table = @query.project(
    [
      text_dataset("=1+1"),
      text_dataset(" \t@SUM(1)"),
      text_dataset("A,\"B\"\nC"),
    ],
    columns,
  )
  assert_eq(
    table.private_csv(),
    "\"name\"\r\n\"'=1+1\"\r\n\"' \t@SUM(1)\"\r\n\"A,\"\"B\"\"\nC\"\r\n",
  )
  assert_true(table.private_jsonl().contains("=1+1"))
}

///|
test "JSONL preserves absent empty and multiple values" {
  let columns : Array[@query.Column] = [
    { name: "name", path: path(0x0010U, 0x0010U), },
  ]
  let empty = @dicom.DataSet::new([
    @dicom.DataElement::new(
      @dicom.Tag::new(0x0010U, 0x0010U),
      @dicom.Vr::PN,
      0U,
      @dicom.ElementValue::Empty,
      0,
    ),
  ])
  assert_eq(
    @query.project(
      [@dicom.DataSet::empty(), empty, text_dataset("A\\B")],
      columns,
    ).private_jsonl(),
    "{\"name\":null}\n{\"name\":[]}\n{\"name\":[\"A\",\"B\"]}\n",
  )
  let groups = @query.group_counts(
    [@dicom.DataSet::empty(), empty, text_dataset("A\\B"), text_dataset("A\\B")],
    columns[0].path,
  )
  assert_eq(groups.length(), 3)
  assert_true(groups.contains(("[\"A\",\"B\"]", 2)))
}

///|
test "filter uses AND numeric range and missing semantics" {
  let datasets = linked_pair().map(input => @dicom.parse(input).dataset)
  assert_eq(
    @query.select(datasets, [
      @query.Predicate::Equals(path(0x0008U, 0x0060U), "OT"),
      @query.Predicate::IntegerRange(path(0x0028U, 0x0010U), 2L, 2L),
    ]),
    [0, 1],
  )
  assert_eq(
    @query.select(datasets, [@query.Predicate::Exists(path(0x0099U, 0x0001U))]),
    [],
  )
  assert_true(
    try {
      ignore(
        @query.select(datasets, [
          @query.Predicate::IntegerRange(path(0x0028U, 0x0010U), 3L, 2L),
        ]),
      )
      false
    } catch {
      @query.QueryError::InvalidNumber => true
      _ => false
    },
  )
}

///|
test "public inventory never includes patient UID or raw dates" {
  let datasets = linked_pair().map(input => @dicom.parse(input).dataset)
  let report = @query.summary(datasets, [
    { name: "name", path: path(0x0010U, 0x0010U), },
    { name: "absent", path: path(0x0099U, 0x0001U), },
  ]).stringify()
  for secret in ["SDKCANARY", "1.2.826", "20240229"] {
    assert_true(!report.contains(secret))
  }
  assert_true(report.contains("\"absent\":2"))
  assert_true(report.contains("\"series\":1"))
}

///|
test "quality rejects duplicate SOP and missing reference instead of passing subset" {
  let inputs = linked_pair()
  assert_true(@quality.check(inputs).ready())
  let duplicated = @quality.check([inputs[0], inputs[0]])
  assert_true(!duplicated.ready())
  assert_eq(duplicated.collection_state, @quality.CheckState::Failed)
  assert_true(!@quality.check([inputs[1]]).ready())
  let broken = @quality.check([inputs[0], b"invalid"])
  assert_eq(broken.objects, 2)
  assert_eq(broken.collection_state, @quality.CheckState::NotChecked)
  assert_true(!broken.ready())
  for secret in ["SDKCANARY", "1.2.826", "invalid"] {
    assert_true(!broken.public_json().stringify().contains(secret))
  }
}

///|
test "quality labels unsupported syntax separately" {
  assert_eq(@quality.check([]).object_state, @quality.CheckState::NotChecked)
  let input = object("1.2.3.4")
  let file = @dicom.parse(input)
  let wrong = {
    ..file,
    dataset: file.dataset.remove(@dicom.Tag::new(0x0028U, 0x0010U)),
  }
  assert_true(!@quality.check([@dicom.write(wrong)]).ready())
}

///|
test "plan owns source array offsets and respects lowered budgets" {
  let inputs = linked_pair()
  let offsets = [7]
  let options = @validation.ConversionOptions::new(
    policy=@policy.strict(),
    uid_seed="123456789",
    date_offsets=offsets,
  )
  let plan = @validation.plan_collection(inputs, options)
  offsets[0] = 0
  inputs[0] = b"changed"
  let result = plan.execute()
  assert_eq(result.length(), 2)
  assert_eq(
    @query.scalar(
      @dicom.parse(result.private_bytes(0)).dataset,
      path(0x0008U, 0x0020U),
    ),
    "20240307",
  )
  for secret in ["123456789", "SDKCANARY", "20240229"] {
    assert_true(!plan.public_report().stringify().contains(secret))
  }
  let small = @validation.ConversionOptions::new(
    policy=@policy.strict(),
    uid_seed="123456789",
    date_offsets=[7],
    budget=@validation.Budget::new(max_objects=1),
  )
  assert_true(
    try {
      ignore(@validation.plan_collection(linked_pair(), small))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "plan fails before execute for broken relations and invalid configuration" {
  let options = @validation.ConversionOptions::new(
    policy=@policy.strict(),
    uid_seed="123456789",
    date_offsets=[7],
  )
  assert_true(
    try {
      ignore(@validation.plan_collection([linked_pair()[1]], options))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(@validation.Budget::new(max_objects=10000))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(
        @validation.ConversionOptions::new(
          policy=@policy.strict(),
          uid_seed="0",
          date_offsets=[7],
        ),
      )
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(
        @validation.ConversionOptions::new(
          policy=@policy.strict(),
          uid_seed="123",
          date_offsets=[0],
        ),
      )
      false
    } catch {
      _ => true
    },
  )
}

///|
test "named patient dates reject duplicate missing and extra bindings" {
  let options = @validation.ConversionOptions::for_patients(
    policy=@policy.strict(),
    uid_seed="123456789",
    patients=[{ patient_id: "SDKCANARY-ID", issuer: "", days: 7, }],
  )
  assert_eq(
    @validation.plan_collection(linked_pair(), options).execute().length(),
    2,
  )
  let wrong = @validation.ConversionOptions::for_patients(
    policy=@policy.strict(),
    uid_seed="123456789",
    patients=[{ patient_id: "wrong", issuer: "", days: 7, }],
  )
  assert_true(
    try {
      ignore(@validation.plan_collection(linked_pair(), wrong))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(
        @validation.ConversionOptions::for_patients(
          policy=@policy.strict(),
          uid_seed="123456789",
          patients=[
            { patient_id: "A", issuer: "", days: 7, },
            { patient_id: "A", issuer: "", days: 8, },
          ],
        ),
      )
      false
    } catch {
      _ => true
    },
  )
}

///|
test "caller required fields and deeply nested constructed models are bounded" {
  let missing = @quality.check(linked_pair(), required_fields=[
    @dicom.Tag::new(0x0099U, 0x0001U),
  ])
  assert_true(!missing.ready())
  assert_true(missing.public_json().stringify().contains("QUALITY-REQUIRED"))
  let mut dataset = @dicom.DataSet::empty()
  for _ in 0..<34 {
    dataset = @dicom.DataSet::new([
      @dicom.DataElement::new(
        @dicom.Tag::new(0x0008U, 0x1140U),
        @dicom.Vr::SQ,
        0U,
        @dicom.ElementValue::Sequence([dataset]),
        0,
      ),
    ])
  }
  assert_eq(
    @quality.check_datasets([dataset]).object_state,
    @quality.CheckState::NotChecked,
  )
}

///|
test "unsupported input state and series consistency are independently observable" {
  let inputs = linked_pair()
  let file = @dicom.parse(inputs[0])
  let unsupported = {
    ..file,
    transfer_syntax: "1.2.840.10008.1.2.2",
    file_meta: file.file_meta.replace_text(
      @dicom.Tag::new(0x0002U, 0x0010U),
      "1.2.840.10008.1.2.2",
    ),
  }
  let report = @quality.check([@dicom.write(unsupported)])
  assert_eq(report.object_state, @quality.CheckState::Unsupported)
  assert_eq(report.collection_state, @quality.CheckState::NotChecked)
  let second = @dicom.parse(inputs[1]).dataset
  let changed = @dicom.DataSet::new(
    second.elements.map(element => {
      if element.tag == @dicom.Tag::new(0x0028U, 0x0010U) {
        @dicom.DataElement::new(
          element.tag,
          element.vr,
          2U,
          @dicom.ElementValue::UnsignedShort([3U]),
          element.original_order,
        )
      } else {
        element
      }
    }),
  )
  let series_report = @quality.check_datasets([file.dataset, changed])
  assert_true(
    series_report.issues.any(item => {
      item.code == "QUALITY-SERIES" &&
      item.severity == @quality.Severity::Advisory
    }),
  )
}
