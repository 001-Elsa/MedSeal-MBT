///|
async fn load_policy(
  path : String?,
) -> @policy.Policy raise @model.MedSealError {
  match path {
    None => @policy.research()
    Some(path) => {
      let bytes = @storage.read(path, limit=1024 * 1024)
      let text = @utf8.decode(bytes) catch {
        _ => raise @model.MedSealError::PolicyError("invalid policy encoding")
      }
      @policy.from_json(text)
    }
  }
}
