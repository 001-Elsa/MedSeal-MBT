///|
pub struct Inventory {
  candidates : Array[String]
  excluded : Array[String]
  entries : Int
}

///|
async fn visit(
  root : String,
  depth : Int,
  paths : Array[String],
  excluded : Array[String],
  entries : Array[Int],
) -> Unit raise @model.MedSealError {
  if depth > 16 {
    raise @model.MedSealError::InvalidArgument("directory nesting exceeds 16")
  }
  for name in @storage.list(root) {
    entries[0] = entries[0] + 1
    if entries[0] > 20000 {
      raise @model.MedSealError::InvalidArgument(
        "discovery exceeds 20000 entries",
      )
    }
    let path = @path.Path(root).join(@path.Path(name)).0
    match @storage.kind(path) {
      @async_fs.FileKind::Directory =>
        visit(path, depth + 1, paths, excluded, entries)
      @async_fs.FileKind::Regular =>
        if name.to_lower().has_suffix(".dcm") || @storage.part10_candidate(path) {
          paths.push(path)
          if paths.length() > 10000 {
            raise @model.MedSealError::InvalidArgument(
              "job exceeds 10000 files",
            )
          }
        } else {
          excluded.push(path)
        }
      _ =>
        raise @model.MedSealError::InvalidArgument(
          "links and special entries are rejected during discovery",
        )
    }
  }
}

///|
pub async fn discover(root : String) -> Inventory raise @model.MedSealError {
  let candidates : Array[String] = []
  let excluded : Array[String] = []
  let entries = [0]
  visit(root, 0, candidates, excluded, entries)
  candidates.sort()
  excluded.sort()
  { candidates, excluded, entries: entries[0], }
}

///|
pub fn Inventory::summary(self : Inventory) -> Json {
  Json::object(
    Map::from_array([
      (
        "regular_files",
        Json::number(
          (self.candidates.length() + self.excluded.length()).to_double(),
        ),
      ),
      ("candidates", Json::number(self.candidates.length().to_double())),
      ("excluded_non_part10", Json::number(self.excluded.length().to_double())),
    ]),
  )
}
