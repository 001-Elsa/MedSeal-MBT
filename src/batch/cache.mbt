///|
fn cache_request(
  policy : @policy.Policy,
  program : String,
  objects : Array[Json],
) -> Json {
  Json::object(
    Map::from_array([
      ("schema", Json::number(1.0)),
      ("namespace", Json::string(policy.scope_name)),
      ("policy_sha256", Json::string(policy.digest())),
      ("rulebook_sha256", Json::string(@rulebook.digest)),
      ("program_sha256", Json::string(program)),
      ("objects", Json::array(objects)),
    ]),
  )
}

///|
async fn cached_result(
  artifact : @identity_store.CachedArtifact,
  context : @identity.Context,
  input : @model.DataSet,
  source : String,
  original : @parser.PixelSpan?,
) -> @identity.Result raise @model.MedSealError {
  if @storage.file_digest(artifact.file) != artifact.sha256 ||
    @storage.file_digest(artifact.audit_file) != artifact.audit_sha256 {
    raise @model.MedSealError::IdentityError(
      "cached payload fingerprint changed",
    )
  }
  let span = @streaming.inspect(artifact.file)
  let dataset = span.parsed.dataset
  @verification.check_file_meta(span.parsed)
  if @identity.required_text(dataset, @model.Tag::new(0x0008U, 0x0018U)) !=
    context.mapped_uid(
      @identity.required_text(input, @model.Tag::new(0x0008U, 0x0018U)),
    ) ||
    @identity.required_text(dataset, @model.Tag::new(0x0010U, 0x0020U)) !=
    context.patient(input) ||
    @identity.required_text(dataset, @model.Tag::new(0x0008U, 0x0016U)) !=
    @identity.required_text(input, @model.Tag::new(0x0008U, 0x0016U)) ||
    !@verification.clean_private(dataset) {
    raise @model.MedSealError::IdentityError(
      "cached identity or profile changed",
    )
  }
  guard original is Some(original) else {
    raise @model.MedSealError::IdentityError("cache requires source pixel span")
  }
  if original.length != span.length ||
    original.vr != span.vr ||
    @storage.stream_range(source, original.offset, original.length) !=
    @storage.stream_range(artifact.file, span.offset, span.length) {
    raise @model.MedSealError::IdentityError(
      "cached pixels differ from sealed source",
    )
  }
  let audit_bytes = @storage.read(artifact.audit_file, limit=16 * 1024 * 1024)
  let audit = @utf8.decode(audit_bytes) catch {
    _ =>
      raise @model.MedSealError::IdentityError("invalid cached audit encoding")
  }
  context.restore_cached(dataset, audit)
}

///|
async fn copy_cached(
  artifact : @identity_store.CachedArtifact,
  output : String,
  resumable : Bool,
) -> String raise @model.MedSealError {
  if resumable && @storage.exists(output) {
    if @storage.file_digest(output) == artifact.sha256 {
      return artifact.sha256
    }
    @async_fs.remove(output) catch {
      _ =>
        raise @model.MedSealError::IoError(
          "could not discard owned partial cache copy",
        )
    }
  }
  let size = @storage.snapshot(artifact.file).0
  let actual = @storage.stream_range(
    artifact.file,
    0,
    size.to_int(),
    output=Some(output),
  )
  if actual != artifact.sha256 ||
    @storage.file_digest(output) != artifact.sha256 {
    raise @model.MedSealError::IdentityError("cached copy failed verification")
  }
  actual
}
