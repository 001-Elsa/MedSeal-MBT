///|
/// Private format exchange example for JS hosts. The host handles I/O.
/// Success contains original metadata/pixels: never use as a public report.
pub fn exchange(mode : String, input : String) -> String {
  try {
    let output = match mode {
      "canonical" => @dicom_json.encode(@dicom_json.decode(input))
      "to_part10" => @hex.encode(@dicom_json.to_part10(input))
      "from_part10" =>
        @dicom_json.encode(@dicom.parse(@hex.decode(input)).dataset)
      _ => return "{\"ok\":false}"
    }
    Json::object(
      Map::from_array([
        ("ok", Json::boolean(true)),
        ("value", Json::string(output)),
      ]),
    ).stringify()
  } catch {
    // Fixed refusal, no original metadata in diagnostics.
    _ => "{\"ok\":false}"
  }
}
