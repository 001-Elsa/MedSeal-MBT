///|
pub struct Scan {
  priv datasets : Array[@dicom.DataSet]
  priv quality : @quality.Report
  priv excluded : Int
}

///|
fn clone(dataset : @dicom.DataSet) -> @dicom.DataSet {
  @dicom.DataSet::new(
    dataset.elements.map(element => {
      let value = match element.value {
        @dicom.ElementValue::Sequence(items) =>
          @dicom.ElementValue::Sequence(items.map(clone))
        @dicom.ElementValue::UnsignedShort(v) =>
          @dicom.ElementValue::UnsignedShort(v.copy())
        @dicom.ElementValue::UnsignedLong(v) =>
          @dicom.ElementValue::UnsignedLong(v.copy())
        @dicom.ElementValue::SignedShort(v) =>
          @dicom.ElementValue::SignedShort(v.copy())
        @dicom.ElementValue::SignedLong(v) =>
          @dicom.ElementValue::SignedLong(v.copy())
        other => other
      }
      @dicom.DataElement::new(
        element.tag,
        element.vr,
        element.value_length,
        value,
        element.original_order,
      )
    }),
  )
}

///|
fn check_cancel(cancelled : (() -> Bool)?) -> Unit raise @model.MedSealError {
  if cancelled is Some(callback) && callback() {
    raise @model.InvalidArgument("operation cancelled before commit")
  }
}

///|
/// Native bounded metadata only: terminal finite pixels, max 2MiB metadata/file.
/// For metadata-only files <=2MiB use full parsing; never silently ignore errors.
pub async fn scan_directory(
  input : String,
  cancelled? : (() -> Bool)? = None,
) -> Scan raise @model.MedSealError {
  check_cancel(cancelled)
  if @storage.kind(input) != @async_fs.Directory {
    raise @model.InvalidArgument("input must be a regular directory")
  }
  let inventory = @inventory.discover(input)
  if inventory.candidates.is_empty() {
    raise @model.InvalidArgument("no candidate DICOM objects")
  }
  let datasets : Array[@dicom.DataSet] = []
  let mut total = 0
  let snapshots : Array[(Int64, (Int64, Int))] = []
  for path in inventory.candidates {
    check_cancel(cancelled)
    let before = @storage.snapshot(path)
    let parsed = read_metadata(path)
    let metadata = @verification.metadata_only(parsed.dataset)
    // Prefix bytes bound variable text/binary content; account for element/index overhead.
    let estimate = metadata_cost(metadata)
    if estimate > 64 * 1024 * 1024 - total {
      raise @model.InvalidArgument("scan metadata index exceeds 64MiB budget")
    }
    total = total + estimate
    if before != @storage.snapshot(path) {
      raise @model.IoError("input changed during metadata scanning")
    }
    snapshots.push(before)
    datasets.push(metadata)
  }
  check_cancel(cancelled)
  let final_inventory = @inventory.discover(input)
  if final_inventory.candidates != inventory.candidates ||
    final_inventory.excluded != inventory.excluded {
    raise @model.MedSealError::IoError("input file set changed during scanning")
  }
  for index, path in inventory.candidates {
    if @storage.snapshot(path) != snapshots[index] {
      raise @model.MedSealError::IoError("input changed before scan completion")
    }
  }
  {
    datasets,
    quality: @quality.check_datasets(datasets),
    excluded: inventory.excluded.length(),
  }
}

///|
pub fn Scan::private_datasets(self : Scan) -> Array[@dicom.DataSet] {
  self.datasets.map(clone)
}

///|
pub fn Scan::quality_report(self : Scan) -> @quality.Report {
  self.quality
}

///|
pub fn Scan::public_report(self : Scan) -> Json {
  Json::object(
    Map::from_array([
      ("schema", Json::string("medseal-scan-v1")),
      ("objects", Json::number(self.datasets.length().to_double())),
      ("excluded_non_dicom", Json::number(self.excluded.to_double())),
      ("scope", Json::string("metadata-only")),
      ("pixels_checked", Json::boolean(false)),
      ("quality", self.quality.public_json()),
      ("release_authorized", Json::boolean(false)),
    ]),
  )
}

///|
pub struct DatasetJob {
  priv job : @batch.Job
}

///|
/// Reuses bounded Native streaming, global identities and closed references.
/// Uses OS entropy and per-job offsets; no Python or persistent identity store.
pub async fn plan_directory(
  input : String,
  policy? : @public_policy.Policy = @public_policy.strict(),
  cancelled? : (() -> Bool)? = None,
) -> DatasetJob raise @model.MedSealError {
  check_cancel(cancelled)
  if !policy.strict_metadata || policy.allow_external_references {
    raise @model.PolicyError("Native SDK requires a strict closed policy")
  }
  let job = @batch.plan(input, policy, streamed=true, cancelled~)
  check_cancel(cancelled)
  { job, }
}

