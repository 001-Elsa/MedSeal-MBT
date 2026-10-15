///|
fn canonical(text : String) -> String raise @dicom.MedSealError {
  @dicom_json.encode(@dicom_json.decode(text))
}

///|
fn rejects(text : String) -> Bool {
  try {
    ignore(@dicom_json.decode(text))
    false
  } catch {
    _ => true
  }
}

///|
test "DICOM JSON orders attributes and preserves null text values and single-valued backslashes" {
  let text = "{\"00100020\":{\"vr\":\"LO\",\"Value\":[\"A\",null,\"B\",null]},\"00081030\":{\"vr\":\"LO\"},\"0040A160\":{\"vr\":\"UT\",\"Value\":[\"a\\\\b\"]}}"
  let output = canonical(text)
  assert_true(output.has_prefix("{\"00081030\":"))
  assert_true(output.contains("[\"A\",null,\"B\",null]"))
  assert_eq(canonical(output), output)
  assert_eq(
    @dicom_json.decode(output).find(@dicom.Tag::new(0x0040U, 0xA160U)).unwrap().value,
    @dicom.ElementValue::Text("a\\b"),
  )
}

///|
test "DICOM JSON PN representation groups, missing alphabetic and empty item" {
  let text = "{\"00100010\":{\"vr\":\"PN\",\"Value\":[{\"Alphabetic\":\"TEST^NAME\",\"Ideographic\":\"韩^桢\",\"Phonetic\":\"HAN^ZHEN\"},null,{\"Phonetic\":\"HAN\"}]}}"
  let dataset = @dicom_json.decode(text)
  assert_eq(
    dataset.elements[0].value,
    @dicom.ElementValue::Text("TEST^NAME=韩^桢=HAN^ZHEN\\\\==HAN"),
  )
  assert_eq(canonical(canonical(text)), canonical(text))
  assert_true(
    rejects(
      "{\"00100010\":{\"vr\":\"PN\",\"Value\":[{\"Alphabetic\":\"A=B\"}]}}",
    ),
  )
}

///|
test "DICOM JSON exact decimal and IS representation survives without Double rewriting" {
  for value in ["0.12345678901234", "+1.2300E-02", "9007199254740993"] {
    let text = "{\"00281053\":{\"vr\":\"DS\",\"Value\":[\"\{value}\"]}}"
    assert_true(canonical(text).contains("\"\{value}\""))
  }
  for exact in ["9007199254740993", "1.2300", "1e-003", "-0"] {
    assert_true(
      canonical("{\"00281053\":{\"vr\":\"DS\",\"Value\":[\{exact}]}}").contains(
        "\"\{exact}\"",
      ),
    )
  }
  assert_true(
    rejects(
      "{\"00281053\":{\"vr\":\"DS\",\"Value\":[{\"__medseal_exact_number__\":\"123\"}]}}",
    ),
  )
  assert_true(
    rejects(
      "{\"00281053\":{\"vr\":\"DS\",\"Value\":[{\"__medseal_exact_\\u006eumber__\":\"123\"}]}}",
    ),
  )
  let numeric = canonical(
    "{\"00281053\":{\"vr\":\"DS\",\"Value\":[0.12345678901234]}}",
  )
  assert_true(numeric.contains("\"0.12345678901234\""))
  assert_true(
    canonical(
      "{\"00200013\":{\"vr\":\"IS\",\"Value\":[\"+00001\",-2147483648,2147483647]}}",
    ).contains("+00001"),
  )
  for bad in ["NaN", "1e999", "1.2.3", "--1", "12345678901234567"] {
    assert_true(
      rejects("{\"00281053\":{\"vr\":\"DS\",\"Value\":[\"\{bad}\"]}}"),
    )
  }
}

///|
test "DICOM JSON integer signed and unsigned boundaries are exact" {
  for
    (vr, values) in [
      ("US", "[0,65535]"),
      ("SS", "[-32768,32767]"),
      ("UL", "[0,4294967295]"),
      ("SL", "[-2147483648,2147483647]"),
    ] {
    let text = "{\"00280010\":{\"vr\":\"\{vr}\",\"Value\":\{values}}}"
    assert_eq(canonical(text), text)
  }
  for
    (vr, value) in [
      ("US", "-1"),
      ("US", "65536"),
      ("SS", "32768"),
      ("UL", "4294967296"),
      ("SL", "-2147483649"),
      ("UL", "4294967295.0000001"),
      ("US", "1e0"),
      ("US", "1.0"),
      ("UL", "\"4294967295\""),
      ("US", "null"),
    ] {
    if !rejects("{\"00280010\":{\"vr\":\"\{vr}\",\"Value\":[\{value}]}}") {
      fail("unexpected acceptance: " + vr + " " + value)
    }
  }
}

