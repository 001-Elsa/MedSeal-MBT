///|
fn object_bytes(
  patient : String,
  sop : String,
  study : String,
  serie : String,
  date : String,
  reference? : String? = None,
) -> Bytes raise {
  let source = @parser.parse(
    @fs.read_file_to_bytes("samples/valid/pixel-data.dcm"),
  )
  let dataset = source.dataset
    .replace_text(@model.Tag::new(0x0010U, 0x0020U), patient)
    .replace_text(@model.Tag::new(0x0008U, 0x0018U), sop)
    .replace_text(@model.Tag::new(0x0020U, 0x000DU), study)
    .replace_text(@model.Tag::new(0x0020U, 0x000EU), serie)
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
  match reference {
    Some(uid) => {
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
          @model.ElementValue::Text(uid),
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
    None => ()
  }
  let parsed : @parser.ParsedFile = {
    ..source,
    dataset: @model.DataSet::new(elements),
    file_meta: source.file_meta.replace_text(
      @model.Tag::new(0x0002U, 0x0003U),
      sop,
    ),
  }
  @dicom_writer.write_bytes(parsed)
}

///|
test "shared context preserves patient groups and references regardless of ordering" {
  let a = @parser.parse(
      object_bytes(
        "PATIENT-A",
        "1.2.3",
        "1.2.10",
        "1.2.20",
        "20240228",
        reference=Some("1.2.4"),
      ),
    ).dataset
  let b = @parser.parse(
      object_bytes("PATIENT-A", "1.2.4", "1.2.10", "1.2.21", "20240313"),
    ).dataset
  let c = @parser.parse(
      object_bytes("PATIENT-B", "1.2.5", "1.2.11", "1.2.22", "20240228"),
    ).dataset
  let policy = @policy.research()
  let context = @identity.Context::new("12345", policy, [14, 7])
  context.prepare([a, b, c])
  let reversed = @identity.Context::new("12345", policy, [14, 7])
  reversed.prepare([c, b, a])
  assert_eq(context.mapped_uid("1.2.3"), reversed.mapped_uid("1.2.3"))
  assert_eq(context.patient(a), context.patient(b))
  assert_false(context.patient(a) == context.patient(c))
  let outputs = [
    context.apply(a).dataset,
    context.apply(b).dataset,
    context.apply(c).dataset,
  ]
  assert_eq(@verification.check(outputs).references, 1)
  assert_eq(
    @identity.text(outputs[0], @model.Tag::new(0x0008U, 0x0020U)),
    Some("20240313"),
  )
  assert_eq(
    @identity.text(outputs[1], @model.Tag::new(0x0008U, 0x0020U)),
    Some("20240327"),
  )
  assert_eq(
    @identity.text(outputs[2], @model.Tag::new(0x0008U, 0x0020U)),
    Some("20240306"),
  )
  let repeat = try {
    ignore(context.apply(outputs[0]))
    false
  } catch {
    _ => true
  }
  assert_true(repeat)
}

///|
test "closed graph rejects missing, cross patient and duplicate object references" {
  let a = @parser.parse(
      object_bytes(
        "A",
        "1.2.3",
        "1.2.10",
        "1.2.20",
        "20240228",
        reference=Some("1.2.4"),
      ),
    ).dataset
  let b = @parser.parse(
      object_bytes("B", "1.2.4", "1.2.11", "1.2.21", "20240313"),
    ).dataset
  let missing = try {
    ignore(@verification.check([a]))
    false
  } catch {
    _ => true
  }
  let cross_patient = try {
    ignore(@verification.check([a, b]))
    false
  } catch {
    _ => true
  }
  let duplicate = try {
    ignore(@verification.check([b, b]))
    false
  } catch {
    _ => true
  }
  assert_true(missing && cross_patient && duplicate)
  assert_eq(
    @verification.check([a], allow_external=true).external_references,
    1,
  )
}

///|
test "conflicting patient identities and unclassified UID roles are rejected" {
  let a = @parser.parse(
      object_bytes("A", "1.2.3", "1.2.10", "1.2.20", "20240228"),
    ).dataset
  let conflict = a.replace_text(
    @model.Tag::new(0x0010U, 0x0010U),
    "DIFFERENT^NAME",
  )
  let context = @identity.Context::new("12345", @policy.research(), [14])
  let rejected = try {
    context.prepare([a, conflict])
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  let fresh = @identity.Context::new("12345", @policy.research(), [14])
  let unknown = @model.DataSet::new(
    a.elements +
    [
      @model.DataElement::new(
        @model.Tag::new(0x0008U, 0x3010U),
        @model.Vr::UI,
        0U,
        @model.ElementValue::Text("1.2.30"),
        0,
      ),
    ],
  )
  let rejected = try {
    fresh.prepare([unknown])
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "processed marker prevents a second shift even when original patient ID is already P1" {
  let source = @parser.parse(
      object_bytes("P1", "1.2.3", "1.2.10", "1.2.20", "20240228"),
    ).dataset
  let context = @identity.Context::new("12345", @policy.research(), [14])
  context.prepare([source])
  let processed = context.apply(source).dataset
  let rejected = try {
    ignore(context.apply(processed))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
