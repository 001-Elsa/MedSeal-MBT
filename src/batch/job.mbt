///|
pub struct Job {
  priv root : String
  priv paths : Array[String]
  priv snapshots : Array[(Int64, (Int64, Int))]
  priv hashes : Array[String]
  priv metadata : Array[@model.DataSet]
  priv context : @identity.Context
  priv policy : @policy.Policy
  priv mut consumed : Bool
  report : @verification.CollectionReport
}

///|
fn join(parent : String, name : String) -> String {
  @path.Path(parent).join(@path.Path(name)).0
}

///|
async fn scan(
  root : String,
  paths : Array[String],
  depth : Int,
) -> Unit raise @model.MedSealError {
  if depth > 16 {
    raise @model.MedSealError::InvalidArgument("directory nesting exceeds 16")
  }
  for name in @storage.list(root) {
    let path = join(root, name)
    match @storage.kind(path) {
      @async_fs.FileKind::SymLink =>
        raise @model.MedSealError::InvalidArgument(
          "symbolic links in input directory are rejected",
        )
      @async_fs.FileKind::Directory => scan(path, paths, depth + 1)
      @async_fs.FileKind::Regular if name.to_lower().has_suffix(".dcm") => {
        paths.push(path)
        if paths.length() > 10000 {
          raise @model.MedSealError::InvalidArgument("job exceeds 10000 files")
        }
      }
      @async_fs.FileKind::Regular => ()
      _ =>
        raise @model.MedSealError::InvalidArgument(
          "non-regular input directory entry",
        )
    }
  }
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
) -> Job raise @model.MedSealError {
  if @storage.kind(input) != @async_fs.FileKind::Directory {
    raise @model.MedSealError::InvalidArgument(
      "input must be a directory, not a link",
    )
  }
  let root = @storage.canonical(input)
  let paths : Array[String] = []
  scan(root, paths, 0)
  paths.sort()
  let metadata : Array[@model.DataSet] = []
  let snapshots : Array[(Int64, (Int64, Int))] = []
  let hashes : Array[String] = []
  let offsets : Array[Int] = []
  let mut total = 0
  for path in paths {
    let before = @storage.snapshot(path)
    let bytes = @storage.read(path)
    let parsed = @parser.parse(bytes)
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
  // Run transformations during dry-run as well, so incompatible dates, VRs and
  // rule applications fail before any output directory is created.
  for dataset in metadata {
    ignore(context.apply(dataset))
  }
  {
    root,
    paths,
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
fn audit(id : String, result : @identity.Result) -> String {
  Json::object(
    Map::from_array([
      ("object", Json::string(id)),
      ("policy", Json::string("research-v1")),
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
) -> String raise @model.MedSealError {
  if self.consumed {
    raise @model.MedSealError::InvalidArgument(
      "planned job is single-use; re-plan after any attempt",
    )
  }
  self.consumed = true
  let current : Array[String] = []
  scan(self.root, current, 0)
  current.sort()
  if current != self.paths {
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
  let stage = "\{output}.medseal-\{@storage.token()}"
  @storage.mkdir(stage)
  defer (@async_fs.rmdir(stage, recursive=true) catch { _ => () })
  let outputs : Array[@model.DataSet] = []
  let objects : Array[Json] = []
  for index, path in self.paths {
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
    @storage.write_new(path, bytes)
    let reparsed = @parser.parse(@storage.read(path))
    check_meta(reparsed)
    if !@verification.same_values(result.dataset, reparsed.dataset) ||
      !@verification.clean_private(reparsed.dataset) {
      raise @model.MedSealError::OutputVerificationFailed(
        "retained values or output policy changed during serialization",
      )
    }
    outputs.push(@verification.metadata_only(reparsed.dataset))
    let audit_bytes = @utf8.encode(audit(id, result))
    if audit_bytes.length() > 16 * 1024 * 1024 {
      raise @model.MedSealError::OutputVerificationFailed(
        "audit report exceeds 16 MiB limit",
      )
    }
    @storage.write_new(join(stage, "\{id}.audit.json"), audit_bytes)
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
  let manifest = Json::object(
    Map::from_array([
      ("version", Json::number(1.0)),
      ("tool_version", Json::string(@model.medseal_version)),
      ("status", Json::string("complete")),
      ("policy", Json::string("research-v1")),
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
  @storage.write_new(join(stage, "manifest.json"), @utf8.encode(manifest))
  let final_paths : Array[String] = []
  scan(self.root, final_paths, 0)
  final_paths.sort()
  if final_paths != self.paths {
    raise @model.MedSealError::IoError(
      "input file set changed during execution",
    )
  }
  for index, path in self.paths {
    if @storage.snapshot(path) != self.snapshots[index] {
      raise @model.MedSealError::IoError("input changed during execution")
    }
  }
  // No overwrite; the sibling staging directory keeps the rename on one FS.
  @storage.publish(stage, output)
  manifest
}

///|
pub async fn run(
  input : String,
  output : String,
  policy : @policy.Policy,
) -> String raise @model.MedSealError {
  let job = plan(input, policy)
  job.execute(output)
}
