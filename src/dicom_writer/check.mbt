///|
fn check_model(element : @model.DataElement) -> Unit raise @model.MedSealError {
  let valid = match element.value {
    @model.ElementValue::Empty => element.vr != @model.Vr::SQ
    @model.ElementValue::Text(_) => element.vr.is_text()
    @model.ElementValue::Sequence(_) => element.vr == @model.Vr::SQ
    @model.ElementValue::UnsignedShort(values) =>
      element.vr == @model.Vr::US && values.all(fn(v) { v <= 65535U })
    @model.ElementValue::SignedShort(values) =>
      element.vr == @model.Vr::SS &&
      values.all(fn(v) { v >= -32768 && v <= 32767 })
    @model.ElementValue::UnsignedLong(_) => element.vr == @model.Vr::UL
    @model.ElementValue::SignedLong(_) => element.vr == @model.Vr::SL
    @model.ElementValue::Raw(bytes) =>
      !element.vr.is_text() &&
      element.vr != @model.Vr::SQ &&
      bytes.length() % 2 == 0
  }
  if !valid {
    raise @model.MedSealError::InvalidModel(
      "value does not match VR or supported range",
    )
  }
  match element.original_bytes {
    Some(bytes) => {
      if bytes.length() % 2 != 0 {
        raise @model.MedSealError::InvalidModel(
          "original text bytes have odd length",
        )
      }
      match element.value {
        @model.ElementValue::Text(value) if element.vr.is_text() => {
          let decoded = @utf8.decode(bytes) catch {
            _ =>
              raise @model.MedSealError::InvalidModel(
                "invalid cached text bytes",
              )
          }
          if decoded.trim_end(chars=" \u{0000}") != value {
            raise @model.MedSealError::InvalidModel(
              "cached bytes differ from text value",
            )
          }
        }
        @model.ElementValue::Empty if bytes.is_empty() => ()
        _ =>
          raise @model.MedSealError::InvalidModel(
            "cached bytes are only supported for text",
          )
      }
    }
    None => ()
  }
}

///|
fn encoded_size(
  dataset : @model.DataSet,
  depth : Int,
  count : Array[Int],
) -> Int raise @model.MedSealError {
  if depth > 32 {
    raise @model.MedSealError::ExcessiveNesting(depth)
  }
  let mut size = 0
  for element in dataset.elements {
    count[0] = count[0] + 1
    if count[0] > 100000 {
      raise @model.MedSealError::TooManyElements(count[0])
    }
    check_model(element)
    let length = match element.value {
      @model.ElementValue::Sequence(items) => {
        let mut total = 0
        for item in items {
          total = total + 8 + encoded_size(item, depth + 1, count)
          if total > 128 * 1024 * 1024 {
            raise @model.MedSealError::InvalidModel("sequence exceeds 128 MiB")
          }
        }
        total
      }
      _ => encode_ordinary_value(element).length()
    }
    if length % 2 != 0 ||
      length > 128 * 1024 * 1024 ||
      (!element.vr.uses_u32_length() && length > 65534) {
      raise @model.MedSealError::InvalidModel(
        "encoded value exceeds VR or element limits",
      )
    }
    size = size + (if element.vr.uses_u32_length() { 12 } else { 8 }) + length
    if size > 256 * 1024 * 1024 {
      raise @model.MedSealError::InvalidModel("dataset exceeds 256 MiB")
    }
  }
  size
}
