///|
fn json_object(bytes : Bytes) -> Map[String, Json] raise @model.MedSealError {
  let text = @utf8.decode(bytes) catch {
    _ =>
      raise @model.MedSealError::OutputVerificationFailed(
        "invalid JSON encoding",
      )
  }
  let value = @json.parse(text) catch {
    _ => raise @model.MedSealError::OutputVerificationFailed("invalid JSON")
  }
  match value {
    Json::Object(fields) => fields
    _ =>
      raise @model.MedSealError::OutputVerificationFailed(
        "JSON object required",
      )
  }
}

///|
fn json_string(value : Json?) -> String raise @model.MedSealError {
  match value {
    Some(Json::String(text)) => text
    _ =>
      raise @model.MedSealError::OutputVerificationFailed(
        "missing string in manifest",
      )
  }
}

///|
pub async fn verify(input : String) -> String raise @model.MedSealError {
  if @storage.kind(input) != @async_fs.FileKind::Directory {
    raise @model.MedSealError::InvalidArgument(
      "job must be a directory, not a link",
    )
  }
  let root = @storage.canonical(input)
  let manifest = json_object(
    @storage.read(join(root, "manifest.json"), limit=4 * 1024 * 1024),
  )
  let profile = json_string(manifest.get("policy"))
  if manifest.get("version") != Some(Json::number(1.0)) ||
    manifest.get("status") != Some(Json::string("complete")) ||
    !["research-v1", "strict-v1"].contains(profile) ||
    manifest.get("pixels_inspected") != Some(Json::boolean(false)) {
    raise @model.MedSealError::OutputVerificationFailed(
      "unsupported or incomplete job manifest",
    )
  }
  if profile == "strict-v1" &&
    manifest.get("dictionary_sha256") !=
    Some(Json::string(@dictionary.strict_dictionary_digest)) {
    raise @model.MedSealError::OutputVerificationFailed(
      "strict dictionary version mismatch",
    )
  }
  let external = match manifest.get("allow_external_references") {
    Some(Json::True) => true
    Some(Json::False) => false
    _ =>
      raise @model.MedSealError::OutputVerificationFailed(
        "missing external reference mode",
      )
  }
  let entries = match manifest.get("objects") {
    Some(Json::Array(entries)) if !entries.is_empty() &&
      entries.length() <= 10000 => entries
    _ =>
      raise @model.MedSealError::OutputVerificationFailed("invalid object list")
  }
  let metadata : Array[@model.DataSet] = []
  let expected : Map[String, Bool] = Map::from_array([("manifest.json", true)])
  let mut total = 0
  for index, entry in entries {
    let fields = match entry {
      Json::Object(fields) => fields
      _ =>
        raise @model.MedSealError::OutputVerificationFailed(
          "invalid object entry",
        )
    }
    let id = "object-\{index + 1}"
    let filename = "\{id}.dcm"
    if json_string(fields.get("file")) != filename {
      raise @model.MedSealError::OutputVerificationFailed(
        "object filename is not canonical",
      )
    }
    let bytes = @storage.read(join(root, filename))
    if @checksum.sha256(bytes) != json_string(fields.get("sha256")) {
      raise @model.MedSealError::OutputVerificationFailed(
        "DICOM checksum mismatch",
      )
    }
    let audit_bytes = @storage.read(
      join(root, "\{id}.audit.json"),
      limit=16 * 1024 * 1024,
    )
    if @checksum.sha256(audit_bytes) != json_string(fields.get("audit_sha256")) {
      raise @model.MedSealError::OutputVerificationFailed(
        "audit checksum mismatch",
      )
    }
    let report = json_object(audit_bytes)
    if report.get("object") != Some(Json::string(id)) ||
      report.get("pixels_inspected") != Some(Json::boolean(false)) ||
      report.get("conversion") != Some(Json::string("verified")) {
      raise @model.MedSealError::OutputVerificationFailed(
        "audit identity or verification status mismatch",
      )
    }
    if report.get("policy") != manifest.get("policy") ||
      report.get("policy_sha256") != manifest.get("policy_sha256") {
      raise @model.MedSealError::OutputVerificationFailed(
        "audit and manifest policy differ",
      )
    }
    let parsed = @parser.parse(bytes)
    check_meta(parsed)
    if parsed.preamble != Bytes::make(128, b'\x00') ||
      !@verification.clean_private(parsed.dataset) ||
      @identity.text(parsed.dataset, @model.Tag::new(0x0012U, 0x0063U)) !=
      Some("MedSeal \{profile}; metadata subset; pixels unchecked") {
      raise @model.MedSealError::OutputVerificationFailed(
        "output header, method marker or private tag check failed",
      )
    }
    if profile == "strict-v1" {
      @conformance.check(
        parsed.dataset.remove(@model.Tag::new(0x0012U, 0x0063U)),
        full_pixels=true,
      )
    }
    for element in parsed.file_meta.elements {
      if ![0x0000U, 0x0001U, 0x0002U, 0x0003U, 0x0010U, 0x0012U, 0x0013U].contains(
          element.tag.element,
        ) {
        raise @model.MedSealError::OutputVerificationFailed(
          "unexpected File Meta element",
        )
      }
    }
    let stripped = @verification.metadata_only(parsed.dataset)
    total = total + metadata_size(stripped)
    if total > 64 * 1024 * 1024 {
      raise @model.MedSealError::OutputVerificationFailed(
        "job metadata exceeds index budget",
      )
    }
    metadata.push(stripped)
    expected.set(filename, true)
    expected.set("\{id}.audit.json", true)
  }
  for name in @storage.list(root) {
    if !expected.contains(name) {
      raise @model.MedSealError::OutputVerificationFailed(
        "unexpected file in published job",
      )
    }
  }
  let report = @verification.check(metadata, allow_external=external)
  if manifest.get("references") !=
    Some(Json::number(report.references.to_double())) ||
    manifest.get("external_references") !=
    Some(Json::number(report.external_references.to_double())) {
    raise @model.MedSealError::OutputVerificationFailed(
      "reference counts differ from manifest",
    )
  }
  Json::object(
    Map::from_array([
      ("status", Json::string("integrity-and-structure-verified")),
      ("release_authorized", Json::boolean(false)),
      ("objects", Json::number(report.objects.to_double())),
      ("references", Json::number(report.references.to_double())),
      (
        "external_references",
        Json::number(report.external_references.to_double()),
      ),
      ("pixels_inspected", Json::boolean(false)),
      (
        "remaining_risks",
        Json::array([
          Json::string("pixel-content-unchecked"),
          Json::string("public-metadata-subset-only"),
        ]),
      ),
    ]),
  ).stringify(indent=2)
}
