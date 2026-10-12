///|
pub struct Job {
  priv root : String
  priv paths : Array[String]
  priv inventory : @inventory.Inventory
  priv snapshots : Array[(Int64, (Int64, Int))]
  priv hashes : Array[String]
  priv metadata : Array[@model.DataSet]
  priv context : @identity.Context
  priv policy : @policy.Policy
  priv mut consumed : Bool
  report : @verification.CollectionReport
}

///|
/// Caller owns this private stage exclusively; owner token must match its marker.
pub(all) struct ResumeStage {
  path : String
  token : String
}

///|
async fn checkpoint_file(
  path : String,
  bytes : Bytes,
) -> Unit raise @model.MedSealError {
  if @storage.exists(path) {
    // Recompute expected bytes; file existence alone is not a checkpoint.
    if @storage.read(path) == bytes {
      return
    }
    @async_fs.remove(path) catch {
      _ =>
        raise @model.MedSealError::IoError(
          "could not discard owned incomplete checkpoint",
        )
    }
  }
  @storage.write_new(path, bytes)
}

///|
fn join(parent : String, name : String) -> String {
  @path.Path(parent).join(@path.Path(name)).0
}

///|
fn metadata_size(dataset : @model.DataSet) -> Int {
  let mut total = 0
  for element in dataset.elements {
    total = total + 32
    match element.value {
      @model.ElementValue::Text(value) =>
        total = total + @utf8.encode(value).length()
      @model.ElementValue::Sequence(items) =>
        for item in items {
          total = total + metadata_size(item)
        }
      _ => ()
    }
  }
  total
}

///|
fn check_meta(parsed : @parser.ParsedFile) -> Unit raise @model.MedSealError {
  for
    (tag, meta_tag) in [
      (@model.Tag::new(0x0008U, 0x0016U), @model.Tag::new(0x0002U, 0x0002U)),
      (@model.Tag::new(0x0008U, 0x0018U), @model.Tag::new(0x0002U, 0x0003U)),
    ] {
    if @identity.required_text(parsed.dataset, tag) !=
      @identity.required_text(parsed.file_meta, meta_tag) {
      raise @model.MedSealError::IdentityError(
        "File Meta SOP identity differs from dataset",
      )
    }
  }
  @verification.check_unique_tags(parsed.dataset)
  @verification.check_unique_tags(parsed.file_meta)
}

///|
pub async fn plan(
  input : String,
  policy : @policy.Policy,
  provider? : @identity_store.Provider? = None,
) -> Job raise @model.MedSealError {
  if @storage.kind(input) != @async_fs.FileKind::Directory {
    raise @model.MedSealError::InvalidArgument(
      "input must be a directory, not a link",
    )
  }
  let root = @storage.canonical(input)
  let inventory = @inventory.discover(root)
  let paths = inventory.candidates
  let metadata : Array[@model.DataSet] = []
  let snapshots : Array[(Int64, (Int64, Int))] = []
  let hashes : Array[String] = []
  let offsets : Array[Int] = []
  let mut total = 0
  for path in paths {
    let before = @storage.snapshot(path)
    let bytes = @storage.read(path)
    let parsed = @parser.parse(bytes)
    if policy.strict_metadata {
      @conformance.check(parsed.dataset, full_pixels=true)
    }
    check_meta(parsed)
    let after = @storage.snapshot(path)
    if before != after {
      raise @model.MedSealError::IoError("input changed during planning")
    }
    let stripped = @verification.metadata_only(parsed.dataset)
    let size = metadata_size(stripped)
    if size > 2 * 1024 * 1024 || total + size > 64 * 1024 * 1024 {
      raise @model.MedSealError::InvalidArgument(
        "job metadata exceeds bounded index budget",
      )
    }
    total = total + size
    metadata.push(stripped)
    snapshots.push(after)
    hashes.push(@checksum.sha256(bytes))
    offsets.push(@storage.date_offset(policy.date_shift_days))
  }
  let report = @verification.check(
    metadata,
    allow_external=policy.allow_external_references,
  )
  let context = @identity.Context::new(@storage.token(size=12), policy, offsets)
  context.prepare(metadata)
  if provider is Some(provider) {
    context.load_bindings(
      provider.reserve(context.binding_request(metadata, hashes)),
    )
  }
  // Run transformations during dry-run as well, so incompatible dates, VRs and
  // rule applications fail before any output directory is created.
  for dataset in metadata {
    ignore(context.apply(dataset))
  }
  {
    root,
    paths,
    inventory,
    snapshots,
    hashes,
    metadata,
    context,
    policy,
    consumed: false,
    report,
  }
}

