///|
/// Private IPC payload: never write this to public logs or delivery artifacts.
pub fn Context::binding_request(
  self : Context,
  datasets : Array[@model.DataSet],
  hashes : Array[String],
) -> String raise @model.MedSealError {
  if !self.ready {
    raise @model.MedSealError::IdentityError("context is not prepared")
  }
  let patients : Map[String, Json] = Map([])
  if hashes.length() != datasets.length() {
    raise @model.MedSealError::IdentityError(
      "missing private object fingerprints",
    )
  }
  let objects : Array[Json] = []
  let owners : Array[Json] = []
  for index, dataset in datasets {
    let key = patient_key(dataset, self.policy.scope_name)
    patients.set(
      key,
      Json::object(
        Map::from_array([
          ("key", Json::string(key)),
          (
            "name",
            Json::string(
              text(dataset, @model.Tag::new(0x0010U, 0x0010U)).unwrap_or(""),
            ),
          ),
          (
            "birth_date",
            Json::string(
              text(dataset, @model.Tag::new(0x0010U, 0x0030U)).unwrap_or(""),
            ),
          ),
        ]),
      ),
    )
    let study = required_text(dataset, @model.Tag::new(0x0020U, 0x000DU))
    let series = required_text(dataset, @model.Tag::new(0x0020U, 0x000EU))
    let instance = required_text(dataset, @model.Tag::new(0x0008U, 0x0018U))
    objects.push(
      Json::array([Json::string(instance), Json::string(hashes[index])]),
    )
    for
      (uid, role, parent) in [
        (instance, "instance", series),
        (study, "study", ""),
        (series, "series", study),
      ] {
      owners.push(
        Json::array([
          Json::string(uid),
          Json::string(role),
          Json::string(key),
          Json::string(parent),
        ]),
      )
    }
    if text(dataset, @model.Tag::new(0x0020U, 0x0052U)) is Some(frame) &&
      !frame.is_empty() {
      owners.push(
        Json::array([
          Json::string(frame),
          Json::string("frame"),
          Json::string(key),
          Json::string(""),
        ]),
      )
    }
  }
  let keys = patients.keys().to_array()
  keys.sort()
  let uids = self.uids.keys().to_array()
  uids.sort()
  Json::object(
    Map::from_array([
      ("schema", Json::number(2.0)),
      ("namespace", Json::string(self.policy.scope_name)),
      ("date_shift_days", Json::number(self.policy.date_shift_days.to_double())),
      ("patients", Json::array(keys.map(fn(key) { patients[key] }))),
      ("uids", Json::array(uids.map(Json::string))),
      ("objects", Json::array(objects)),
      ("owners", Json::array(owners)),
    ]),
  ).stringify()
}

///|
fn fields(json : Json) -> Map[String, Json] raise @model.MedSealError {
  match json {
    Json::Object(fields) => fields
    _ =>
      raise @model.MedSealError::IdentityError(
        "binding response is not an object",
      )
  }
}

///|
fn string_field(json : Json?) -> String raise @model.MedSealError {
  match json {
    Some(Json::String(value)) => value
    _ =>
      raise @model.MedSealError::IdentityError("binding response needs string")
  }
}

///|
/// Replace provisional per-job mappings only after validating a complete response.
pub fn Context::load_bindings(
  self : Context,
  response : String,
) -> Unit raise @model.MedSealError {
  if !self.ready || response.length() > 32 * 1024 * 1024 {
    raise @model.MedSealError::IdentityError(
      "invalid binding response size or state",
    )
  }
  let root = fields(
    @json.parse(response) catch {
      _ => raise @model.MedSealError::IdentityError("invalid binding JSON")
    },
  )
  if root.get("schema") != Some(Json::number(1.0)) {
    raise @model.MedSealError::IdentityError("unsupported binding schema")
  }
  let patient_list = match root.get("patients") {
    Some(Json::Array(values)) => values
    _ => raise @model.MedSealError::IdentityError("missing patient bindings")
  }
  let uid_list = match root.get("uids") {
    Some(Json::Array(values)) => values
    _ => raise @model.MedSealError::IdentityError("missing UID bindings")
  }
  if patient_list.length() != self.patients.length() ||
    uid_list.length() != self.uids.length() {
    raise @model.MedSealError::IdentityError("incomplete binding response")
  }
  let patients : Map[String, String] = Map([])
  let offsets : Map[String, Int] = Map([])
  for item in patient_list {
    let item = fields(item)
    let key = string_field(item.get("key"))
    let pseudonym = string_field(item.get("alias"))
    let days = match item.get("offset") {
      Some(Json::Number(n, ..)) if n.to_int().to_double() == n &&
        n >= -3650.0 &&
        n <= 3650.0 => n.to_int()
      _ =>
        raise @model.MedSealError::IdentityError("invalid stored date offset")
    }
    if !self.patients.contains(key) ||
      patients.contains(key) ||
      offsets.contains(pseudonym) ||
      pseudonym.is_empty() ||
      pseudonym.length() > 48 ||
      !pseudonym.all(fn(c) { (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') }) ||
      days == 0 ||
      days.abs() > self.policy.date_shift_days.abs() ||
      (days > 0) != (self.policy.date_shift_days > 0) {
      raise @model.MedSealError::IdentityError("invalid patient binding")
    }
    patients.set(key, pseudonym)
    offsets.set(pseudonym, days)
  }
  let uids : Map[String, String] = Map([])
  let destinations : Map[String, Bool] = Map([])
  for item in uid_list {
    let item = fields(item)
    let source = string_field(item.get("source"))
    let mapped = string_field(item.get("mapped"))
    if !self.uids.contains(source) ||
      uids.contains(source) ||
      destinations.contains(mapped) ||
      self.uids.contains(mapped) ||
      !mapped.has_prefix("2.25.") ||
      mapped.length() > 44 ||
      mapped.length() < 6 ||
      !mapped[5:].all(fn(c) { c >= '0' && c <= '9' }) ||
      mapped[5:].has_prefix("0") {
      raise @model.MedSealError::IdentityError("invalid stored UID binding")
    }
    uids.set(source, mapped)
    destinations.set(mapped, true)
  }
  self.patients.clear()
  self.offsets.clear()
  self.uids.clear()
  for key, value in patients {
    self.patients.set(key, value)
  }
  for key, value in offsets {
    self.offsets.set(key, value)
  }
  for key, value in uids {
    self.uids.set(key, value)
  }
}
