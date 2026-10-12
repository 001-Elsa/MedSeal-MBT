///|
pub(all) struct Provider {
  python : String
  adapter : String
  store : String
  source_domain : String
}

///|
/// Trusted administrator configuration; private data is passed only over IPC.
async fn Provider::exchange(
  self : Provider,
  request : String,
  operation : String,
) -> String raise @model.MedSealError {
  @async.with_timeout(30000, async fn() {
    @async.with_task_group() <| group => {
      let (input, writer) = @process.write_to_process()
      group.spawn_bg() <| () => {
        defer writer.close()
        writer.write(@utf8.encode(request))
      }
      let (code, output, _diagnostic) = @process.collect_output(
        self.python,
        [
          self.adapter,
          operation,
          "--store",
          self.store,
          "--source-domain",
          self.source_domain,
        ],
        stdin=input,
        inherit_env=false,
      )
      if code != 0 {
        raise @model.MedSealError::IdentityError(
          "private identity reservation failed; see controlled store diagnostics",
        )
      }
      let response = output.text()
      if response.length() > 32 * 1024 * 1024 {
        raise @model.MedSealError::IdentityError(
          "private response exceeds budget",
        )
      }
      response
    }
  }) catch {
    @model.MedSealError::IdentityError(message) =>
      raise @model.MedSealError::IdentityError(message)
    _ =>
      raise @model.MedSealError::IdentityError(
        "private identity adapter unavailable or timed out",
      )
  }
}

///|
pub async fn Provider::reserve(
  self : Provider,
  request : String,
) -> String raise @model.MedSealError {
  self.exchange(request, "reserve")
}

///|
pub async fn Provider::runtime_digest(
  self : Provider,
  binary_digest : String,
) -> String raise @model.MedSealError {
  let root = ledger_object(
    @json.parse(self.exchange("{\"schema\":1}", "runtime-fingerprint")) catch {
      _ =>
        raise @model.MedSealError::IdentityError(
          "invalid provider runtime JSON",
        )
    },
  )
  let digest = ledger_string(root.get("fingerprint"))
  if root.length() != 2 ||
    root.get("schema") != Some(Json::number(1.0)) ||
    digest.length() != 64 ||
    !digest.all(fn(c) { (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') }) {
    raise @model.MedSealError::IdentityError(
      "invalid provider runtime fingerprint",
    )
  }
  @checksum.sha256(@utf8.encode(binary_digest + ":" + digest))
}

///|
pub struct CachedArtifact {
  file : String
  sha256 : String
  audit_file : String
  audit_sha256 : String
}

///|
fn ledger_object(json : Json) -> Map[String, Json] raise @model.MedSealError {
  match json {
    Json::Object(fields) => fields
    _ =>
      raise @model.MedSealError::IdentityError(
        "invalid private ledger response",
      )
  }
}

///|
fn ledger_string(json : Json?) -> String raise @model.MedSealError {
  match json {
    Some(Json::String(value)) => value
    _ =>
      raise @model.MedSealError::IdentityError("invalid private ledger string")
  }
}

///|
pub async fn Provider::cached(
  self : Provider,
  request : String,
) -> Array[CachedArtifact?] raise @model.MedSealError {
  let fields = ledger_object(
    @json.parse(self.exchange(request, "cache-get")) catch {
      _ => raise @model.MedSealError::IdentityError("invalid cache JSON")
    },
  )
  if fields.length() != 2 || fields.get("schema") != Some(Json::number(1.0)) {
    raise @model.MedSealError::IdentityError("unsupported cache schema")
  }
  let entries = match fields.get("entries") {
    Some(Json::Array(values)) if values.length() <= 10000 => values
    _ => raise @model.MedSealError::IdentityError("invalid cache entries")
  }
  entries.map(value => {
    if value == Json::null() {
      return None
    }
    let item = ledger_object(value)
    if item.length() != 4 {
      raise @model.MedSealError::IdentityError("invalid cache entry fields")
    }
    let sha256 = ledger_string(item.get("sha256"))
    let audit_sha256 = ledger_string(item.get("audit_sha256"))
    for digest in [sha256, audit_sha256] {
      if digest.length() != 64 ||
        !digest.all(fn(c) { (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') }) {
        raise @model.MedSealError::IdentityError("invalid cache fingerprint")
      }
    }
    Some({
      file: ledger_string(item.get("file")),
      sha256,
      audit_file: ledger_string(item.get("audit_file")),
      audit_sha256,
    })
  })
}

///|
pub async fn Provider::cache_commit(
  self : Provider,
  request : String,
) -> Unit raise @model.MedSealError {
  let fields = ledger_object(
    @json.parse(self.exchange(request, "cache-put")) catch {
      _ => raise @model.MedSealError::IdentityError("invalid cache commit JSON")
    },
  )
  if fields.get("schema") != Some(Json::number(1.0)) ||
    ![
      Some(Json::string("already-cached")),
      Some(Json::string("cache-committed")),
    ].contains(fields.get("status")) {
    raise @model.MedSealError::IdentityError("cache commit failed")
  }
}

///|
/// Private authenticated history lookup; caller rechecks the DICOM metadata.
pub async fn Provider::history(
  self : Provider,
  request : String,
) -> Json raise @model.MedSealError {
  @json.parse(self.exchange(request, "history-get")) catch {
    _ => raise @model.MedSealError::IdentityError("invalid history response")
  }
}
