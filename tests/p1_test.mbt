///|
fn strict_dataset() -> @model.DataSet raise {
  let dataset = @parser.parse(
      object_bytes("A", "1.2.3", "1.2.10", "1.2.20", "20240228"),
    ).dataset
  let elements = dataset.elements.copy()
  for
    (tag, vr, value) in [
      ("00080060", @model.Vr::CS, "OT"),
      ("00080064", @model.Vr::CS, "WSD"),
      ("00080030", @model.Vr::TM, ""),
      ("00080050", @model.Vr::SH, ""),
      ("00080070", @model.Vr::LO, ""),
      ("00200010", @model.Vr::SH, ""),
      ("00200011", @model.Vr::IS, "1"),
      ("00200013", @model.Vr::IS, "1"),
      ("00200020", @model.Vr::CS, ""),
      ("00200060", @model.Vr::CS, ""),
      ("00280004", @model.Vr::CS, "MONOCHROME2"),
    ] {
    elements.push(
      @model.DataElement::new(
        @policy.parse_tag(tag),
        vr,
        0U,
        if value.is_empty() {
          @model.ElementValue::Empty
        } else {
          @model.ElementValue::Text(value)
        },
        0,
      ),
    )
  }
  elements.push(
    @model.DataElement::new(
      @model.Tag::new(0x0028U, 0x0102U),
      @model.Vr::US,
      2U,
      @model.ElementValue::UnsignedShort([7U]),
      0,
    ),
  )
  @model.DataSet::new(elements)
}

///|
test "P1 strict rejects unknown fields and validates required fields and VM" {
  let dataset = strict_dataset()
  @conformance.check(dataset, full_pixels=true)
  for
    changed in [
      @model.DataSet::new(
        dataset.elements +
        [
          @model.DataElement::new(
            @model.Tag::new(0x7776U, 0x0100U),
            @model.Vr::LO,
            0U,
            @model.ElementValue::Text("SENSITIVE"),
            0,
          ),
        ],
      ),
      dataset.remove(@model.Tag::new(0x0008U, 0x0030U)),
      dataset.replace_text(@model.Tag::new(0x0008U, 0x0018U), "1.2.3\\1.2.4"),
    ] {
    let rejected = try {
      @conformance.check(changed, full_pixels=true)
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "P1 rules are order independent and hard constraints cannot be overridden" {
  let a : @policy.PathRule = {
    id: "base",
    path: "dataset/00081030",
    action: @policy.Action::Empty,
    priority: 1,
    sop: None,
    present: None,
  }
  let b : @policy.PathRule = {
    id: "specific",
    path: "dataset/00081030",
    action: @policy.Action::Replace("APPROVED"),
    priority: 2,
    sop: Some("1.2.840.10008.5.1.4.1.1.7"),
    present: Some(@model.Tag::new(0x0028U, 0x0010U)),
  }
  let policy = @policy.strict(path_rules=[a, b])
  let reversed = @policy.strict(path_rules=[b, a])
  assert_eq(policy.digest(), reversed.digest())
  let dataset = strict_dataset()
  let context = @identity.Context::new("12345", policy, [14])
  context.prepare([dataset])
  let transformed = context.apply(dataset)
  assert_eq(
    @identity.text(transformed.dataset, @model.Tag::new(0x0008U, 0x1030U)),
    Some("APPROVED"),
  )
  assert_true(transformed.events.any(fn(e) { e.rule == "specific" }))
  assert_eq(
    @identity.text(transformed.dataset, @model.Tag::new(0x0010U, 0x0040U)),
    Some(""),
  )
  for
    invalid in [
      { ..a, path: "dataset/00100020", },
      { ..a, action: @policy.Action::Keep, },
      { ..a, path: "dataset/0008103e", },
    ] {
    let rejected = try {
      ignore(@policy.strict(path_rules=[invalid]))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let collision = try {
    ignore(@policy.strict(path_rules=[a, { ..b, priority: 1, }]))
    false
  } catch {
    _ => true
  }
  assert_true(collision)
}

///|
test "P1 duplicate escaped JSON keys and unknown strict schema fields are rejected" {
  for
    text in [
      "{\"version\":2,\"mode\":\"strict\",\"namespace\":\"lab\",\"date_shift_days\":30,\"version\":1}",
      "{\"version\":2,\"mode\":\"strict\",\"namespace\":\"lab\",\"date_shift_days\":30,\"\\u0076ersion\":2}",
      "{\"version\":2,\"mode\":\"strict\",\"namespace\":\"lab\",\"date_shift_days\":30,\"allow_external_references\":true}",
    ] {
    let rejected = try {
      ignore(@policy.from_json(text))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  assert_true(
    @policy.from_json(
      "{\"version\":2,\"mode\":\"strict\",\"namespace\":\"lab\",\"date_shift_days\":30}",
    ).strict_metadata,
  )
}

///|
async test "P1 strict collection output is canonical and independently verifiable" {
  let root = @async_fs.tmpdir(prefix="medseal-strict")
  defer @async_fs.rmdir(root, recursive=true)
  let input = "\{root}/input"
  @storage.mkdir(input)
  let source = @parser.parse(
    object_bytes("A", "1.2.3", "1.2.10", "1.2.20", "20240228"),
  )
  @storage.write_new(
    "\{input}/instance",
    @dicom_writer.write_bytes(source, dataset=strict_dataset()),
  )
  let manifest = @batch.run(input, "\{root}/output", @policy.strict())
  assert_true(manifest.contains("strict-v1"))
  ignore(@batch.verify("\{root}/output"))
  let output = @parser.parse(@storage.read("\{root}/output/object-1.dcm"))
  assert_eq(
    output.dataset.elements.map(fn(e) { e.tag }),
    output.dataset.canonical().elements.map(fn(e) { e.tag }),
  )
}