///|
pub fn Job::preview(self : Job) -> String {
  Json::object(
    Map::from_array([
      ("status", Json::string("planned")),
      ("inventory", self.inventory.summary()),
      ("release_authorized", Json::boolean(false)),
      ("objects", Json::number(self.report.objects.to_double())),
      ("references", Json::number(self.report.references.to_double())),
      (
        "external_references",
        Json::number(self.report.external_references.to_double()),
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

///|
fn event_json(event : @identity.Event) -> Json {
  Json::object(
    Map::from_array([
      ("path", Json::string(event.path)),
      ("rule", Json::string(event.rule)),
      ("action", Json::string(event.action)),
    ]),
  )
}

///|
fn audit(
  id : String,
  result : @identity.Result,
  policy : @policy.Policy,
) -> String {
  Json::object(
    Map::from_array([
      ("object", Json::string(id)),
      ("policy", Json::string(policy.name())),
      ("policy_sha256", Json::string(policy.digest())),
      ("conversion", Json::string("verified")),
      ("pixel_bytes_preserved", Json::boolean(true)),
      ("pixels_inspected", Json::boolean(false)),
      ("events", Json::array(result.events.map(event_json))),
    ]),
  ).stringify(indent=2)
}

///|
fn nested(left : String, right : String) -> Bool {
  let a = if @path.sep == '\\' { left.to_lower() } else { left }
  let b = if @path.sep == '\\' { right.to_lower() } else { right }
  a == b || a.has_prefix("\{b}\{@path.sep}") || b.has_prefix("\{a}\{@path.sep}")
}

///|
pub async fn Job::execute(
  self : Job,
  output : String,
  faults? : @storage.Faults? = None,
  checkpoint? : (async (String, Int) -> Unit raise @model.MedSealError)? = None,
  resume_stage? : ResumeStage? = None,
) -> String raise @model.MedSealError {
  if self.consumed {
    raise @model.MedSealError::InvalidArgument(
      "planned job is single-use; re-plan after any attempt",
    )
  }
  self.consumed = true
  let current = @inventory.discover(self.root)
  if current.candidates != self.paths ||
    current.excluded != self.inventory.excluded {
    raise @model.MedSealError::IoError("input file set changed after planning")
  }
  let output = @storage.output_path(output)
  if nested(self.root, output) {
    raise @model.MedSealError::InvalidArgument(
      "input and output directories must not be nested",
    )
  }
  if @storage.exists(output) {
    raise @model.MedSealError::InvalidArgument(
      "job output must be a new directory",
    )
  }
  let stage = match resume_stage {
    Some(owned) => {
      if owned.token.is_empty() ||
        owned.token.length() > 128 ||
        @storage.kind(owned.path) != @async_fs.FileKind::Directory {
        raise @model.MedSealError::InvalidArgument(
          "invalid private resume stage",
        )
      }
      let stage = @storage.canonical(owned.path)
      if nested(self.root, stage) ||
        stage == output ||
        @storage.read(join(stage + ".checkpoints", "owner"), limit=128) !=
        @utf8.encode(owned.token) {
        raise @model.MedSealError::InvalidArgument(
          "resume stage ownership mismatch",
        )
      }
      stage
    }
    None => {
      let stage = "\{output}.medseal-\{@storage.token()}"
      @storage.mkdir(stage)
      stage
    }
  }
  defer (if resume_stage is None {
    @async_fs.rmdir(stage, recursive=true) catch {
      _ => ()
    }
  })
  if checkpoint is Some(callback) {
    callback("stage-created", 0)
  }
  let outputs : Array[@model.DataSet] = []
  let objects : Array[Json] = []
  for index, path in self.paths {
    if checkpoint is Some(callback) {
      callback("before-object", index)
    }
    if @storage.snapshot(path) != self.snapshots[index] {
      raise @model.MedSealError::IoError("input changed after planning")
    }
    let source = @storage.read(path)
    if @checksum.sha256(source) != self.hashes[index] {
      raise @model.MedSealError::IoError("input bytes changed after planning")
    }
    let parsed = @parser.parse(source)
    check_meta(parsed)
    if !@verification.same_values(
        @verification.metadata_only(parsed.dataset),
        self.metadata[index],
      ) {
      raise @model.MedSealError::IoError(
        "input metadata changed after planning",
      )
    }
    let result = self.context.apply(parsed.dataset)
    let bytes = @dicom_writer.write_deidentified(parsed, result.dataset)
    let id = "object-\{index + 1}"
    let path = join(stage, "\{id}.dcm")
    if resume_stage is Some(_) {
      checkpoint_file(path, bytes)
    } else {
      @storage.write_new(path, bytes, faults~)
    }
    let reparsed = @parser.parse(@storage.read(path))
    check_meta(reparsed)
    if !@verification.same_values(result.dataset, reparsed.dataset) ||
      !@verification.clean_private(reparsed.dataset) {
      raise @model.MedSealError::OutputVerificationFailed(
        "retained values or output policy changed during serialization",
      )
    }
    outputs.push(@verification.metadata_only(reparsed.dataset))
    if self.policy.strict_metadata {
      @conformance.check(
        reparsed.dataset.remove(@model.Tag::new(0x0012U, 0x0063U)),
        full_pixels=true,
      )
    }
    let audit_bytes = @utf8.encode(audit(id, result, self.policy))
    if audit_bytes.length() > 16 * 1024 * 1024 {
      raise @model.MedSealError::OutputVerificationFailed(
        "audit report exceeds 16 MiB limit",
      )
    }
    if resume_stage is Some(_) {
      checkpoint_file(join(stage, "\{id}.audit.json"), audit_bytes)
      checkpoint_file(
        join(stage + ".checkpoints", "\{id}.checkpoint.json"),
        @utf8.encode(
          Json::object(
            Map::from_array([
              ("object", Json::string(id)),
              ("sha256", Json::string(@checksum.sha256(bytes))),
              ("audit_sha256", Json::string(@checksum.sha256(audit_bytes))),
              ("policy_sha256", Json::string(self.policy.digest())),
            ]),
          ).stringify(),
        ),
      )
    } else {
      @storage.write_new(join(stage, "\{id}.audit.json"), audit_bytes, faults~)
    }
    if checkpoint is Some(callback) {
      callback("object-verified", index)
    }
    objects.push(
      Json::object(
        Map::from_array([
          ("file", Json::string("\{id}.dcm")),
          ("sha256", Json::string(@checksum.sha256(bytes))),
          ("audit_sha256", Json::string(@checksum.sha256(audit_bytes))),
        ]),
      ),
    )
  }
  let report = @verification.check(
    outputs,
    allow_external=self.policy.allow_external_references,
  )
  if checkpoint is Some(callback) {
    callback("before-manifest", self.paths.length())
  }
  let manifest = Json::object(
    Map::from_array([
      ("version", Json::number(1.0)),
      ("tool_version", Json::string(@model.medseal_version)),
      ("status", Json::string("complete")),
      ("conversion_status", Json::string("metadata-subset-transformed")),
      ("integrity_status", Json::string("verified")),
      ("release_authorized", Json::boolean(false)),
      ("inventory", self.inventory.summary()),
      ("policy", Json::string(self.policy.name())),
      ("policy_sha256", Json::string(self.policy.digest())),
      ("dictionary_sha256", Json::string(@dictionary.strict_dictionary_digest)),
      (
        "allow_external_references",
        Json::boolean(self.policy.allow_external_references),
      ),
      ("references", Json::number(report.references.to_double())),
      (
        "external_references",
        Json::number(report.external_references.to_double()),
      ),
      ("objects", Json::array(objects)),
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
  if resume_stage is Some(_) {
    checkpoint_file(join(stage, "manifest.json"), @utf8.encode(manifest))
  } else {
    @storage.write_new(
      join(stage, "manifest.json"),
      @utf8.encode(manifest),
      faults~,
    )
  }
  if checkpoint is Some(callback) {
    callback("before-publication", self.paths.length())
  }
  let final_inventory = @inventory.discover(self.root)
  if final_inventory.candidates != self.paths ||
    final_inventory.excluded != self.inventory.excluded {
    raise @model.MedSealError::IoError(
      "input file set changed during execution",
    )
  }
  for index, path in self.paths {
    if @storage.snapshot(path) != self.snapshots[index] ||
      @checksum.sha256(@storage.read(path)) != self.hashes[index] {
      raise @model.MedSealError::IoError("input changed during execution")
    }
  }
  // No overwrite; the sibling staging directory keeps the rename on one FS.
  @storage.publish(stage, output, faults~)
  manifest
}

///|
pub async fn run(
  input : String,
  output : String,
  policy : @policy.Policy,
  provider? : @identity_store.Provider? = None,
) -> String raise @model.MedSealError {
  let job = plan(input, policy, provider~)
  job.execute(output)
}
