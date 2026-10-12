///|
/// Canonical semantic model for public SYNTHETIC fixtures only.
pub fn normalized(dataset : @model.DataSet) -> Json {
  Json::array(
    dataset.canonical().elements.map(fn(element) {
      let value = match element.value {
        @model.Empty => Json::null()
        @model.Text(text) => Json::string(text)
        @model.UnsignedShort(values) | @model.UnsignedLong(values) =>
          Json::array(values.map(fn(n) { Json::number(n.to_double()) }))
        @model.SignedShort(values) | @model.SignedLong(values) =>
          Json::array(values.map(fn(n) { Json::number(n.to_double()) }))
        @model.Raw(bytes) =>
          Json::array([
            Json::string("raw"),
            Json::number(bytes.length().to_double()),
            Json::string(@checksum.sha256(bytes)),
          ])
        @model.Sequence(items) => Json::array(items.map(normalized))
      }
      Json::array([
        Json::string(element.tag.compact().replace(old=",", new="")),
        Json::string(element.vr.to_string()),
        value,
      ])
    }),
  )
}

///|
pub fn evaluate(
  bytes : Bytes,
  mode : String,
  tag? : String = "",
  configuration? : String = "",
) -> Json {
  try {
    if mode == "policy" {
      let policy = @policy.from_json(configuration)
      return Json::object(
        Map::from_array([
          ("status", Json::string("passed")),
          ("policy_sha256", Json::string(policy.digest())),
        ]),
      )
    }
    let parsed = @parser.parse(bytes)
    let before = normalized(parsed.dataset)
    let written = @dicom_writer.write_bytes(parsed)
    let reread = normalized(@parser.parse(written).dataset)
    if mode == "field" {
      let selected = @policy.parse_tag(tag)
      guard parsed.dataset.find(selected) is Some(element) else {
        raise @model.MedSealError::InvalidArgument("missing fixture field")
      }
      @conformance.check_attribute(element)
      return Json::object(
        Map::from_array([
          ("status", Json::string("passed")),
          ("before", before),
          ("roundtrip", reread),
        ]),
      )
    }
    let policy = if configuration.is_empty() {
      @policy.strict()
    } else {
      @policy.from_json(configuration)
    }
    let input = @validation.validate(bytes)
    let context = @identity.Context::new("12345", policy, [14])
    context.prepare([input.private_dataset()])
    let converted = @validation.convert(input, context)
    Json::object(
      Map::from_array([
        ("status", Json::string("passed")),
        ("before", before),
        ("roundtrip", reread),
        ("after", normalized(@parser.parse(converted.private_bytes()).dataset)),
        ("release_authorized", Json::boolean(false)),
      ]),
    )
  } catch {
    error => {
      let fields = Map::from_array([
        ("status", Json::string("blocked")),
        ("code", Json::string(error.code())),
      ])
      match error {
        @model.MedSealError::RuleViolation(rule, _, _, stage) => {
          fields.set("rule_id", Json::string(rule))
          fields.set("stage", Json::string(stage))
        }
        _ => ()
      }
      Json::object(fields)
    }
  }
}

///|
pub fn roundtrip_bytes(bytes : Bytes) -> Bytes raise @model.MedSealError {
  @dicom_writer.write_bytes(@parser.parse(bytes))
}

///|
pub fn converted_bytes(
  bytes : Bytes,
  configuration? : String = "",
) -> Bytes raise @model.MedSealError {
  let policy = if configuration.is_empty() {
    @policy.strict()
  } else {
    @policy.from_json(configuration)
  }
  let input = @validation.validate(bytes)
  let context = @identity.Context::new("12345", policy, [14])
  context.prepare([input.private_dataset()])
  @validation.convert(input, context).private_bytes()
}

///|
/// Closed collections use the actual owner/reference checker before and after.
pub fn evaluate_collection(inputs : Array[Bytes]) -> Json {
  try {
    let validated = inputs.map(@validation.validate)
    let datasets = validated.map(object => object.private_dataset())
    let before = @verification.check(datasets)
    let context = @identity.Context::new("12345", @policy.strict(), [14])
    context.prepare(datasets)
    let converted = validated.map(object => {
      @parser.parse(@validation.convert(object, context).private_bytes()).dataset
    })
    let after = @verification.check(converted)
    if before.objects != after.objects || before.references != after.references {
      raise @model.MedSealError::IdentityError("collection relation changed")
    }
    Json::object(
      Map::from_array([
        ("status", Json::string("passed")),
        ("objects", Json::number(after.objects.to_double())),
        ("references", Json::number(after.references.to_double())),
        (
          "external_references",
          Json::number(after.external_references.to_double()),
        ),
      ]),
    )
  } catch {
    error =>
      Json::object(
        Map::from_array([
          ("status", Json::string("blocked")),
          ("code", Json::string(error.code())),
        ]),
      )
  }
}
