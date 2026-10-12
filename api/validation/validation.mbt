///|
pub struct ValidatedObject {
  priv source : Bytes
}

///|
pub struct ConvertedObject {
  priv output : Bytes
  priv decisions : Array[@rulebook.RuleDecision]
}

///|
/// Own a validated snapshot. Caller mutations cannot change this state.
pub fn validate(bytes : Bytes) -> ValidatedObject raise @model.MedSealError {
  let source = bytes
  let file = @parser.parse(source)
  @conformance.check_research(file.dataset, full_pixels=true)
  @verification.check_file_meta(file)
  { source, }
}

///|
/// Detached private data for preparation; never use this in public reports.
pub fn ValidatedObject::private_dataset(
  self : ValidatedObject,
) -> @model.DataSet raise @model.MedSealError {
  @parser.parse(self.source).dataset
}

///|
pub fn convert(
  input : ValidatedObject,
  context : @identity.Context,
) -> ConvertedObject raise @model.MedSealError {
  if !context.is_strict() {
    raise @model.MedSealError::PolicyError(
      "typed conversion requires strict context",
    )
  }
  let source = @parser.parse(input.source)
  let result = context.apply(source.dataset)
  @conformance.check_research(result.dataset, full_pixels=true)
  let output = @dicom_writer.write_deidentified(source, result.dataset)
  let reread = @parser.parse(output)
  @conformance.check_research(reread.dataset, full_pixels=true)
  if !@verification.same_values(result.dataset, reread.dataset) {
    raise @model.MedSealError::OutputVerificationFailed(
      "typed conversion round trip",
    )
  }
  let decisions = result.events.map(event => {
    let leaf = event.path.split("/").to_array().last().unwrap().to_owned()
    let tag = @model.Tag::new(
      hex(leaf[0:4].to_owned()),
      hex(leaf[5:9].to_owned()),
    )
    @rulebook.decision(
      tag,
      event.path,
      event.action,
      temporal=context.retains_dt() &&
        ["precision-preserving-dt", "retained-timezone-context"].contains(
          event.rule,
        ),
      custom=![
        "retain-supported", "reference-sequence", "identity-uid", "full-date-offset",
        "patient-pseudonym", "strict-empty-or-descriptive", "direct-identifier",
        "strict-remove-sensitive-structure", "remove-private-or-obsolete-length",
      ].contains(event.rule),
    )
  })
  decisions.sort_by(fn(a, b) { a.path.compare(b.path) })
  { output, decisions, }
}

///|
fn hex(text : String) -> UInt {
  let mut value = 0U
  for c in text {
    value = value * 16U +
      (if c <= '9' { c.to_int() - 48 } else { c.to_int() - 55 }).reinterpret_as_uint()
  }
  value
}

///|
pub fn ConvertedObject::private_bytes(self : ConvertedObject) -> Bytes {
  self.output
}

///|
pub fn ConvertedObject::public_decisions(self : ConvertedObject) -> Json {
  Json::array(self.decisions.map(fn(decision) { decision.to_json() }))
}
