///|
test "de-identifying write clears preamble and source File Meta" {
  let original = @parser.parse(@fs.read_file_to_bytes("samples/input.dcm"))
  let source : @parser.ParsedFile = {
    ..original,
    preamble: Bytes::make(128, b'S'),
    file_meta: @model.DataSet::new(
      original.file_meta.elements +
      [
        @model.DataElement::new(
          @model.Tag::new(0x0002U, 0x0016U),
          @model.Vr::AE,
          0U,
          @model.ElementValue::Text("SECRET-SOURCE"),
          0,
        ),
      ],
    ),
  }
  let result = @deid.anonymize(source.dataset)
  let bytes = @dicom_writer.write_deidentified(source, result.dataset)
  let clean = @parser.parse(bytes)
  assert_eq(clean.preamble, Bytes::make(128, b'\x00'))
  assert_true(clean.file_meta.find(@model.Tag::new(0x0002U, 0x0016U)) is None)
  assert_true(
    clean.file_meta.find(@model.Tag::new(0x0002U, 0x0001U)) is Some(_),
  )
}

///|
test "writer rejects stale cached text bytes and short VR overflow" {
  let original = @parser.parse(@fs.read_file_to_bytes("samples/input.dcm"))
  let stale = @model.DataElement::new(
    @model.Tag::new(0x0010U, 0x0020U),
    @model.Vr::LO,
    0U,
    @model.ElementValue::Text("CLEAN"),
    0,
    original_bytes=Some(b"SECRET"),
  )
  let rejected = try {
    ignore(
      @dicom_writer.write_bytes(original, dataset=@model.DataSet::new([stale])),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  let large = @model.DataElement::new(
    @model.Tag::new(0x0010U, 0x0020U),
    @model.Vr::LO,
    0U,
    @model.ElementValue::Text(String::from_array(Array::make(65535, 'A'))),
    0,
  )
  let rejected = try {
    ignore(
      @dicom_writer.write_bytes(original, dataset=@model.DataSet::new([large])),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "public audit excludes source names even when the path contains identifiers" {
  let parsed = @parser.parse(@fs.read_file_to_bytes("samples/input.dcm"))
  let result = @deid.anonymize(parsed.dataset)
  let report = @deid.audit_json(
    result,
    "/SECRET-NAME/SECRET-ID.dcm",
    "/SECRET-OUTPUT/file.dcm",
    parsed.transfer_syntax,
    parsed.element_count,
  )
  assert_false(report.contains("SECRET"))
}

///|
test "unchanged text bytes retain leading spaces and padding" {
  let original = @parser.parse(@fs.read_file_to_bytes("samples/input.dcm"))
  let tag = @model.Tag::new(0x0008U, 0x1030U)
  let dataset = @model.DataSet::new([
    @model.DataElement::new(
      tag,
      @model.Vr::LO,
      0U,
      @model.ElementValue::Text(" LEADING  "),
      0,
    ),
  ])
  let first = @dicom_writer.write_bytes(original, dataset~)
  let parsed = @parser.parse(first)
  assert_eq(@dicom_writer.write_bytes(parsed), first)
  match parsed.dataset.elements[0].value {
    @model.ElementValue::Text(value) => assert_eq(value, " LEADING")
    _ => fail("text expected")
  }
}

///|
test "unsupported character sets are explicitly rejected" {
  let original = @parser.parse(@fs.read_file_to_bytes("samples/input.dcm"))
  let dataset = @model.DataSet::new([
    @model.DataElement::new(
      @model.Tag::new(0x0008U, 0x0005U),
      @model.Vr::CS,
      0U,
      @model.ElementValue::Text("ISO_IR 100"),
      0,
    ),
  ])
  let rejected = try {
    ignore(@parser.parse(@dicom_writer.write_bytes(original, dataset~)))
    false
  } catch {
    @model.MedSealError::UnsupportedCharacterSet => true
    _ => false
  }
  assert_true(rejected)
}
