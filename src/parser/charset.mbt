///|
fn check_character_set(
  dataset : @model.DataSet,
  inherited : String,
) -> Unit raise @model.MedSealError {
  let charset = match dataset.find(@model.Tag::new(0x0008U, 0x0005U)) {
    Some(element) =>
      match element.value {
        @model.ElementValue::Text(value) => value
        @model.ElementValue::Empty => ""
        _ => raise @model.MedSealError::UnsupportedCharacterSet
      }
    None => inherited
  }
  if charset != "" && charset != "ISO_IR 6" && charset != "ISO_IR 192" {
    raise @model.MedSealError::UnsupportedCharacterSet
  }
  for element in dataset.elements {
    match element.value {
      @model.ElementValue::Text(value) =>
        if charset != "ISO_IR 192" && value.any(fn(c) { c.to_int() > 127 }) {
          raise @model.MedSealError::InvalidTextEncoding
        }
      @model.ElementValue::Sequence(items) =>
        for item in items {
          check_character_set(item, charset)
        }
      _ => ()
    }
  }
}
