///|
pub(all) struct Provider {
  python : String
  adapter : String
  store : String
  source_domain : String
}

///|
/// Trusted administrator configuration; private data is passed only over IPC.
pub async fn Provider::reserve(
  self : Provider,
  request : String,
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
          "reserve",
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
