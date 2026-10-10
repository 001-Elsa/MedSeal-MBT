///|
#borrow(buffer)
extern "C" fn entropy(buffer : Bytes, length : Int) -> Int = "medseal_entropy"

///|
pub fn token(size? : Int = 16) -> String raise @model.MedSealError {
  if size < 1 || size > 16 {
    raise @model.MedSealError::InvalidArgument("invalid entropy size")
  }
  let bytes = Bytes::make(size, b'\x00')
  if entropy(bytes, size) != 0 {
    raise @model.MedSealError::IoError("operating-system entropy unavailable")
  }
  @bigint.BigInt::from_octets(bytes[:]).to_string()
}

///|
pub fn date_offset(bound : Int) -> Int raise @model.MedSealError {
  if bound == 0 || bound < -3650 || bound > 3650 {
    raise @model.MedSealError::InvalidArgument("invalid date offset bound")
  }
  let bytes = Bytes::make(4, b'\x00')
  if entropy(bytes, 4) != 0 {
    raise @model.MedSealError::IoError("operating-system entropy unavailable")
  }
  let value = @bigint.BigInt::from_octets(bytes[:]) %
    @bigint.BigInt::from_int(bound.abs())
  let days = value.to_int() + 1
  if bound > 0 {
    days
  } else {
    -days
  }
}

///|
pub async fn kind(
  path : String,
) -> @async_fs.FileKind raise @model.MedSealError {
  @async_fs.kind(path, follow_symlink=false) catch {
    _ => raise @model.MedSealError::IoError("could not inspect file kind")
  }
}

///|
pub async fn exists(path : String) -> Bool raise @model.MedSealError {
  @async_fs.exists(path) catch {
    _ => raise @model.MedSealError::IoError("could not inspect target")
  }
}

///|
pub async fn list(path : String) -> Array[String] raise @model.MedSealError {
  @async_fs.readdir(path, include_hidden=true, sort=true) catch {
    _ => raise @model.MedSealError::IoError("could not read directory")
  }
}

///|
pub async fn snapshot(
  path : String,
) -> (Int64, (Int64, Int)) raise @model.MedSealError {
  let size = @async_fs.file_size(path) catch {
    _ => raise @model.MedSealError::IoError("could not inspect file size")
  }
  let time = @async_fs.mtime(path, follow_symlink=false) catch {
    _ =>
      raise @model.MedSealError::IoError("could not inspect modification time")
  }
  (size, time)
}

///|
pub async fn mkdir(path : String) -> Unit raise @model.MedSealError {
  @async_fs.mkdir(path, permission=0o700) catch {
    _ =>
      raise @model.MedSealError::IoError(
        "could not create exclusive job directory",
      )
  }
}

///|
pub async fn publish(
  source : String,
  target : String,
  replace? : Bool = false,
) -> Unit raise @model.MedSealError {
  @async_fs.rename(source, target, replace~) catch {
    _ => raise @model.MedSealError::IoError("could not publish staged result")
  }
}

///|
pub async fn read(
  path : String,
  limit? : Int = 256 * 1024 * 1024,
) -> Bytes raise @model.MedSealError {
  let kind = @async_fs.kind(path, follow_symlink=false) catch {
    _ => raise @model.MedSealError::IoError("could not inspect input")
  }
  if kind != @async_fs.FileKind::Regular {
    raise @model.MedSealError::InvalidArgument(
      "input must be a regular file; symbolic links are rejected",
    )
  }
  let file = @async_fs.open(path, mode=@async_fs.Mode::ReadOnly) catch {
    _ => raise @model.MedSealError::IoError("could not open input")
  }
  defer file.close()
  if file.kind() != @async_fs.FileKind::Regular {
    raise @model.MedSealError::InvalidArgument("input is not a regular file")
  }
  let size = file.size() catch {
    _ => raise @model.MedSealError::IoError("could not inspect input size")
  }
  if size > limit.to_int64() {
    raise @model.MedSealError::FileTooLarge(limit + 1)
  }
  let data = file.read_exactly_at(size.to_int(), position=0L) catch {
    _ => raise @model.MedSealError::IoError("could not read bounded input")
  }
  let current_size = file.size() catch {
    _ => raise @model.MedSealError::IoError("could not recheck input size")
  }
  if current_size != size {
    raise @model.MedSealError::IoError("input changed during reading")
  }
  data
}

///|
pub async fn write_new(
  path : String,
  bytes : Bytes,
) -> Unit raise @model.MedSealError {
  @async_fs.write_file(
    path,
    bytes,
    create_mode=@async_fs.CreateMode::CreateNew,
    permission=0o600,
    sync=@async_fs.SyncMode::Full,
  ) catch {
    _ =>
      raise @model.MedSealError::IoError(
        "could not create staged file exclusively",
      )
  }
}

///|
pub async fn output_path(path : String) -> String raise @model.MedSealError {
  let normalized = @path.Path(path).resolve()
  let parent = @async_fs.realpath(normalized.dirname().0) catch {
    _ =>
      raise @model.MedSealError::IoError(
        "output parent directory is unavailable",
      )
  }
  @path.Path(parent).join(@path.Path(normalized.basename().to_owned())).0
}

///|
pub async fn canonical(path : String) -> String raise @model.MedSealError {
  @async_fs.realpath(path) catch {
    _ => raise @model.MedSealError::IoError("could not resolve path")
  }
}
