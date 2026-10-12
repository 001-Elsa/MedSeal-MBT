///|
pub struct Context {
  priv policy : @policy.Policy
  priv uid_base : @bigint.BigInt
  priv patients : Map[String, String]
  priv uids : Map[String, String]
  priv offsets : Map[String, Int]
  priv date_offsets : Array[Int]
  priv mut ready : Bool
  priv mut prepared : Bool
}

///|
pub fn Context::is_strict(self : Context) -> Bool {
  self.policy.strict_metadata
}

///|
pub fn Context::new(
  uid_seed : String,
  policy : @policy.Policy,
  date_offsets : Array[Int],
) -> Context raise @model.MedSealError {
  if uid_seed.is_empty() ||
    uid_seed.length() > 29 ||
    !uid_seed.all(fn(c) { c >= '0' && c <= '9' }) ||
    uid_seed.has_prefix("0") {
    raise @model.MedSealError::IdentityError(
      "UID seed must be a positive decimal integer of at most 29 digits",
    )
  }
  if date_offsets.any(fn(days) {
      days == 0 ||
      days < -3650 ||
      days > 3650 ||
      days.abs() > policy.date_shift_days.abs()
    }) {
    raise @model.MedSealError::IdentityError("invalid per-patient date offset")
  }
  {
    policy,
    uid_base: @bigint.BigInt::from_string(uid_seed) *
    @bigint.BigInt::from_int(1000001),
    patients: Map([]),
    uids: Map([]),
    offsets: Map([]),
    date_offsets: date_offsets.copy(),
    ready: false,
    prepared: false,
  }
}

///|
pub fn text(dataset : @model.DataSet, tag : @model.Tag) -> String? {
  match dataset.find(tag) {
    Some(element) =>
      match element.value {
        @model.ElementValue::Text(value) => Some(value)
        @model.ElementValue::Empty => Some("")
        _ => None
      }
    None => None
  }
}

///|
pub fn required_text(
  dataset : @model.DataSet,
  tag : @model.Tag,
) -> String raise @model.MedSealError {
  match text(dataset, tag) {
    Some(value) if !value.is_empty() && !value.contains("\\") => value
    _ =>
      raise @model.MedSealError::IdentityError(
        "missing required identity field",
      )
  }
}

///|
fn patient_key(
  dataset : @model.DataSet,
  scope_name : String,
) -> String raise @model.MedSealError {
  let id = required_text(dataset, @model.Tag::new(0x0010U, 0x0020U))
  let issuer = text(dataset, @model.Tag::new(0x0010U, 0x0021U)).unwrap_or("")
  // Length-delimited components prevent ambiguous concatenation collisions.
  "\{scope_name.length()}:\{scope_name}\{issuer.length()}:\{issuer}\{id.length()}:\{id}"
}

///|
pub fn instance_uid(tag : @model.Tag) -> Bool {
  [
    @model.Tag::new(0x0008U, 0x0018U),
    @model.Tag::new(0x0008U, 0x1155U),
    @model.Tag::new(0x0020U, 0x000DU),
    @model.Tag::new(0x0020U, 0x000EU),
    @model.Tag::new(0x0020U, 0x0052U),
  ].contains(tag)
}

///|
pub fn standard_uid(tag : @model.Tag) -> Bool {
  [@model.Tag::new(0x0008U, 0x0016U), @model.Tag::new(0x0008U, 0x1150U)].contains(
    tag,
  )
}

///|
pub fn supported_sop_class(value : String) -> Bool {
  [
    "1.2.840.10008.5.1.4.1.1.2", "1.2.840.10008.5.1.4.1.1.4", "1.2.840.10008.5.1.4.1.1.7",
  ].contains(value)
}

///|
pub fn shifted_date(tag : @model.Tag) -> Bool {
  tag.group == 0x0008U &&
  [0x0020U, 0x0021U, 0x0022U, 0x0023U].contains(tag.element)
}

