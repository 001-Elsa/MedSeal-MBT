///|
pub fn check_preamble(data : Bytes) -> Unit raise @model.MedSealError {
  if data.length() < 132 {
    raise @model.MedSealError::FileTooSmall
  }
  if data[128] != b'D' ||
    data[129] != b'I' ||
    data[130] != b'C' ||
    data[131] != b'M' {
    raise @model.MedSealError::MissingDicmMarker
  }
}