///|
test "DICOM JSON sequence empty item and zero length attributes" {
  let text = "{\"00081140\":{\"vr\":\"SQ\",\"Value\":[{}, {\"00081155\":{\"vr\":\"UI\",\"Value\":[\"1.2.3\"]}}]},\"00100020\":{\"vr\":\"LO\"}}"
  assert_eq(canonical(canonical(text)), canonical(text))
  assert_eq(
    canonical("{\"00081140\":{\"vr\":\"SQ\"}}"),
    "{\"00081140\":{\"vr\":\"SQ\"}}",
  )
  // pydicom emits Value:[] for empty SQ; accept and normalize to omitted Value.
  assert_eq(
    canonical("{\"00081140\":{\"vr\":\"SQ\",\"Value\":[]}}"),
    "{\"00081140\":{\"vr\":\"SQ\"}}",
  )
  assert_true(rejects("{\"00081140\":{\"vr\":\"SQ\",\"Value\":[null]}}"))
}

///|
test "DICOM JSON InlineBinary preserves exact octets and refuses ambiguous forms" {
  for vr in ["OB", "OW", "UN"] {
    let text = "{\"7FE00010\":{\"vr\":\"\{vr}\",\"InlineBinary\":\"AAECAw==\"}}"
    assert_eq(canonical(text), text)
  }
  for data in ["AA==", "AAE", "AAE= ", "***=", "AB=="] {
    assert_true(
      rejects("{\"7FE00010\":{\"vr\":\"OB\",\"InlineBinary\":\"\{data}\"}}"),
    )
  }
  assert_true(rejects("{\"7FE00010\":{\"vr\":\"OB\",\"Value\":[1]}}"))
  assert_true(
    rejects("{\"00100020\":{\"vr\":\"LO\",\"InlineBinary\":\"AAE=\"}}"),
  )
}

///|
test "DICOM JSON rejects duplicates including escaped JSON names" {
  for
    text in [
      "{\"00100020\":{\"vr\":\"LO\",\"vr\":\"PN\"}}", "{\"00100020\":{\"vr\":\"LO\",\"v\\u0072\":\"PN\"}}",
      "{\"00100020\":{\"vr\":\"LO\"},\"00100020\":{\"vr\":\"LO\"}}",
    ] {
    assert_true(rejects(text))
  }
}

///|
test "DICOM JSON rejects malformed shape, unsupported VRs, file meta and remote bulk data" {
  for
    text in [
      "[]", "null", "{", "{\"00100020\":{}}", "{\"00100020\":{\"vr\":\"ZZ\"}}", "{\"00100020\":{\"vr\":\"LO\",\"Value\":[]}}",
      "{\"00100020\":{\"vr\":\"LO\",\"Value\":null}}", "{\"00100020\":{\"vr\":\"LO\",\"Value\":[\"A\\\\B\"]}}",
      "{\"0010002a\":{\"vr\":\"LO\"}}", "{\"00020010\":{\"vr\":\"UI\"}}", "{\"00100000\":{\"vr\":\"UL\"}}",
      "{\"FF FEE000\":{\"vr\":\"LO\"}}",
    ] {
    assert_true(rejects(text))
  }
  for vr in ["SV", "UV", "AT", "FD", "FL", "OD", "OF", "OL", "OV"] {
    assert_true(rejects("{\"00110010\":{\"vr\":\"\{vr}\"}}"))
  }
  assert_true(
    rejects(
      "{\"7FE00010\":{\"vr\":\"OB\",\"BulkDataURI\":\"https://example.invalid/private\"}}",
    ),
  )
  assert_true(
    rejects(
      "{\"7FE00010\":{\"vr\":\"OB\",\"Value\":[null],\"InlineBinary\":\"AAE=\"}}",
    ),
  )
}

