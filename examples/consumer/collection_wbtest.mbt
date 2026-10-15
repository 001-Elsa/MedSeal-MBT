///|
fn rejection(inputs : Array[Bytes]) -> String {
  try {
    ignore(
      @validation.convert_collection(inputs, @policy.strict(), "987654321", [7]),
    )
    "accepted"
  } catch {
    error => error.code()
  }
}

///|
test "public SDK preserves source, output order and linked relationships" {
  let input = linked_pair()
  let snapshot = @dicom.parse(input[0]).dataset
  let result = @validation.convert_collection(
    input,
    @policy.strict(),
    "987654321",
    [7],
  )
  assert_eq(result.length(), 2)
  assert_eq(@dicom.parse(input[0]).dataset, snapshot)
  let first = @dicom.parse(result.private_bytes(0)).dataset
  let second = @dicom.parse(result.private_bytes(1)).dataset
  let tag = @dicom.Tag::new(0x0008U, 0x0018U)
  let mapped = first.find(tag).unwrap().value
  assert_true(mapped != snapshot.find(tag).unwrap().value)
  match second.find(@dicom.Tag::new(0x0008U, 0x1140U)).unwrap().value {
    @dicom.ElementValue::Sequence([item]) =>
      assert_eq(
        item.find(@dicom.Tag::new(0x0008U, 0x1155U)).unwrap().value,
        mapped,
      )
    _ => fail("expected preserved reference sequence")
  }
  assert_eq(
    first.find(@dicom.Tag::new(0x0008U, 0x0020U)).unwrap().value,
    @dicom.ElementValue::Text("20240307"),
  )
  let report = result.public_report().stringify()
  for canary in ["SDKCANARY", "987654321", "20240229", "1.2.826.0.1.999"] {
    assert_true(!report.contains(canary))
  }
  assert_true(report.contains("collection-converted"))
  assert_true(report.contains("release_authorized"))
}

///|
test "public SDK rejects duplicate and unresolved SOPs before returning outputs" {
  let pair = linked_pair()
  assert_eq(rejection([pair[0], pair[0]]), "MEDSEAL-E520")
  assert_eq(rejection([pair[1]]), "MEDSEAL-E520")
}

///|
test "public SDK rejects conflicting identities in one closed collection" {
  assert_eq(
    rejection([
      object("1.2.826.0.1.999.1"),
      object("1.2.826.0.1.999.2", name="DIFFERENT^PERSON"),
    ]),
    "MEDSEAL-E520",
  )
}

///|
test "public SDK rejects invalid tail instead of returning partial results" {
  let pair = linked_pair()
  assert_eq(rejection([pair[0], b"invalid"]), "MEDSEAL-E101")
}

///|
test "public SDK enforces empty, count, per-object and aggregate budgets" {
  assert_eq(rejection([]), "MEDSEAL-E501")
  assert_eq(rejection(Array::make(257, b"")), "MEDSEAL-E501")
  // Shared immutable buffers test byte accounting without allocating 128 MiB.
  let chunk = Bytes::make(1024 * 1024, b'\x00')
  assert_eq(rejection(Array::make(129, chunk)), "MEDSEAL-E501")
  assert_eq(
    rejection([Bytes::make(64 * 1024 * 1024 + 1, b'\x00')]),
    "MEDSEAL-E501",
  )
}

///|
test "public SDK requires strict policy and valid explicit identity settings" {
  let inputs = linked_pair()
  let relaxed = @policy.from_json(
    "{\"version\":1,\"mode\":\"research\",\"namespace\":\"example\",\"date_shift_days\":30}",
  )
  let policy_code = try {
    ignore(@validation.convert_collection(inputs, relaxed, "987654321", [7]))
    "accepted"
  } catch {
    error => error.code()
  }
  assert_eq(policy_code, "MEDSEAL-E510")
  for
    (seed, offsets) in [
      ("0", [7]),
      ("987654321", [0]),
      ("987654321", []),
      ("987654321", [31]),
    ] {
    let code = try {
      ignore(
        @validation.convert_collection(inputs, @policy.strict(), seed, offsets),
      )
      "accepted"
    } catch {
      error => error.code()
    }
    assert_eq(code, "MEDSEAL-E520")
  }
}

///|
test "public SDK result accessor rejects invalid indexes with typed errors" {
  let result = @validation.convert_collection(
    linked_pair(),
    @policy.strict(),
    "987654321",
    [7],
  )
  for index in [-1, 2] {
    let code = try {
      ignore(result.private_bytes(index))
      "accepted"
    } catch {
      error => error.code()
    }
    assert_eq(code, "MEDSEAL-E501")
  }
}
