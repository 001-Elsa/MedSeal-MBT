///|
fn tag(value : String) -> @model.Tag {
  // Only fixed, generated eight-hex constants are passed by this module.
  let number = @string.parse_uint(value, base=16) catch { _ => 0U }
  @model.Tag::new(number >> 16, number & 65535U)
}

///|
fn multiplicity(element : @model.DataElement) -> Int {
  match element.value {
    @model.ElementValue::Empty => 0
    @model.ElementValue::Text(value) =>
      if value.is_empty() {
        0
      } else {
        value.split("\\").count()
      }
    @model.ElementValue::UnsignedShort(v) => v.length()
    @model.ElementValue::SignedShort(v) => v.length()
    @model.ElementValue::UnsignedLong(v) => v.length()
    @model.ElementValue::SignedLong(v) => v.length()
    @model.ElementValue::Raw(v) =>
      if v.is_empty() {
        0
      } else if [
          @model.Vr::OB,
          @model.Vr::OW,
          @model.Vr::OF,
          @model.Vr::OD,
          @model.Vr::OL,
          @model.Vr::OV,
          @model.Vr::UN,
        ].contains(element.vr) {
        1
      } else {
        v.length() / element.vr.value_unit_size()
      }
    @model.ElementValue::Sequence(_) => 1
  }
}

///|
fn valid_vm(vm : String, count : Int) -> Bool {
  if count == 0 {
    return true
  }
  let parts = vm.split("-").to_array()
  let first = @string.parse_int(parts[0]) catch { _ => return false }
  if parts.length() == 1 {
    return count == first
  }
  let last = parts[1]
  if last == "n" {
    return count >= first
  }
  if last.has_suffix("n") {
    let step = @string.parse_int(last[0:last.length() - 1]) catch {
      _ => return false
    }
    return count >= first && step > 0 && count % step == 0
  }
  let maximum = @string.parse_int(last) catch { _ => return false }
  count >= first && count <= maximum
}

///|
fn fields(
  dataset : @model.DataSet,
  nested : Bool,
) -> Unit raise @model.MedSealError {
  let seen : Map[@model.Tag, Bool] = Map([])
  for element in dataset.elements {
    if seen.contains(element.tag) {
      raise @model.MedSealError::InvalidModel("duplicate attribute")
    }
    seen.set(element.tag, true)
    if element.tag.is_private() || element.tag.element == 0U {
      continue
    }
    if element.tag.group == 0x0400U ||
      element.tag.group == 0xFFFAU ||
      element.tag.group == 0xFFFCU ||
      (element.tag.group >= 0x6000U && element.tag.group <= 0x60FFU) {
      continue // explicitly removed by strict transformation
    }
    let attribute = match @dictionary.strict_attribute(element.tag) {
      Some(attribute) => attribute
      None =>
        raise @model.MedSealError::PolicyError(
          "unclassified public attribute \{element.tag.compact()}",
        )
    }
    if nested &&
      !["standard-uid", "instance-uid", "descriptive"].contains(attribute.role) {
      raise @model.MedSealError::PolicyError(
        "unsupported reference item context",
      )
    }
    if !attribute.vr.split(" or ").any(fn(vr) { vr == element.vr.to_string() }) {
      raise @model.MedSealError::InvalidModel(
        "attribute VR differs from pinned dictionary",
      )
    }
    if !valid_vm(attribute.vm, multiplicity(element)) {
      raise @model.MedSealError::InvalidModel(
        "attribute VM differs from pinned dictionary",
      )
    }
    match element.value {
      @model.ElementValue::Sequence(items) if attribute.role == "sequence" =>
        for item in items {
          fields(item, true)
          required(item, ["00081150", "00081155"], true)
        }
      @model.ElementValue::Text(value) if [@model.Vr::DS, @model.Vr::IS].contains(
          element.vr,
        ) =>
        for component in value.split("\\") {
          if component.is_empty() {
            continue
          }
          if component.any(fn(c) {
              !(c >= '0' && c <= '9') &&
              !['+', '-', '.', 'e', 'E', ' '].contains(c)
            }) {
            raise @model.MedSealError::InvalidModel("invalid numeric string")
          }
          if element.vr == @model.Vr::IS {
            ignore(
              @string.parse_int(component.trim()) catch {
                _ =>
                  raise @model.MedSealError::InvalidModel(
                    "IS outside signed integer range",
                  )
              },
            )
          } else {
            let number = @string.parse_double(component.trim()) catch {
              _ => raise @model.MedSealError::InvalidModel("invalid DS")
            }
            if number.is_nan() || number.is_inf() {
              raise @model.MedSealError::InvalidModel("non-finite DS")
            }
          }
        }
      _ => ()
    }
  }
}

///|
fn required(
  dataset : @model.DataSet,
  tags : Array[String],
  nonempty : Bool,
) -> Unit raise @model.MedSealError {
  for text in tags {
    let element = match dataset.find(tag(text)) {
      Some(element) => element
      None =>
        raise @model.MedSealError::InvalidModel(
          "missing declared Type 1/2 field \{text}",
        )
    }
    if nonempty && multiplicity(element) == 0 {
      raise @model.MedSealError::InvalidModel(
        "empty declared Type 1 field \{text}",
      )
    }
  }
}

