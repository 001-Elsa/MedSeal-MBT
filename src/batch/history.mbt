///|
priv struct HistoricalWitnesses {
  source : Array[(String, String, String)]
  mapped : Array[(String, String, String)]
}

///|
async fn historical_witnesses(
  metadata : Array[@model.DataSet],
  policy : @policy.Policy,
  provider : @identity_store.Provider?,
  program : String,
  destination : Json?,
) -> HistoricalWitnesses raise @model.MedSealError {
  let targets = @verification.missing_references(metadata)
  if targets.is_empty() {
    return { source: [], mapped: [], }
  }
  guard destination is Some(destination) && provider is Some(provider) else {
    raise @model.MedSealError::IdentityError(
      "unresolved SOP reference; complete the target batch first",
    )
  }
  let request = cache_request(policy, program, [])
  let fields = match request {
    Json::Object(fields) => fields
    _ => abort("object")
  }
  fields.remove("objects")
  fields.set("destination", destination)
  fields.set(
    "references",
    Json::array(
      targets.map(fn(target) {
        Json::object(
          Map::from_array([
            ("source_uid", Json::string(target.0)),
            ("owner_key", Json::string(target.1)),
            ("sop_class", Json::string(target.2)),
          ]),
        )
      }),
    ),
  )
  let response = match provider.history(Json::object(fields).stringify()) {
    Json::Object(fields) if fields.length() == 2 &&
      fields.get("schema") == Some(Json::number(1.0)) => fields
    _ => raise @model.MedSealError::IdentityError("invalid historical schema")
  }
  let entries = match response.get("entries") {
    Some(Json::Array(entries)) if entries.length() == targets.length() =>
      entries
    _ =>
      raise @model.MedSealError::IdentityError(
        "historical witnesses incomplete",
      )
  }
  let mapped : Array[(String, String, String)] = []
  for i, entry in entries {
    let f = match entry {
      Json::Object(fields) if fields.length() == 7 => fields
      _ =>
        raise @model.MedSealError::IdentityError("invalid historical witness")
    }
    if json_string(f.get("source_uid")) != targets[i].0 ||
      json_string(f.get("owner_key")) != targets[i].1 ||
      json_string(f.get("sop_class")) != targets[i].2 {
      raise @model.MedSealError::IdentityError(
        "historical witness differs from request",
      )
    }
    let file = json_string(f.get("file"))
    let sha = json_string(f.get("sha256"))
    if @storage.file_digest(file) != sha {
      raise @model.MedSealError::IdentityError(
        "historical target bytes changed",
      )
    }
    let parsed = @streaming.inspect(file).parsed
    check_meta(parsed)
    let uid = @identity.required_text(
      parsed.dataset,
      @model.Tag::new(0x0008U, 0x0018U),
    )
    let patient = @identity.required_text(
      parsed.dataset,
      @model.Tag::new(0x0010U, 0x0020U),
    )
    if uid != json_string(f.get("mapped_uid")) ||
      patient != json_string(f.get("mapped_patient")) ||
      @identity.required_text(parsed.dataset, @model.Tag::new(0x0008U, 0x0016U)) !=
      targets[i].2 ||
      !@verification.clean_private(parsed.dataset) {
      raise @model.MedSealError::IdentityError(
        "historical target identity or SOP Class changed",
      )
    }
    mapped.push((uid, "0:\{patient.length()}:\{patient}", targets[i].2))
  }
  { source: targets, mapped, }
}

///|
async fn Job::recheck_history(
  self : Job,
) -> Array[(String, String, String)] raise @model.MedSealError {
  let checked = historical_witnesses(
    self.metadata,
    self.policy,
    self.provider,
    self.program_sha256,
    self.destination,
  )
  if checked.source != self.historical.source ||
    checked.mapped != self.historical.mapped {
    raise @model.MedSealError::IdentityError(
      "historical witnesses changed since planning",
    )
  }
  checked.mapped
}

///|
/// Native verifier refreshes acknowledged historical witnesses.
pub async fn Job::verify_output(
  self : Job,
  output : String,
) -> String raise @model.MedSealError {
  verify(output, historical=self.recheck_history())
}
