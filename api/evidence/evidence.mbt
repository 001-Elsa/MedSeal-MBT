///|
/// A reference to the input records that contributed to one output record.
/// The library records provenance; it does not interpret or transform values.
pub(all) struct SourceRef {
  source : String
  record : String
  step : String
}

///|
/// One declared deterministic step in a caller-owned transformation.
pub(all) struct TransformationStep {
  id : String
  description : String
}

///|
/// The immutable declaration that a receipt is bound to.
pub(all) struct Plan {
  schema : String
  plan_id : String
  input_digest : String
  rule_digest : String
  tool_version : String
  steps : Array[TransformationStep]
}

///|
/// Provenance and change information for one output record.
pub(all) struct OutputRecord {
  id : String
  sources : Array[SourceRef]
  changed_fields : Array[String]
}

///|
/// A portable receipt for a completed transformation.
pub(all) struct Receipt {
  schema : String
  plan_id : String
  input_digest : String
  rule_digest : String
  output_digest : String
  tool_version : String
  input_records : Int
  output_records : Array[OutputRecord]
  dropped_records : Array[String]
  warnings : Array[String]
  status : String
}

///|
/// The result of checking a receipt against the files and plan available to a verifier.
pub(all) struct Verification {
  valid : Bool
  code : String
  message : String
}

///|
/// Calculate the digest used by a plan or receipt. This proves byte identity,
/// not privacy or business correctness.
pub fn sha256(bytes : Bytes) -> String {
  let digest = @sha256.Digest::new()
  for byte in bytes {
    digest.write(byte)
  }
  digest.check_sum()
}

///|
/// Construct a plan without embedding a data format or domain vocabulary.
pub fn Plan::new(
  plan_id~ : String,
  input_digest~ : String,
  rule_digest~ : String,
  tool_version~ : String,
  steps~ : Array[TransformationStep],
) -> Plan {
  {
    schema: "medseal-evidence-plan-v1",
    plan_id,
    input_digest,
    rule_digest,
    tool_version,
    steps: steps.copy(),
  }
}

///|
/// Construct a successful receipt. A caller must provide the digest of the actual output.
pub fn Receipt::new(
  plan : Plan,
  output_digest~ : String,
  input_records~ : Int,
  output_records~ : Array[OutputRecord],
  dropped_records? : Array[String] = [],
  warnings? : Array[String] = [],
) -> Receipt {
  {
    schema: "medseal-evidence-receipt-v1",
    plan_id: plan.plan_id,
    input_digest: plan.input_digest,
    rule_digest: plan.rule_digest,
    output_digest,
    tool_version: plan.tool_version,
    input_records,
    output_records: output_records.copy(),
    dropped_records: dropped_records.copy(),
    warnings: warnings.copy(),
    status: "completed",
  }
}

///|
/// Verify the binding and provenance shape without trusting producer-side metadata.
pub fn Receipt::verify(
  self : Receipt,
  plan : Plan,
  input_digest : String,
  output_digest : String,
) -> Verification {
  if self.schema != "medseal-evidence-receipt-v1" {
    return {
      valid: false,
      code: "SCHEMA",
      message: "unsupported receipt schema",
    }
  }
  if self.plan_id != plan.plan_id || self.rule_digest != plan.rule_digest {
    return {
      valid: false,
      code: "PLAN_MISMATCH",
      message: "receipt is bound to another plan",
    }
  }
  if self.input_digest != input_digest || plan.input_digest != input_digest {
    return {
      valid: false,
      code: "INPUT_CHANGED",
      message: "input digest does not match the plan",
    }
  }
  if self.output_digest != output_digest {
    return {
      valid: false,
      code: "OUTPUT_CHANGED",
      message: "output digest does not match the receipt",
    }
  }
  if self.input_records < 0 ||
    self.output_records.any(record => {
      record.id.is_empty() ||
      record.sources.is_empty() ||
      record.sources.any(source => !source_complete(source))
    }) {
    return {
      valid: false,
      code: "PROVENANCE",
      message: "record provenance is incomplete",
    }
  }
  { valid: true, code: "OK", message: "receipt and provenance are consistent", }
}

///|
/// Convert a receipt to an allowlisted JSON object for independent tooling.
fn source_json(source : SourceRef) -> Json {
  Json::object(
    Map::from_array([
      ("source", Json::string(source.source)),
      ("record", Json::string(source.record)),
      ("step", Json::string(source.step)),
    ]),
  )
}

///|
fn record_json(record : OutputRecord) -> Json {
  Json::object(
    Map::from_array([
      ("id", Json::string(record.id)),
      ("sources", Json::array(record.sources.map(source_json))),
      ("changed_fields", Json::array(record.changed_fields.map(Json::string))),
    ]),
  )
}

///|
fn source_complete(source : SourceRef) -> Bool {
  !source.source.is_empty() &&
  !source.record.is_empty() &&
  !source.step.is_empty()
}

///|
pub fn Receipt::to_json(self : Receipt) -> Json {
  Json::object(
    Map::from_array([
      ("schema", Json::string(self.schema)),
      ("plan_id", Json::string(self.plan_id)),
      ("input_digest", Json::string(self.input_digest)),
      ("rule_digest", Json::string(self.rule_digest)),
      ("output_digest", Json::string(self.output_digest)),
      ("tool_version", Json::string(self.tool_version)),
      ("input_records", Json::number(self.input_records.to_double())),
      ("output_records", Json::array(self.output_records.map(record_json))),
      ("dropped_records", Json::array(self.dropped_records.map(Json::string))),
      ("warnings", Json::array(self.warnings.map(Json::string))),
      ("status", Json::string(self.status)),
    ]),
  )
}

///|
pub fn Verification::to_json(self : Verification) -> Json {
  Json::object(
    Map::from_array([
      ("valid", Json::boolean(self.valid)),
      ("code", Json::string(self.code)),
      ("message", Json::string(self.message)),
    ]),
  )
}
