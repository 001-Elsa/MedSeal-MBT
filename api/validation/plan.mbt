///|
/// Lowerable buffered limits. Hard ceilings preserve the original SDK contract.
pub struct Budget {
  max_objects : Int
  max_file_bytes : Int
  max_total_bytes : Int
}

///|
pub fn Budget::new(
  max_objects? : Int = 256,
  max_file_bytes? : Int = 64 * 1024 * 1024,
  max_total_bytes? : Int = 128 * 1024 * 1024,
) -> Budget raise @model.MedSealError {
  if max_objects < 1 ||
    max_objects > 256 ||
    max_file_bytes < 132 ||
    max_file_bytes > 64 * 1024 * 1024 ||
    max_total_bytes < max_file_bytes ||
    max_total_bytes > 128 * 1024 * 1024 {
    raise @model.InvalidArgument("invalid bounded SDK configuration")
  }
  { max_objects, max_file_bytes, max_total_bytes, }
}

///|
pub struct ConversionOptions {
  priv policy : @public_policy.Policy
  priv seed : String
  priv offsets : Array[Int]
  priv budget : Budget
  priv patient_keys : Array[String]?
}

///|
/// Offsets follow the existing sorted patient-key contract; copied at construction.
pub fn ConversionOptions::new(
  policy~ : @public_policy.Policy,
  uid_seed~ : String,
  date_offsets~ : Array[Int],
  budget? : Budget = Budget::new(),
) -> ConversionOptions raise @model.MedSealError {
  if !policy.strict_metadata || policy.allow_external_references {
    raise @model.PolicyError("a closed strict policy is required")
  }
  ignore(@identity.Context::new(uid_seed, policy, date_offsets))
  {
    policy,
    seed: uid_seed,
    offsets: date_offsets.copy(),
    budget,
    patient_keys: None,
  }
}

///|
pub struct ConversionPlan {
  priv inputs : Array[Bytes]
  priv options : ConversionOptions
  priv references : Int
  priv patients : Int
}

///|
/// Holds immutable byte snapshots. No output or identity values in public preview.
pub fn plan_collection(
  inputs : Array[Bytes],
  options : ConversionOptions,
) -> ConversionPlan raise @model.MedSealError {
  if inputs.is_empty() || inputs.length() > options.budget.max_objects {
    raise @model.InvalidArgument("SDK plan object budget exceeded")
  }
  let mut remaining = options.budget.max_total_bytes
  for input in inputs {
    if input.length() > options.budget.max_file_bytes ||
      input.length() > remaining {
      raise @model.InvalidArgument("SDK plan byte budget exceeded")
    }
    remaining = remaining - input.length()
  }
  let datasets = inputs.map(bytes => validate(bytes).private_dataset())
  if options.patient_keys is Some(expected) {
    let keys : Map[String, Bool] = Map([])
    for dataset in datasets {
      let id = @identity.required_text(
        dataset,
        @model.Tag::new(0x0010U, 0x0020U),
      )
      let issuer = @identity.text(dataset, @model.Tag::new(0x0010U, 0x0021U)).unwrap_or(
        "",
      )
      keys.set(binding_key(options.policy.scope_name, issuer, id), true)
    }
    let actual = keys.keys().to_array()
    actual.sort()
    if actual != expected {
      raise @model.MedSealError::IdentityError(
        "patient-date bindings must exactly cover source identities",
      )
    }
  }
  let report = @verification.check(datasets)
  let context = @identity.Context::new(
    options.seed,
    options.policy,
    options.offsets,
  )
  context.prepare(datasets)
  let patients : Map[String, Bool] = Map([])
  for dataset in datasets {
    patients.set(context.patient(dataset), true)
  }
  {
    inputs: inputs.copy(),
    options,
    references: report.references,
    patients: patients.length(),
  }
}

///|
pub fn ConversionPlan::public_report(self : ConversionPlan) -> Json {
  Json::object(
    Map::from_array([
      ("schema", Json::string("medseal-plan-v1")),
      ("objects", Json::number(self.inputs.length().to_double())),
      ("patients", Json::number(self.patients.to_double())),
      ("references", Json::number(self.references.to_double())),
      ("status", Json::string("ready-for-conversion")),
      ("release_authorized", Json::boolean(false)),
    ]),
  )
}

///|
/// Revalidates the complete closed collection before returning any result.
pub fn ConversionPlan::execute(
  self : ConversionPlan,
) -> ConvertedCollection raise @model.MedSealError {
  convert_collection(
    self.inputs,
    self.options.policy,
    self.options.seed,
    self.options.offsets,
  )
}

///|
pub(all) struct PatientOffset {
  patient_id : String
  issuer : String
  days : Int
}

///|
fn binding_key(scope : String, issuer : String, id : String) -> String {
  "\{scope.length()}:\{scope}\{issuer.length()}:\{issuer}\{id.length()}:\{id}"
}

///|
/// Bind each date offset to a named private identity; order-independent and exact.
pub fn ConversionOptions::for_patients(
  policy~ : @public_policy.Policy,
  uid_seed~ : String,
  patients~ : Array[PatientOffset],
  budget? : Budget = Budget::new(),
) -> ConversionOptions raise @model.MedSealError {
  if patients.is_empty() || patients.length() > budget.max_objects {
    raise @model.MedSealError::InvalidArgument("invalid patient binding count")
  }
  let offsets : Map[String, Int] = Map([])
  for patient in patients {
    if patient.patient_id.is_empty() ||
      patient.patient_id.contains("\\") ||
      patient.issuer.contains("\\") {
      raise @model.MedSealError::IdentityError(
        "invalid patient binding identity",
      )
    }
    let key = binding_key(policy.scope_name, patient.issuer, patient.patient_id)
    if offsets.contains(key) {
      raise @model.MedSealError::IdentityError("duplicate patient-date binding")
    }
    offsets.set(key, patient.days)
  }
  let keys = offsets.keys().to_array()
  keys.sort()
  let options = ConversionOptions::new(
    policy~,
    uid_seed~,
    date_offsets=keys.map(key => offsets.get(key).unwrap()),
    budget~,
  )
  { ..options, patient_keys: Some(keys), }
}
