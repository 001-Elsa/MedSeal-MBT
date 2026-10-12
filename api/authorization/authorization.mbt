///|
pub struct Verifier {
  priv python : String
  priv adapter : String
  priv python_sha256 : String
  priv files : Array[(String, String)]
}

///|
pub struct ReviewEvidence {
  sha256 : String
  objects : Int
  context : String
}

///|
pub struct AuthorizedPackage {
  sha256 : String
  objects : Int
  context : String
}

///|
pub(all) enum AcceptanceContext {
  Controlled
  SyntheticTest
}

///|
/// Trusted administrator pins the audited adapter and its Python modules.
/// This is a trust configuration, not an untrusted application parameter.
pub async fn Verifier::new(
  python : String,
  adapter : String,
  files : Array[(String, String)],
) -> Verifier raise @model.MedSealError {
  let python = @storage.canonical(python)
  let suffix = "/api_authorization.py"
  if !adapter.has_suffix(suffix) {
    raise @model.MedSealError::InvalidArgument("trusted adapter name")
  }
  let root = adapter[0:adapter.length() - suffix.length()].to_owned()
  let names = [
    "api_authorization.py", "enterprise_job.py", "risk_gate.py", "verify_delivery.py",
    "private_store.py", "ledger_cache.py", "history_outbox.py", "local_fs.py",
  ]
  if files.length() != names.length() ||
    !names.all(fn(name) {
      files.filter(fn(pair) { pair.0 == root + "/" + name }).length() == 1
    }) {
    raise @model.MedSealError::InvalidArgument(
      "pin adapter and its complete runtime closure",
    )
  }
  let result : Verifier = {
    python,
    adapter,
    python_sha256: @storage.file_digest(python),
    files: files.copy(),
  }
  result.check()
  result
}

///|
async fn Verifier::check(self : Verifier) -> Unit raise @model.MedSealError {
  if @storage.file_digest(self.python) != self.python_sha256 {
    raise @model.MedSealError::OutputVerificationFailed(
      "trusted Python runtime changed",
    )
  }
  for (path, checksum) in self.files {
    if @storage.file_digest(path) != checksum {
      raise @model.MedSealError::OutputVerificationFailed(
        "trusted evidence adapter changed",
      )
    }
  }
}

///|
async fn Verifier::verify(
  self : Verifier,
  operation : String,
  root : String,
  identity : String,
  trust : String,
) -> (String, Int, String) raise @model.MedSealError {
  self.check()
  let response = @async.with_timeout(30000, async fn() {
    let (code, output, _) = @process.collect_output(
      self.python,
      [self.adapter, operation, root, identity, trust],
      inherit_env=false,
    )
    if code != 0 {
      raise @model.MedSealError::OutputVerificationFailed(
        "fresh evidence revalidation failed",
      )
    }
    output.text()
  }) catch {
    _ =>
      raise @model.MedSealError::OutputVerificationFailed(
        "evidence service failed",
      )
  }
  self.check()
  if response.length() > 4096 {
    raise @model.MedSealError::OutputVerificationFailed(
      "evidence response budget",
    )
  }
  let json = @json.parse(response) catch {
    _ =>
      raise @model.MedSealError::OutputVerificationFailed(
        "invalid evidence response",
      )
  }
  match json {
    Json::Object(fields) if fields.length() == 5 &&
      fields.get("schema") == Some(Json::number(1.0)) &&
      fields.get("kind") == Some(Json::string(operation)) =>
      match
        (fields.get("sha256"), fields.get("objects"), fields.get("context")) {
        (
          Some(Json::String(hash)),
          Some(Json::Number(count, ..)),
          Some(Json::String(context)),
        ) if hash.length() == 64 &&
          hash.all(fn(c) { (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') }) &&
          count >= 1.0 &&
          count <= 10000.0 &&
          count.to_int().to_double() == count &&
          ["controlled", "synthetic"].contains(context) =>
          (hash, count.to_int(), context)
        _ =>
          raise @model.MedSealError::OutputVerificationFailed(
            "invalid evidence bindings",
          )
      }
    _ =>
      raise @model.MedSealError::OutputVerificationFailed(
        "invalid evidence schema",
      )
  }
}

///|
pub async fn Verifier::review(
  self : Verifier,
  workspace : String,
  job : String,
  registry : String,
) -> ReviewEvidence raise @model.MedSealError {
  let (sha256, objects, context) = self.verify(
    "review", workspace, job, registry,
  )
  { sha256, objects, context, }
}

///|
pub async fn Verifier::authorized_package(
  self : Verifier,
  root : String,
  trust : String,
  acceptance? : AcceptanceContext = Controlled,
) -> AuthorizedPackage raise @model.MedSealError {
  let (sha256, objects, context) = self.verify(
    "package",
    root,
    match acceptance {
      Controlled => "controlled"
      SyntheticTest => "synthetic-test"
    },
    trust,
  )
  { sha256, objects, context, }
}
