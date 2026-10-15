///|
/// All outputs are owned by this result, in input order. No output is returned
/// unless the complete closed collection passes input and output validation.
pub struct ConvertedCollection {
  priv objects : Array[ConvertedObject]
  priv references : Int
}

///|
/// Portable, in-memory workflow. This is not a persistent identity store or a
/// release authorization. Supply fresh host-generated seed/offsets for a new
/// real job; fixed values are appropriate only for synthetic examples.
pub fn convert_collection(
  inputs : Array[Bytes],
  policy : @public_policy.Policy,
  uid_seed : String,
  date_offsets : Array[Int],
) -> ConvertedCollection raise @model.MedSealError {
  if !policy.strict_metadata || policy.allow_external_references {
    raise @model.MedSealError::PolicyError(
      "collection conversion requires a strict closed policy",
    )
  }
  if inputs.is_empty() || inputs.length() > 256 {
    raise @model.MedSealError::InvalidArgument("SDK collection count budget")
  }
  // Check before parsing or allocating datasets. The subtraction avoids an
  // overflowing sum even if a hostile caller supplies many huge buffers.
  let mut remaining = 128 * 1024 * 1024
  for input in inputs {
    if input.length() > 64 * 1024 * 1024 || input.length() > remaining {
      raise @model.MedSealError::InvalidArgument("SDK collection byte budget")
    }
    remaining = remaining - input.length()
  }
  let snapshots = inputs.map(validate)
  let datasets = snapshots.map(object => object.private_dataset())
  let before = @verification.check(datasets)
  let context = @identity.Context::new(uid_seed, policy, date_offsets)
  context.prepare(datasets)
  let objects = snapshots.map(object => convert(object, context))
  let after = @verification.check(
    objects.map(object => @parser.parse(object.private_bytes()).dataset),
  )
  if before.objects != after.objects || before.references != after.references {
    raise @model.MedSealError::OutputVerificationFailed(
      "SDK collection relation count changed",
    )
  }
  { objects, references: after.references, }
}

///|
pub fn ConvertedCollection::length(self : ConvertedCollection) -> Int {
  self.objects.length()
}

///|
/// Private DICOM bytes; never attach these to a public explanation report.
pub fn ConvertedCollection::private_bytes(
  self : ConvertedCollection,
  index : Int,
) -> Bytes raise @model.MedSealError {
  if index < 0 || index >= self.objects.length() {
    raise @model.MedSealError::InvalidArgument("SDK object index")
  }
  self.objects[index].private_bytes()
}

///|
/// Counts and reviewed decisions only; no seed, offsets, identifiers or values.
pub fn ConvertedCollection::public_report(self : ConvertedCollection) -> Json {
  Json::object(
    Map::from_array([
      ("schema", Json::number(1.0)),
      ("status", Json::string("collection-converted")),
      ("scope", Json::string("current-batch-only")),
      ("release_authorized", Json::boolean(false)),
      ("objects", Json::number(self.objects.length().to_double())),
      ("references", Json::number(self.references.to_double())),
      (
        "decisions",
        Json::array(self.objects.map(object => object.public_decisions())),
      ),
    ]),
  )
}
