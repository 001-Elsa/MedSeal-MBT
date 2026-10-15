///|
/// End-to-end consumer using public imports only, on all four backends.
fn main {
  try {
    // Simulate metadata supplied by another DICOM JSON implementation.
    // The format bridge preserves private values; strict conversion is separate.
    let inputs = linked_pair().map(bytes => {
      @dicom_json.to_part10(@dicom_json.encode(@dicom.parse(bytes).dataset))
    })
    let result = @validation.convert_collection(
      inputs,
      @policy.strict(),
      "987654321",
      [7],
    )
    if result.length() != 2 {
      abort("unexpected SDK result count")
    }
    for index in 0..<result.length() {
      let bytes = result.private_bytes(index)
      ignore(@validation.validate(bytes))
      let file = @dicom.parse(bytes)
      match file.dataset.find(@dicom.Tag::new(0x7FE0U, 0x0010U)) {
        Some(element) if element.value ==
          @dicom.ElementValue::Raw(b"\x01\x02\x03\x04") => ()
        _ => abort("pixel preservation failed")
      }
      // Deliberately private synthetic payload for the independent verifier.
      // Never use this output mode for actual patient files.
      println("synthetic-output-\{index}:\{@hex.encode(bytes)}")
    }
    println(result.public_report().stringify())
    println("public-collection-ok")
  } catch {
    _ => abort("public collection workflow failed")
  }
}
