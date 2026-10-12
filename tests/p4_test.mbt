///|
test "P4 terminal pixel index has bounded metadata and rejects trailing data" {
  let parsed = @parser.parse(
    object_bytes("A", "1.2.3", "1.2.10", "1.2.20", "20240228"),
  )
  let bytes = @dicom_writer.write_deidentified(parsed, parsed.dataset)
  let indexed = @parser.index_pixel_prefix(bytes, bytes.length().to_int64())
  assert_eq(indexed.length, 4)
  assert_eq(indexed.offset + indexed.length, bytes.length())
  assert_true(
    indexed.parsed.dataset.find(@model.Tag::new(0x7FE0U, 0x0010U)) is None,
  )
  let writer = @byteio.ByteWriter::new()
  writer.write_bytes(bytes)
  writer.write_bytes(b"\xFC\xFF\xFC\xFFOB\x00\x00\x00\x00\x00\x00")
  let trailing = writer.to_bytes()
  for
    (prefix, size) in [
      (trailing, trailing.length().to_int64()),
      (bytes, bytes.length().to_int64() - 1L),
      (bytes[0:indexed.offset - 1].to_owned(), bytes.length().to_int64()),
    ] {
    let rejected = try {
      ignore(@parser.index_pixel_prefix(prefix, size))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
