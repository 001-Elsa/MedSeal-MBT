///|
pub async fn read_prefix(
  path : String,
  limit : Int,
) -> Bytes raise @model.MedSealError {
  if limit < 132 || limit > 2 * 1024 * 1024 {
    raise @model.MedSealError::InvalidArgument("invalid prefix budget")
  }
  try {
    let file = @async_fs.open(path, mode=@async_fs.Mode::ReadOnly)
    defer file.close()
    check_source(file, path)
    let size = file.size()
    if size > 256L * 1024L * 1024L {
      raise @model.MedSealError::FileTooLarge(256 * 1024 * 1024 + 1)
    }
    let prefix = file.read_exactly_at(size.to_int().min(limit), position=0L)
    check_source(file, path)
    prefix
  } catch {
    _ => raise @model.MedSealError::IoError("bounded prefix read failed")
  }
}

///|
/// Hash/copy a source range with a fixed one-MiB buffer and optional new destination.
pub async fn stream_range(
  source : String,
  offset : Int,
  length : Int,
  prefix? : Bytes = b"",
  output? : String? = None,
) -> String raise @model.MedSealError {
  try {
    let input = @async_fs.open(source, mode=@async_fs.Mode::ReadOnly)
    defer input.close()
    check_source(input, source)
    let before = (input.size(), input.mtime(), input.ctime())
    if offset < 0 ||
      length < 0 ||
      before.0 > 256L * 1024L * 1024L ||
      offset.to_int64() + length.to_int64() > before.0 {
      raise @model.MedSealError::InvalidArgument("invalid bounded source span")
    }
    let destination = match output {
      Some(path) =>
        Some(
          @async_fs.open(
            path,
            mode=@async_fs.Mode::WriteOnly,
            create_mode=@async_fs.CreateMode::CreateNew,
            permission=0o600,
          ),
        )
      None => None
    }
    defer (if destination is Some(file) { file.close() })
    let digest = @checksum.StreamDigest::new()
    digest.update(prefix[:])
    if destination is Some(file) {
      file.write_at(prefix[:], position=0L)
    }
    let mut position = 0
    while position < length {
      let data = input.read_exactly_at(
        (length - position).min(1024 * 1024),
        position=(offset + position).to_int64(),
      )
      digest.update(data[:])
      if destination is Some(file) {
        file.write_at(data[:], position=(prefix.length() + position).to_int64())
      }
      position = position + data.length()
    }
    if (input.size(), input.mtime(), input.ctime()) != before {
      raise @model.MedSealError::IoError("source changed during streaming")
    }
    check_source(input, source)
    if destination is Some(file) {
      file.sync()
    }
    if output is Some(path) {
      sync_dir(@path.Path(path).dirname().0)
    }
    digest.finish()
  } catch {
    _ => raise @model.MedSealError::IoError("bounded source hash/copy failed")
  }
}

///|
pub async fn file_digest(path : String) -> String raise @model.MedSealError {
  let size = snapshot(path).0
  if size > 256L * 1024L * 1024L {
    raise @model.MedSealError::FileTooLarge(256 * 1024 * 1024 + 1)
  }
  stream_range(path, 0, size.to_int())
}
