///|
fn person_name(json : Json) -> String raise @dicom.MedSealError {
  let obj = fields(json)
  for key in obj.keys() {
    if !["Alphabetic", "Ideographic", "Phonetic"].contains(key) {
      raise invalid("unknown PN group")
    }
  }
  let groups : Array[String] = []
  for key in ["Alphabetic", "Ideographic", "Phonetic"] {
    let value = match obj.get(key) {
      None => ""
      Some(Json::String(value)) if !value.contains("=") &&
        !value.contains("\\") &&
        value.split("^").count() <= 5 &&
        value.length() <= 64 => value
      _ => raise invalid("invalid PN group")
    }
    groups.push(value)
  }
  while groups.last() == Some("") {
    ignore(groups.pop())
  }
  groups.join("=")
}

///|
fn text_values(
  vr : @dicom.Vr,
  values : Array[Json],
  budget : Budget,
) -> String raise @dicom.MedSealError {
  if single_text(vr) && values.length() != 1 {
    raise invalid("single-valued text VR")
  }
  let components = values.map(value => {
    budget.node(0)
    let text = match value {
      Json::Null => ""
      _ if vr == @dicom.Vr::PN => person_name(value)
      _ if vr == @dicom.Vr::DS || vr == @dicom.Vr::IS => {
        let text = numeric_text(value)
        check_numeric(text, vr)
        text
      }
      Json::String(text) => text
      _ => raise invalid("text VR requires strings")
    }
    if !single_text(vr) && text.contains("\\") {
      raise invalid("unescaped value delimiter")
    }
    if text.contains("\u{0000}") {
      raise invalid("NUL in text")
    }
    budget.text(text)
    text
  })
  components.join("\\")
}

///|
fn integer_value(
  json : Json,
  low : Double,
  high : Double,
  budget : Budget,
) -> Double raise @dicom.MedSealError {
  budget.node(0)
  match json {
    Json::Object(_) => {
      let text = numeric_text(json)
      if !integer_text(text) {
        raise invalid("integer VR requires integer JSON token")
      }
      let number = @string.parse_double(text) catch {
        _ => raise invalid("integer VR representation")
      }
      if number < low || number > high {
        raise invalid("integer VR range")
      }
      number
    }
    _ => raise invalid("integer VR requires JSON number")
  }
}

///|
fn decode_dataset(
  json : Json,
  depth : Int,
  budget : Budget,
) -> @dicom.DataSet raise @dicom.MedSealError {
  budget.node(depth)
  let obj = fields(json)
  let names = obj.keys().to_array()
  names.sort()
  let elements : Array[@dicom.DataElement] = []
  for name in names {
    budget.node(depth)
    let tag = tag(name)
    let attr = fields(obj.get(name).unwrap())
    for key in attr.keys() {
      if !["vr", "Value", "InlineBinary"].contains(key) {
        raise invalid("unsupported attribute member or BulkDataURI")
      }
    }
    let vr = match attr.get("vr") {
      Some(Json::String(text)) =>
        @dicom.Vr::from_string(text).unwrap_or_else(() => {
          raise invalid("unknown VR")
        })
      _ => raise invalid("missing VR")
    }
    if !supported(vr) {
      raise invalid("unsupported VR")
    }
    if attr.contains("Value") && attr.contains("InlineBinary") {
      raise invalid("multiple value representations")
    }
    let value = match (attr.get("Value"), attr.get("InlineBinary")) {
      (None, None) =>
        if vr == @dicom.Vr::SQ {
          @dicom.ElementValue::Sequence([])
        } else {
          @dicom.ElementValue::Empty
        }
      (None, Some(Json::String(text))) if [
          @dicom.Vr::OB,
          @dicom.Vr::OW,
          @dicom.Vr::UN,
        ].contains(vr) => {
        if text.length() > 1398104 {
          raise invalid("InlineBinary exceeds 1 MiB")
        }
        let bytes = @base64.decode(text) catch {
          _ => raise invalid("invalid InlineBinary")
        }
        if bytes.length() > 1024 * 1024 ||
          bytes.length() % vr.value_unit_size() != 0 ||
          @base64.encode(bytes) != text {
          raise invalid("noncanonical or unaligned InlineBinary")
        }
        // DICOM native values are even-length. No automatic padding: it would
        // change payload bytes and conceal an invalid original representation.
        if bytes.length() % 2 != 0 {
          raise invalid("odd InlineBinary length")
        }
        if bytes.is_empty() {
          @dicom.ElementValue::Empty
        } else {
          @dicom.ElementValue::Raw(bytes)
        }
      }
      (Some(Json::Array(values)), None) => {
        if values.is_empty() && vr != @dicom.Vr::SQ {
          raise invalid("empty Value must be omitted")
        }
        match vr {
          SQ =>
            @dicom.ElementValue::Sequence(
              values.map(item => decode_dataset(item, depth + 1, budget)),
            )
          US =>
            @dicom.ElementValue::UnsignedShort(
              values.map(v => integer_value(v, 0.0, 65535.0, budget).to_uint()),
            )
          SS =>
            @dicom.ElementValue::SignedShort(
              values.map(v => {
                integer_value(v, -32768.0, 32767.0, budget).to_int()
              }),
            )
          UL =>
            @dicom.ElementValue::UnsignedLong(
              values.map(v => {
                integer_value(v, 0.0, 4294967295.0, budget).to_uint()
              }),
            )
          SL =>
            @dicom.ElementValue::SignedLong(
              values.map(v => {
                integer_value(v, -2147483648.0, 2147483647.0, budget).to_int()
              }),
            )
          _ if vr.is_text() => {
            let text = text_values(vr, values, budget)
            if text.is_empty() {
              @dicom.ElementValue::Empty
            } else {
              @dicom.ElementValue::Text(text)
            }
          }
          _ => raise invalid("VR requires InlineBinary")
        }
      }
      _ => raise invalid("invalid value representation")
    }
    elements.push(
      @dicom.DataElement::new(tag, vr, 0U, value, elements.length()),
    )
  }
  @dicom.DataSet::new(elements)
}

///|
/// Decode one DICOM JSON Dataset (PS3.18 2025e F.2, documented subset).
/// This contains private metadata, not a public explanation or IOD approval.
pub fn decode(text : String) -> @dicom.DataSet raise @dicom.MedSealError {
  let tokenized = preflight(text)
  let json = @json.parse(tokenized) catch {
    _ => raise invalid("malformed JSON")
  }
  decode_dataset(json, 0, Budget::new())
}