///|
fn collect_uids(
  dataset : @model.DataSet,
  values : Map[String, Bool],
  strict : Bool,
) -> Unit raise @model.MedSealError {
  for element in dataset.elements {
    if element.tag.is_private() {
      continue
    }
    if strict &&
      (
        element.tag.group == 0x0400U ||
        element.tag.group == 0xFFFAU ||
        element.tag.group == 0xFFFCU ||
        (element.tag.group >= 0x6000U && element.tag.group <= 0x60FFU) ||
        @dictionary.strict_attribute(element.tag).map(fn(a) { a.role }) ==
        Some("remove")
      ) {
      continue
    }
    match element.value {
      @model.ElementValue::Sequence(items) =>
        for item in items {
          collect_uids(item, values, strict)
        }
      @model.ElementValue::Text(value) if element.vr == @model.Vr::UI =>
        if instance_uid(element.tag) {
          for uid in value.split("\\") {
            if !uid.is_empty() {
              values.set(uid.to_owned(), true)
            }
          }
        } else if !standard_uid(element.tag) {
          raise @model.MedSealError::IdentityError(
            "unclassified public UID tag; extend the support matrix before processing",
          )
        }
      _ => ()
    }
  }
}

///|
// Preparation reads identities only. The context does not retain Pixel Data.
pub fn Context::prepare(
  self : Context,
  datasets : Array[@model.DataSet],
) -> Unit raise @model.MedSealError {
  if self.prepared {
    raise @model.MedSealError::IdentityError(
      "context preparation is single-use",
    )
  }
  self.prepared = true
  let patients : Map[String, Bool] = Map([])
  let uids : Map[String, Bool] = Map([])
  let signatures : Map[String, (String, String)] = Map([])
  for dataset in datasets {
    if self.policy.strict_metadata {
      @conformance.check(dataset)
    }
    if text(dataset, @model.Tag::new(0x0012U, 0x0062U)) == Some("YES") ||
      text(dataset, @model.Tag::new(0x0012U, 0x0063U)) is Some(_) {
      raise @model.MedSealError::IdentityError(
        "already processed datasets require a new explicit workflow",
      )
    }
    let key = patient_key(dataset, self.policy.scope_name)
    let signature = (
      text(dataset, @model.Tag::new(0x0010U, 0x0010U)).unwrap_or(""),
      text(dataset, @model.Tag::new(0x0010U, 0x0030U)).unwrap_or(""),
    )
    match signatures.get(key) {
      Some(previous) if previous != signature =>
        raise @model.MedSealError::IdentityError(
          "conflicting name or birth date for one patient identity key",
        )
      _ => signatures.set(key, signature)
    }
    patients.set(key, true)
    let sop_class = required_text(dataset, @model.Tag::new(0x0008U, 0x0016U))
    if !supported_sop_class(sop_class) {
      raise @model.MedSealError::IdentityError(
        "SOP Class is outside CT, MR and Secondary Capture support",
      )
    }
    collect_uids(dataset, uids, self.policy.strict_metadata)
  }
  let keys = patients.keys().to_array()
  keys.sort()
  if keys.length() > self.date_offsets.length() {
    raise @model.MedSealError::IdentityError(
      "not enough per-patient date offsets",
    )
  }
  for index, key in keys {
    let patient = "P\{index + 1}"
    self.patients.set(key, patient)
    self.offsets.set(patient, self.date_offsets[index])
  }
  let keys = uids.keys().to_array()
  keys.sort()
  if keys.length() > 100000 {
    raise @model.MedSealError::IdentityError("job exceeds 100000 unique UIDs")
  }
  for index, key in keys {
    let value = self.uid_base + @bigint.BigInt::from_int(index + 1)
    let mapped = "2.25.\{value.to_string()}"
    if uids.contains(mapped) {
      raise @model.MedSealError::IdentityError(
        "generated UID collides with source UID",
      )
    }
    self.uids.set(key, mapped)
  }
  self.ready = true
}

///|
pub fn Context::date_offset(
  self : Context,
  patient : String,
) -> Int raise @model.MedSealError {
  match self.offsets.get(patient) {
    Some(value) => value
    None =>
      raise @model.MedSealError::IdentityError("unknown patient date offset")
  }
}

///|
pub fn Context::mapped_uid(
  self : Context,
  uid : String,
) -> String raise @model.MedSealError {
  match self.uids.get(uid) {
    Some(value) if self.ready => value
    _ =>
      raise @model.MedSealError::IdentityError(
        "UID was not present during preparation",
      )
  }
}

///|
pub fn Context::patient(
  self : Context,
  dataset : @model.DataSet,
) -> String raise @model.MedSealError {
  match self.patients.get(patient_key(dataset, self.policy.scope_name)) {
    Some(value) if self.ready => value
    _ =>
      raise @model.MedSealError::IdentityError(
        "patient was not present during preparation",
      )
  }
}