///|
/// Declared field/module subset, with independent full-IOD acceptance still required.
pub fn check(
  dataset : @model.DataSet,
  full_pixels? : Bool = false,
) -> Unit raise @model.MedSealError {
  if !@validator.validate_dataset(dataset).is_valid() {
    raise @model.MedSealError::InvalidModel("basic value validation failed")
  }
  fields(dataset, false)
  required(
    dataset,
    [
      "00080016", "00080018", "00080060", "0020000D", "0020000E", "00280002", "00280004",
      "00280010", "00280011", "00280100", "00280101", "00280102", "00280103",
    ],
    true,
  )
  required(
    dataset,
    [
      "00100010", "00100020", "00100030", "00100040", "00080020", "00080030", "00080070",
      "00080090", "00200010", "00080050", "00200011", "00200013",
    ],
    false,
  )
  let sop = match dataset.find(tag("00080016")) {
    Some({ value: @model.ElementValue::Text(value), .. }) => value
    _ => raise @model.MedSealError::InvalidModel("invalid SOP Class")
  }
  if sop == "1.2.840.10008.5.1.4.1.1.7" {
    required(dataset, ["00080064"], true)
    required(dataset, ["00200020"], false)
  } else if sop == "1.2.840.10008.5.1.4.1.1.2" ||
    sop == "1.2.840.10008.5.1.4.1.1.4" {
    required(
      dataset,
      ["00080008", "00200032", "00200037", "00200052", "00280030"],
      true,
    )
    required(dataset, ["00080070", "00180050", "00200012", "00201040"], false)
    if sop == "1.2.840.10008.5.1.4.1.1.2" {
      required(dataset, ["00281052", "00281053"], true)
    }
  } else {
    raise @model.MedSealError::InvalidModel("unsupported strict SOP Class")
  }
  if full_pixels {
    required(dataset, ["7FE00010"], true)
  }
  let high = dataset.find(tag("00280102"))
  let bits = dataset.find(tag("00280101"))
  match (high, bits) {
    (
      Some({ value: @model.ElementValue::UnsignedShort([h]), .. }),
      Some({ value: @model.ElementValue::UnsignedShort([b]), .. }),
    ) if b > 0U && h + 1U == b => ()
    _ =>
      raise @model.MedSealError::InvalidModel(
        "High Bit must equal Bits Stored minus one",
      )
  }
  let number = fn(text : String) -> UInt raise @model.MedSealError {
    match dataset.find(tag(text)) {
      Some({ value: @model.ElementValue::UnsignedShort([n]), .. }) => n
      _ =>
        raise @model.MedSealError::InvalidModel("missing single image number")
    }
  }
  let allocated = number("00280100")
  if number("00280002") != 1U || ![8U, 16U].contains(allocated) {
    raise @model.MedSealError::InvalidModel(
      "strict profile accepts monochrome 8/16 bit images only",
    )
  }
  let photo = match dataset.find(tag("00280004")) {
    Some({ value: @model.ElementValue::Text(v), .. }) => v
    _ => ""
  }
  if !["MONOCHROME1", "MONOCHROME2"].contains(photo) {
    raise @model.MedSealError::InvalidModel(
      "unsupported photometric interpretation",
    )
  }
  if dataset.find(tag("00280008"))
    is Some({ value: @model.ElementValue::Text(v), .. }) &&
    v != "1" {
    raise @model.MedSealError::InvalidModel(
      "multi-frame objects need a separate reviewed SOP profile",
    )
  }
  if full_pixels {
    let length = match dataset.find(tag("7FE00010")) {
      Some({ value: @model.ElementValue::Raw(v), .. }) => v.length().to_int64()
      _ =>
        raise @model.MedSealError::InvalidModel(
          "unsupported pixel representation",
        )
    }
    let expected = number("00280010").to_int64() *
      number("00280011").to_int64() *
      (allocated / 8U).to_int64()
    if length != expected + expected % 2L {
      raise @model.MedSealError::InvalidModel(
        "pixel payload does not match declared dimensions",
      )
    }
  }
}

///|
/// Image payload dimension check without claiming pixels were decoded or reviewed.
pub fn check_pixel_length(
  dataset : @model.DataSet,
  length : Int,
) -> Unit raise @model.MedSealError {
  check(dataset)
  let number = fn(value : String) -> Int64 raise @model.MedSealError {
    match dataset.find(tag(value)) {
      Some({ value: @model.ElementValue::UnsignedShort([n]), .. }) =>
        n.to_int64()
      _ => raise @model.MedSealError::InvalidModel("missing image number")
    }
  }
  let expected = number("00280010") *
    number("00280011") *
    (number("00280100") / 8L)
  if length.to_int64() != expected + expected % 2L {
    raise @model.MedSealError::InvalidModel(
      "streamed payload differs from declared image dimensions",
    )
  }
}
