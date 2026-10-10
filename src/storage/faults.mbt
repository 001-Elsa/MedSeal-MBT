///|
/// Instance-local failure injection for exercising real cleanup paths.
pub struct Faults {
  priv operation : String
  priv occurrence : Int
  priv mut hits : Int
}

///|
pub fn Faults::new(
  operation : String,
  occurrence? : Int = 1,
) -> Faults raise @model.MedSealError {
  if !["create", "after-partial-write", "before-sync", "publish"].contains(
      operation,
    ) ||
    occurrence < 1 {
    raise @model.MedSealError::InvalidArgument("invalid fault specification")
  }
  { operation, occurrence, hits: 0, }
}

///|
pub fn Faults::hit(
  self : Faults,
  operation : String,
) -> Unit raise @model.MedSealError {
  if operation == self.operation {
    self.hits = self.hits + 1
    if self.hits == self.occurrence {
      raise @model.MedSealError::IoError(
        "injected storage failure: \{operation}",
      )
    }
  }
}
