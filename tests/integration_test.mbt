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

///|
fn text_at(dataset : @model.DataSet, tag : @model.Tag) -> String? {
  match dataset.find(tag) {
    Some(element) =>
      match element.value {
        @model.ElementValue::Text(value) => Some(value)
        @model.ElementValue::Empty => Some("")
        _ => None
      }
    None => None
  }
}

///|
test "invalid sample errors keep their promised structured categories" {
  let truncated = try {
    ignore(
      @parser.parse(
        @fs.read_file_to_bytes("samples/invalid/truncated-element.dcm"),
      ),
    )
    false
  } catch {
    @model.MedSealError::InvalidLength(tag, _, _) =>
      tag == @model.Tag::new(0x0010U, 0x0010U)
    _ => false
  }
  let invalid_vr = try {
    ignore(
      @parser.parse(@fs.read_file_to_bytes("samples/invalid/invalid-vr.dcm")),
    )
    false
  } catch {
    @model.MedSealError::InvalidVr("ZZ", _) => true
    _ => false
  }
  let invalid_sequence = try {
    ignore(
      @parser.parse(
        @fs.read_file_to_bytes("samples/invalid/invalid-sequence.dcm"),
      ),
    )
    false
  } catch {
    @model.MedSealError::InvalidSequence(_) => true
    _ => false
  }
  assert_true(truncated)
  assert_true(invalid_vr)
  assert_true(invalid_sequence)
}

///|
test "patient sample applies every configured action it contains" {
  let parsed = @parser.parse(
    @fs.read_file_to_bytes("samples/valid/patient-fields.dcm"),
  )
  let result = @deid.anonymize(parsed.dataset)
  assert_eq(
    text_at(result.dataset, @model.Tag::new(0x0010U, 0x0010U)),
    Some("ANONYMOUS"),
  )
  assert_eq(
    text_at(result.dataset, @model.Tag::new(0x0010U, 0x0020U)),
    Some("MEDSEAL-ID"),
  )
  for
    tag in [
      @model.Tag::new(0x0010U, 0x0030U),
      @model.Tag::new(0x0008U, 0x0080U),
      @model.Tag::new(0x0008U, 0x0090U),
    ] {
    assert_eq(text_at(result.dataset, tag), Some(""))
  }
  assert_eq(
    text_at(result.dataset, @model.Tag::new(0x0010U, 0x0040U)),
    Some("O"),
  )
  assert_true(
    result.warnings.any(fn(warning) { warning.code == "MEDSEAL-W103" }),
  )
  assert_true(
    result.warnings.any(fn(warning) { warning.code == "MEDSEAL-W104" }),
  )
  assert_true(
    result.warnings.any(fn(warning) { warning.code == "MEDSEAL-W105" }),
  )
  assert_true(
    result.warnings.any(fn(warning) { warning.code == "MEDSEAL-W106" }),
  )
}

///|
test "nested sample removes identifiers recursively" {
  let parsed = @parser.parse(
    @fs.read_file_to_bytes("samples/valid/nested-sequence.dcm"),
  )
  let result = @deid.anonymize(parsed.dataset)
  let sequences = result.dataset.elements.filter(fn(element) {
    element.vr == @model.Vr::SQ
  })
  match sequences.get(0) {
    Some(element) =>
      match element.value {
        @model.ElementValue::Sequence(items) => {
          assert_eq(items.length(), 1)
          assert_eq(
            text_at(items[0], @model.Tag::new(0x0010U, 0x0010U)),
            Some("ANONYMOUS"),
          )
          assert_eq(
            text_at(items[0], @model.Tag::new(0x0010U, 0x0020U)),
            Some("MEDSEAL-ID"),
          )
        }
        _ => fail("expected nested sequence")
      }
    None => fail("sequence missing")
  }
}

///|
test "private-tag switch changes only private elements" {
  let parsed = @parser.parse(
    @fs.read_file_to_bytes("samples/valid/private-tags.dcm"),
  )
  let keep = @deid.anonymize(parsed.dataset)
  let remove = @deid.anonymize(parsed.dataset, remove_private=true)
  assert_eq(@validator.private_element_count(keep.dataset), 1)
  assert_eq(@validator.private_element_count(remove.dataset), 0)
  assert_eq(remove.private_elements_removed, 1)
  assert_eq(remove.elements_removed, 1)
  assert_eq(
    keep.dataset.count_recursive() - remove.dataset.count_recursive(),
    1,
  )
}

///|
test "audit JSON has required safety declarations and no fixture values" {
  let parsed = @parser.parse(
    @fs.read_file_to_bytes("samples/valid/patient-fields.dcm"),
  )
  let result = @deid.anonymize(parsed.dataset, remove_private=true)
  let audit = @deid.audit_json(
    result,
    "input.dcm",
    "output.dcm",
    parsed.transfer_syntax,
    parsed.element_count,
  )
  assert_true(audit.contains("\"pixel_data_modified\": false"))
  assert_true(audit.contains("\"uid_values_modified\": false"))
  assert_true(audit.contains("MEDSEAL-W105"))
  assert_true(audit.contains("MEDSEAL-W106"))
  assert_false(audit.contains("TEST^PATIENT"))
  assert_false(audit.contains("SYNTHETIC-001"))
  assert_false(audit.contains("SYNTHETIC HOSPITAL"))
  assert_false(audit.contains("TEST^DOCTOR"))
}

///|
fn same_structure(left : @model.DataSet, right : @model.DataSet) -> Bool {
  if left.elements.length() != right.elements.length() {
    return false
  }
  for index = 0; index < left.elements.length(); index = index + 1 {
    let a = left.elements[index]
    let b = right.elements[index]
    if a.tag != b.tag || a.vr != b.vr {
      return false
    }
    match (a.value, b.value) {
      (
        @model.ElementValue::Sequence(a_items),
        @model.ElementValue::Sequence(b_items),
      ) => {
        if a_items.length() != b_items.length() {
          return false
        }
        for item = 0; item < a_items.length(); item = item + 1 {
          if !same_structure(a_items[item], b_items[item]) {
            return false
          }
        }
      }
      (@model.ElementValue::Sequence(_), _)
      | (_, @model.ElementValue::Sequence(_)) => return false
      _ => ()
    }
  }
  true
}

///|
test "every valid sample survives parse-write-parse structurally" {
  for
    name in [
      "minimal-valid.dcm", "patient-fields.dcm", "private-tags.dcm", "nested-sequence.dcm",
      "pixel-data.dcm",
    ] {
    let first = @parser.parse(@fs.read_file_to_bytes("samples/valid/\{name}"))
    let second = @parser.parse(@dicom_writer.write_bytes(first))
    assert_true(same_structure(first.dataset, second.dataset))
    assert_eq(first.dataset.count_recursive(), second.dataset.count_recursive())
    assert_eq(find_pixel(first.dataset), find_pixel(second.dataset))
  }
}

///|
test "committed demo output is valid and contains only replacement values" {
  let parsed = @parser.parse(@fs.read_file_to_bytes("samples/output.dcm"))
  assert_true(@validator.validate(parsed).is_valid())
  assert_eq(
    text_at(parsed.dataset, @model.Tag::new(0x0010U, 0x0010U)),
    Some("ANONYMOUS"),
  )
  assert_eq(
    text_at(parsed.dataset, @model.Tag::new(0x0010U, 0x0020U)),
    Some("MEDSEAL-ID"),
  )
  assert_eq(@validator.private_element_count(parsed.dataset), 0)
}
