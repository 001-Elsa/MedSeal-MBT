///|
fn encode_person_name(text : String) -> Json raise @dicom.MedSealError {
  let groups = text.split("=").to_array()
  if groups.length() > 3 {
    raise invalid("too many PN groups")
  }
  let result : Map[String, Json] = Map([])
  let names = ["Alphabetic", "Ideographic", "Phonetic"]
  for index, group in groups {
    if group.length() > 64 || group.split("^").count() > 5 {
      raise invalid("invalid PN group")
    }
    if !group.is_empty() {
      result.set(names[index], Json::string(group.to_owned()))
    }
  }
  Json::object(result)
}

///|
fn encode_dataset(
  dataset : @dicom.DataSet,
  depth : Int,
  budget : Budget,
) -> Json raise @dicom.MedSealError {
  budget.node(depth)
  let result : Map[String, Json] = Map([])
  let elements = dataset.elements.copy()
  elements.sort_by((a, b) => a.tag.compact().compare(b.tag.compact()))
  for element in elements {
    budget.node(depth)
    if element.tag.group > 65535U || element.tag.element > 65535U {
      raise invalid("tag range")
    }
    let name = element.tag.compact().replace(old=",", new="")
    ignore(tag(name))
    if result.contains(name) {
      raise invalid("duplicate dataset tag")
    }
    let vr = element.vr
    if !supported(vr) {
      raise invalid("unsupported VR")
    }
    let attr = Map::from_array([("vr", Json::string(vr.to_string()))])
    let values : Array[Json] = match element.value {
      @dicom.ElementValue::Empty => []
      @dicom.ElementValue::Text(text) if vr.is_text() => {
        budget.text(text)
        if text.contains("\u{0000}") {
          raise invalid("NUL in text")
        }
        if text.is_empty() {
          []
        } else {
          let parts = if single_text(vr) {
            [text]
          } else {
            text.split("\\").map(part => part.to_owned()).to_array()
          }
          parts.map(part => {
            budget.node(depth)
            if part.is_empty() {
              Json::null()
            } else if vr == @dicom.Vr::PN {
              encode_person_name(part)
            } else {
              if vr == @dicom.Vr::DS || vr == @dicom.Vr::IS {
                check_numeric(part, vr)
              }
              Json::string(part)
            }
          })
        }
      }
      @dicom.ElementValue::Sequence(items) if vr == @dicom.Vr::SQ =>
        items.map(item => encode_dataset(item, depth + 1, budget))
      @dicom.ElementValue::UnsignedShort(values) if vr == @dicom.Vr::US &&
        values.all(v => v <= 65535U) =>
        values.map(v => {
          budget.node(depth)
          Json::number(v.to_double())
        })
      @dicom.ElementValue::SignedShort(values) if vr == @dicom.Vr::SS &&
        values.all(v => v >= -32768 && v <= 32767) =>
        values.map(v => {
          budget.node(depth)
          Json::number(v.to_double())
        })
      @dicom.ElementValue::UnsignedLong(values) if vr == @dicom.Vr::UL =>
        values.map(v => {
          budget.node(depth)
          Json::number(v.to_double())
        })
      @dicom.ElementValue::SignedLong(values) if vr == @dicom.Vr::SL =>
        values.map(v => {
          budget.node(depth)
          Json::number(v.to_double())
        })
      @dicom.ElementValue::Raw(bytes) if [
          @dicom.Vr::OB,
          @dicom.Vr::OW,
          @dicom.Vr::UN,
        ].contains(vr) => {
        if bytes.length() > 1024 * 1024 || bytes.length() % 2 != 0 {
          raise invalid("InlineBinary size or alignment")
        }
        budget.spend(4 * ((bytes.length() + 2) / 3))
        if !bytes.is_empty() {
          attr.set("InlineBinary", Json::string(@base64.encode(bytes)))
        }
        []
      }
      _ => raise invalid("model value does not match VR")
    }
    if !values.is_empty() {
      attr.set("Value", Json::array(values))
    }
    result.set(name, Json::object(attr))
  }
  Json::object(result)
}

///|
/// Canonical ascending tag order. DS/IS use strings to preserve decimal text.
/// No values are removed or anonymized; never use this as a public report.
pub fn encode(dataset : @dicom.DataSet) -> String raise @dicom.MedSealError {
  let text = encode_dataset(dataset, 0, Budget::new()).stringify()
  if @utf8.encode(text).length() > 8 * 1024 * 1024 {
    raise invalid("output exceeds 8 MiB")
  }
  text
}
