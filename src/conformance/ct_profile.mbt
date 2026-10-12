///|
fn ct_tag(value : String) -> @model.Tag {
  let number = @string.parse_uint(value, base=16) catch { _ => 0U }
  @model.Tag::new(number >> 16, number & 65535U)
}

///|
/// Return the text representation without treating an empty Type 2 value as missing.
fn ct_text(dataset : @model.DataSet, value : String) -> String? {
  match dataset.find(ct_tag(value)) {
    Some({ value: @model.ElementValue::Text(text), .. }) => Some(text)
    Some({ value: @model.ElementValue::Empty, .. }) => Some("")
    _ => None
  }
}

///|
fn ct_present(
  dataset : @model.DataSet,
  value : String,
  nonempty : Bool,
) -> Bool {
  match dataset.find(ct_tag(value)) {
    None => false
    Some({ value: @model.ElementValue::Empty, .. }) => !nonempty
    Some({ value: @model.ElementValue::Text(text), .. }) =>
      !nonempty || !text.is_empty()
    Some(_) => true
  }
}

///|
fn ct_require(
  dataset : @model.DataSet,
  tags : Array[String],
  nonempty : Bool,
) -> Unit raise @model.MedSealError {
  for value in tags {
    if !ct_present(dataset, value, nonempty) {
      raise @model.MedSealError::RuleViolation(
        "ct-module-required",
        "dataset/" + value,
        "met",
        "ct-classic-research-v1",
      )
    }
  }
}

///|
fn ct_finite_decimal(value : String) -> Bool {
  try {
    let number = @string.parse_double(value.trim())
    !number.is_nan() && !number.is_inf()
  } catch {
    _ => false
  }
}

///|
/// Validate a finite decimal vector while preserving the source text.
fn ct_decimal_vector(
  dataset : @model.DataSet,
  value : String,
  count : Int,
) -> Unit raise @model.MedSealError {
  let text = match ct_text(dataset, value) {
    Some(text) if !text.is_empty() => text
    _ =>
      raise @model.MedSealError::RuleViolation(
        "ct-geometry-contract",
        "dataset/" + value,
        "met",
        "geometry",
      )
  }
  let components = text.split("\\").to_array()
  if components.length() != count ||
    components.any(fn(component) {
      component.is_empty() || !ct_finite_decimal(component.to_owned())
    }) {
    raise @model.MedSealError::RuleViolation(
      "ct-geometry-contract",
      "dataset/" + value,
      "met",
      "geometry",
    )
  }
}

///|
/// A deliberately narrow classic CT profile for research arrays and HU statistics.
/// The independent series verifier owns ordering, physical coordinates and decoded pixels.
pub fn check_classic_ct(
  dataset : @model.DataSet,
  full_pixels? : Bool = true,
) -> Unit raise @model.MedSealError {
  check(dataset, full_pixels~)
  let sop = match ct_text(dataset, "00080016") {
    Some(value) => value
    None => ""
  }
  if sop != "1.2.840.10008.5.1.4.1.1.2" {
    raise @model.MedSealError::RuleViolation(
      "ct-classic-sop", "dataset/0008,0016", "met", "ct-classic-research-v1",
    )
  }
  match ct_text(dataset, "00080060") {
    Some("CT") => ()
    _ =>
      raise @model.MedSealError::RuleViolation(
        "ct-classic-sop", "dataset/0008,0060", "met", "ct-classic-research-v1",
      )
  }
  // Patient, Study, Series, Frame of Reference and Equipment modules.
  ct_require(
    dataset,
    [
      "00100010", "00100020", "00100030", "00100040", "00080020", "00080030", "00080050",
      "00080090", "0020000D", "00200010", "00080060", "0020000E", "00200011", "00080070",
      "00200052", "00201040",
    ],
    false,
  )
  // Image and CT Image Type 1/1C fields for this profile.
  ct_require(
    dataset,
    [
      "00080008", "00080018", "00200012", "00200013", "00200032", "00200037", "00280002",
      "00280004", "00280010", "00280011", "00280030", "00280100", "00280101", "00280102",
      "00280103", "00180050", "00180060", "00281052", "00281053", "00281054",
    ],
    true,
  )
  let photo = match ct_text(dataset, "00280004") {
    Some(value) => value
    None => ""
  }
  if photo != "MONOCHROME2" {
    raise @model.MedSealError::RuleViolation(
      "ct-pixel-contract", "dataset/0028,0004", "met", "pixels",
    )
  }
  let modality = match ct_text(dataset, "00080008") {
    Some(value) => value
    None => ""
  }
  if !modality.split("\\").to_array().contains("ORIGINAL") ||
    !modality.split("\\").to_array().contains("PRIMARY") {
    raise @model.MedSealError::RuleViolation(
      "ct-unknown-condition", "dataset/0008,0008", "met", "ct-classic-research-v1",
    )
  }
  let bits = match dataset.find(ct_tag("00280101")) {
    Some({ value: @model.ElementValue::UnsignedShort([value]), .. }) => value
    _ => 0U
  }
  let allocated = match dataset.find(ct_tag("00280100")) {
    Some({ value: @model.ElementValue::UnsignedShort([value]), .. }) => value
    _ => 0U
  }
  if allocated != 16U || bits < 12U || bits > 16U {
    raise @model.MedSealError::RuleViolation(
      "ct-pixel-contract", "dataset/0028,0100", "met", "pixels",
    )
  }
  if ct_text(dataset, "00281054") != Some("HU") {
    raise @model.MedSealError::RuleViolation(
      "ct-intensity-contract", "dataset/0028,1054", "met", "intensity",
    )
  }
  ct_decimal_vector(dataset, "00280030", 2)
  ct_decimal_vector(dataset, "00200032", 3)
  ct_decimal_vector(dataset, "00200037", 6)
}