///|
test "DICOM JSON Part10 construction requires SOP IDs and explicit charset" {
  assert_true(
    try {
      ignore(@dicom_json.to_part10("{}"))
      false
    } catch {
      _ => true
    },
  )
  let minimal = "{\"00080016\":{\"vr\":\"UI\",\"Value\":[\"1.2.840.10008.5.1.4.1.1.7\"]},\"00080018\":{\"vr\":\"UI\",\"Value\":[\"1.2.3\"]}}"
  let with_text = minimal[0:minimal.length() - 1].to_owned() +
    ",\"00100010\":{\"vr\":\"PN\",\"Value\":[{\"Alphabetic\":\"合成\"}]}}"
  assert_true(
    try {
      ignore(@dicom_json.to_part10(with_text))
      false
    } catch {
      @dicom.MedSealError::InvalidModel(reason) =>
        reason == "DICOM JSON: Part 10 structure or character set"
      _ => false
    },
  )
  let parsed = @dicom.parse(@dicom_json.to_part10(minimal))
  assert_eq(parsed.transfer_syntax, "1.2.840.10008.1.2.1")
  assert_eq(@dicom_json.encode(parsed.dataset), canonical(minimal))
}

///|
test "DICOM JSON enforces preparse depth, input, tree and binary budgets" {
  assert_true(rejects(String::make(8 * 1024 * 1024 + 1, 'x')))
  assert_true(rejects(String::make(65, '[')))
  let mut nested = "{}"
  for _ in 0..<17 {
    nested = "{\"00081140\":{\"vr\":\"SQ\",\"Value\":[\{nested}]}}"
  }
  assert_true(rejects(nested))
  let too_many = Array::make(20001, Json::null()).to_json().stringify()
  assert_true(rejects("{\"00100020\":{\"vr\":\"LO\",\"Value\":\{too_many}}}"))
  assert_true(
    rejects(
      "{\"7FE00010\":{\"vr\":\"OB\",\"InlineBinary\":\"\{String::make(1398108, 'A')}\"}}",
    ),
  )
}

///|
test "DICOM JSON encoder rejects invalid caller models without silently losing values" {
  fn bad(vr : @dicom.Vr, value : @dicom.ElementValue) -> Bool {
    let e = @dicom.DataElement::new(
      @dicom.Tag::new(0x0011U, 0x1010U),
      vr,
      0U,
      value,
      0,
    )
    try {
      ignore(@dicom_json.encode(@dicom.DataSet::new([e])))
      false
    } catch {
      _ => true
    }
  }
  assert_true(bad(@dicom.Vr::US, @dicom.ElementValue::Text("123")))
  assert_true(bad(@dicom.Vr::US, @dicom.ElementValue::UnsignedShort([65536U])))
  assert_true(bad(@dicom.Vr::SS, @dicom.ElementValue::SignedShort([-32769])))
  assert_true(bad(@dicom.Vr::FL, @dicom.ElementValue::Empty))
  assert_true(bad(@dicom.Vr::OB, @dicom.ElementValue::Raw(b"x")))
  assert_true(
    bad(
      @dicom.Vr::OB,
      @dicom.ElementValue::Raw(Bytes::make(1024 * 1024 + 2, b'\x00')),
    ),
  )
  assert_true(bad(@dicom.Vr::DS, @dicom.ElementValue::Text("1e999")))
  assert_true(bad(@dicom.Vr::PN, @dicom.ElementValue::Text("A=B=C=D")))
  assert_true(
    bad(
      @dicom.Vr::LO,
      @dicom.ElementValue::Text(String::make(1024 * 1024 + 1, 'x')),
    ),
  )
  let e = @dicom.DataElement::new(
    @dicom.Tag::new(0x0010U, 0x0020U),
    @dicom.Vr::LO,
    0U,
    @dicom.ElementValue::Empty,
    0,
  )
  assert_true(
    try {
      ignore(@dicom_json.encode(@dicom.DataSet::new([e, e])))
      false
    } catch {
      _ => true
    },
  )
  let mut deep = @dicom.DataSet::new([])
  for _ in 0..<17 {
    deep = @dicom.DataSet::new([
      @dicom.DataElement::new(
        @dicom.Tag::new(0x0008U, 0x1140U),
        @dicom.Vr::SQ,
        0U,
        @dicom.ElementValue::Sequence([deep]),
        0,
      ),
    ])
  }
  assert_true(
    try {
      ignore(@dicom_json.encode(deep))
      false
    } catch {
      _ => true
    },
  )
}
