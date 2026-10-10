///|
pub struct CollectionReport {
  objects : Int
  references : Int
  external_references : Int
}

///|
fn key(dataset : @model.DataSet) -> String raise @model.MedSealError {
  let id = @identity.required_text(dataset, @model.Tag::new(0x0010U, 0x0020U))
  let issuer = @identity.text(dataset, @model.Tag::new(0x0010U, 0x0021U)).unwrap_or(
    "",
  )
  "\{issuer.length()}:\{issuer}\{id.length()}:\{id}"
}

///|
fn references(
  dataset : @model.DataSet,
  patient : String,
  instances : Map[String, (String, String)],
  allow_external : Bool,
  counts : Array[Int],
) -> Unit raise @model.MedSealError {
  match @identity.text(dataset, @model.Tag::new(0x0008U, 0x1155U)) {
    Some(value) => {
      if value.is_empty() || value.contains("\\") {
        raise @model.MedSealError::IdentityError(
          "SOP reference must be a single UID",
        )
      }
      let class_uid = @identity.required_text(
        dataset,
        @model.Tag::new(0x0008U, 0x1150U),
      )
      for uid in value.split("\\") {
        counts[0] = counts[0] + 1
        match instances.get(uid.to_owned()) {
          Some((owner, sop_class)) =>
            if owner != patient || sop_class != class_uid {
              raise @model.MedSealError::IdentityError(
                "reference points to a different patient or SOP Class",
              )
            }
          None if allow_external => counts[1] = counts[1] + 1
          None =>
            raise @model.MedSealError::IdentityError(
              "unresolved SOP reference in closed collection",
            )
        }
      }
    }
    None => ()
  }
  for element in dataset.elements {
    match element.value {
      @model.ElementValue::Sequence(items) =>
        for item in items {
          references(item, patient, instances, allow_external, counts)
        }
      _ => ()
    }
  }
}

///|
pub fn check(
  datasets : Array[@model.DataSet],
  allow_external? : Bool = false,
) -> CollectionReport raise @model.MedSealError {
  if datasets.is_empty() || datasets.length() > 10000 {
    raise @model.MedSealError::IdentityError(
      "collection must contain 1 to 10000 objects",
    )
  }
  let instances : Map[String, (String, String)] = Map([])
  let studies : Map[String, String] = Map([])
  let series : Map[String, (String, String)] = Map([])
  let frames : Map[String, String] = Map([])
  let roles : Map[String, String] = Map([])
  for dataset in datasets {
    if !@validator.validate_dataset(dataset).is_valid() {
      raise @model.MedSealError::IdentityError(
        "collection contains invalid metadata",
      )
    }
    let patient = key(dataset)
    let sop = @identity.required_text(
      dataset,
      @model.Tag::new(0x0008U, 0x0018U),
    )
    let sop_class = @identity.required_text(
      dataset,
      @model.Tag::new(0x0008U, 0x0016U),
    )
    if !@identity.supported_sop_class(sop_class) {
      raise @model.MedSealError::IdentityError("unsupported SOP Class")
    }
    if instances.contains(sop) {
      raise @model.MedSealError::IdentityError("duplicate SOP Instance UID")
    }
    instances.set(sop, (patient, sop_class))
    let study = @identity.required_text(
      dataset,
      @model.Tag::new(0x0020U, 0x000DU),
    )
    let serie = @identity.required_text(
      dataset,
      @model.Tag::new(0x0020U, 0x000EU),
    )
    match studies.get(study) {
      Some(owner) if owner != patient =>
        raise @model.MedSealError::IdentityError(
          "Study UID belongs to multiple patients",
        )
      _ => studies.set(study, patient)
    }
    match series.get(serie) {
      Some(owner) if owner != (patient, study) =>
        raise @model.MedSealError::IdentityError(
          "Series UID belongs to multiple studies or patients",
        )
      _ => series.set(serie, (patient, study))
    }
    let identity_roles : Array[(String, String)] = [
      (sop, "instance"),
      (study, "study"),
      (serie, "series"),
    ]
    match @identity.text(dataset, @model.Tag::new(0x0020U, 0x0052U)) {
      Some(frame) if !frame.is_empty() => {
        if frame.contains("\\") {
          raise @model.MedSealError::IdentityError(
            "Frame UID must be a single value",
          )
        }
        match frames.get(frame) {
          Some(owner) if owner != patient =>
            raise @model.MedSealError::IdentityError(
              "Frame UID belongs to multiple patients",
            )
          _ => frames.set(frame, patient)
        }
        identity_roles.push((frame, "frame"))
      }
      _ => ()
    }
    for (uid, role) in identity_roles {
      match roles.get(uid) {
        Some(old) if old != role =>
          raise @model.MedSealError::IdentityError(
            "UID used for incompatible identity roles",
          )
        _ => roles.set(uid, role)
      }
    }
  }
  let counts = [0, 0]
  for dataset in datasets {
    references(dataset, key(dataset), instances, allow_external, counts)
  }
  {
    objects: datasets.length(),
    references: counts[0],
    external_references: counts[1],
  }
}

///|
pub fn metadata_only(dataset : @model.DataSet) -> @model.DataSet {
  @model.DataSet::new(
    dataset.elements.map(fn(element) {
      match element.value {
        @model.ElementValue::Raw(_) =>
          @model.DataElement::new(
            element.tag,
            element.vr,
            0U,
            @model.ElementValue::Empty,
            element.original_order,
          )
        @model.ElementValue::Sequence(items) =>
          @model.DataElement::new(
            element.tag,
            element.vr,
            0U,
            @model.ElementValue::Sequence(items.map(metadata_only)),
            element.original_order,
          )
        _ => element
      }
    }),
  )
}
