///|
pub struct ValidationIssue {
  priv error : @model.MedSealError
}

///|
pub fn issue(error : @model.MedSealError) -> ValidationIssue {
  { error, }
}

///|
pub fn ValidationIssue::to_json(self : ValidationIssue) -> Json {
  public_error(self.error)
}

///|
/// Fixed code only for legacy errors: their message payloads are private.
pub fn public_error(error : @model.MedSealError) -> Json {
  let fields = Map::from_array([
    ("code", Json::string(error.code())),
    ("stage", Json::string("validation")),
    ("rule_id", Json::string("public-error-boundary")),
    ("path", Json::string("dataset")),
    ("condition", Json::string("unknown")),
    ("source", Json::string("MedSeal public error contract v1")),
    ("evidence_id", Json::string("public-error-canary")),
  ])
  match error {
    @model.MedSealError::RuleViolation(id, path, condition, stage) if @rulebook.known_contract(
        id,
      ) &&
      @rulebook.safe_path(path) &&
      ["met", "not-met", "unknown"].contains(condition) &&
      [
        "vr", "vm", "values", "structure", "context", "classification", "requiredness",
        "profile", "pixels", "condition", "numeric",
      ].contains(stage) => {
      fields.set("rule_id", Json::string(id))
      fields.set("path", Json::string(path))
      fields.set("condition", Json::string(condition))
      fields.set("stage", Json::string(stage))
      fields.set("source", Json::string(@rulebook.contract_source(id)))
      fields.set("evidence_id", Json::string(@rulebook.contract_evidence(id)))
    }
    _ => ()
  }
  Json::object(fields)
}

///|
/// Reuse the strict converter; the output contains only allowlisted decisions.
pub fn object(bytes : Bytes, policy : @policy.Policy) -> Json {
  try {
    if !policy.strict_metadata {
      raise @model.MedSealError::PolicyError(
        "object explanation requires strict policy",
      )
    }
    let input = @validation.validate(bytes)
    let dataset = input.private_dataset()
    // This local context is used only to exercise decisions, never to deliver data.
    let context = @identity.Context::new("123456789", policy, [1])
    context.prepare([dataset])
    let output = @validation.convert(input, context)
    Json::object(
      Map::from_array([
        ("schema", Json::number(1.0)),
        ("status", Json::string("converted-explanation")),
        ("release_authorized", Json::boolean(false)),
        ("rulebook_sha256", Json::string(@rulebook.digest)),
        ("policy", policy.public_explain()),
        ("conditions", policy.public_conditions(dataset)),
        ("decisions", output.public_decisions()),
      ]),
    )
  } catch {
    error =>
      Json::object(
        Map::from_array([
          ("schema", Json::number(1.0)),
          ("status", Json::string("blocked")),
          ("release_authorized", Json::boolean(false)),
          ("issue", public_error(error)),
        ]),
      )
  }
}

///|
/// Current-batch relations only. Historical targets are not implicitly allowed.
pub fn collection(objects : Array[@validation.ValidatedObject]) -> Json {
  try {
    if objects.is_empty() || objects.length() > 10000 {
      raise @model.MedSealError::InvalidArgument("collection count budget")
    }
    let datasets = objects.map(object => object.private_dataset())
    let report = @verification.check(datasets)
    Json::object(
      Map::from_array([
        ("schema", Json::number(1.0)),
        ("status", Json::string("collection-validated")),
        ("release_authorized", Json::boolean(false)),
        ("scope", Json::string("current-batch-only")),
        ("objects", Json::number(report.objects.to_double())),
        ("references", Json::number(report.references.to_double())),
        (
          "external_references",
          Json::number(report.external_references.to_double()),
        ),
      ]),
    )
  } catch {
    error =>
      Json::object(
        Map::from_array([
          ("schema", Json::number(1.0)),
          ("status", Json::string("blocked")),
          ("release_authorized", Json::boolean(false)),
          ("issue", public_error(error)),
        ]),
      )
  }
}
