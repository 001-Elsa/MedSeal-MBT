///|
fn find_pixel(dataset : @model.DataSet) -> Bytes? {
  match dataset.find(@model.pixel_data_tag) {
    Some(element) =>
      match element.value {
        @model.ElementValue::Raw(value) => Some(value)
        _ => None
      }
    None => None
  }
}

///|
test "anonymize write parse keeps pixel bytes and removes direct identifiers" {
  let parsed = @parser.parse(
    @fs.read_file_to_bytes("samples/valid/pixel-data.dcm"),
  )
  let original_pixel = find_pixel(parsed.dataset)
  let result = @deid.anonymize(parsed.dataset, remove_private=true)
  let reparsed = @parser.parse(
    @dicom_writer.write_bytes(parsed, dataset=result.dataset),
  )
  assert_eq(find_pixel(reparsed.dataset), original_pixel)
  match reparsed.dataset.find(@model.Tag::new(0x0010U, 0x0010U)) {
    Some(element) =>
      assert_true(element.value is @model.ElementValue::Text("ANONYMOUS"))
    None => fail("patient name missing")
  }
}