///|
pub fn DatasetJob::public_report(self : DatasetJob) -> Json {
  Json::object(
    Map::from_array([
      ("schema", Json::string("medseal-native-plan-v1")),
      ("objects", Json::number(self.job.report.objects.to_double())),
      ("references", Json::number(self.job.report.references.to_double())),
      ("release_authorized", Json::boolean(false)),
    ]),
  )
}

///|
/// Single-use, rechecks source bytes, stages privately, verifies all outputs then
/// commits a new directory. Cooperative cancellation at object/commit boundaries.
pub async fn DatasetJob::execute(
  self : DatasetJob,
  output : String,
  cancelled? : (() -> Bool)? = None,
) -> Unit raise @model.MedSealError {
  check_cancel(cancelled)
  ignore(
    self.job.execute(
      output,
      checkpoint=Some(fn(_event, _index) -> Unit raise @model.MedSealError {
        check_cancel(cancelled)
      }),
    ),
  )
}

///|
fn metadata_cost(dataset : @dicom.DataSet) -> Int {
  let mut total = 0
  for element in dataset.elements {
    total = total + 128
    match element.value {
      @dicom.ElementValue::Text(value) =>
        total = total + @utf8.encode(value).length() * 4
      @dicom.ElementValue::Sequence(items) =>
        for item in items {
          total = total + metadata_cost(item)
        }
      @dicom.ElementValue::UnsignedShort(v)
      | @dicom.ElementValue::UnsignedLong(v) => total = total + v.length() * 8
      @dicom.ElementValue::SignedShort(v)
      | @dicom.ElementValue::SignedLong(v) => total = total + v.length() * 8
      _ => ()
    }
  }
  total
}

///|
async fn read_metadata(
  path : String,
) -> @parser.ParsedFile raise @model.MedSealError {
  let size = @storage.snapshot(path).0
  // Small files are also bounded; large files must use the prefix index.
  let parsed = if size <= 2L * 1024L * 1024L {
    let parsed = @parser.parse(@storage.read(path, limit=2 * 1024 * 1024))
    {
      ..parsed,
      dataset: @verification.metadata_only(
        parsed.dataset.remove(@dicom.Tag::new(0x7FE0U, 0x0010U)),
      ),
    }
  } else {
    @streaming.inspect(path).parsed
  }
  @verification.check_file_meta(parsed)
  @verification.check_unique_tags(parsed.dataset)
  parsed
}

///|
/// Collect safe per-object failures. Never check successful subset relations.
pub async fn quality_directory(
  input : String,
  cancelled? : (() -> Bool)? = None,
) -> @quality.Report raise @model.MedSealError {
  check_cancel(cancelled)
  if @storage.kind(input) != @async_fs.FileKind::Directory {
    raise @model.MedSealError::InvalidArgument("input must be a directory")
  }
  let inventory = @inventory.discover(input)
  if inventory.candidates.is_empty() {
    raise @model.MedSealError::InvalidArgument("no candidate objects")
  }
  let datasets : Array[@dicom.DataSet] = []
  let failures : Array[(Int, @model.MedSealError)] = []
  let snapshots : Array[(Int64, (Int64, Int))] = []
  let mut total = 0
  for index, path in inventory.candidates {
    check_cancel(cancelled)
    let before = @storage.snapshot(path)
    snapshots.push(before)
    try {
      let metadata = @verification.metadata_only(read_metadata(path).dataset)
      let cost = metadata_cost(metadata)
      if cost > 64 * 1024 * 1024 - total {
        raise @model.MedSealError::InvalidArgument("quality index budget")
      }
      total = total + cost
      if before != @storage.snapshot(path) {
        raise @model.MedSealError::IoError("source changed during quality scan")
      }
      datasets.push(metadata)
    } catch {
      e => failures.push((index, e))
    }
  }
  check_cancel(cancelled)
  let current = @inventory.discover(input)
  if current.candidates != inventory.candidates ||
    current.excluded != inventory.excluded {
    raise @model.MedSealError::IoError("input set changed during quality scan")
  }
  for index, path in inventory.candidates {
    if @storage.snapshot(path) != snapshots[index] {
      raise @model.MedSealError::IoError(
        "input changed before quality completion",
      )
    }
  }
  if !failures.is_empty() {
    return @quality.from_errors(inventory.candidates.length(), failures)
  }
  @quality.check_datasets(datasets)
}
