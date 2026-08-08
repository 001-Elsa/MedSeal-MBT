///|
fn same_path(left : String, right : String) -> Bool {
  let left_resolved = @path.Path(left).resolve().0
  let right_resolved = @path.Path(right).resolve().0
  if @path.sep == '\\' {
    left_resolved.to_lower() == right_resolved.to_lower()
  } else {
    left_resolved == right_resolved
  }
}

///|
fn ensure_output_paths(
  input : String,
  output : String,
  report : String?,
  force : Bool,
) -> Unit raise @model.MedSealError {
  if same_path(input, output) {
    raise @model.MedSealError::InvalidArgument(
      "output path must differ from input path",
    )
  }
  if @fs.path_exists(output) && !force {
    raise @model.MedSealError::OutputAlreadyExists(output)
  }
  match report {
    Some(path) => {
      if same_path(path, input) || same_path(path, output) {
        raise @model.MedSealError::InvalidArgument(
          "report path must differ from input and output paths",
        )
      }
      if @fs.path_exists(path) && !force {
        raise @model.MedSealError::OutputAlreadyExists(path)
      }
    }
    None => ()
  }
}

///|
fn write_temp(path : String, bytes : Bytes) -> Unit raise @model.MedSealError {
  if @fs.path_exists(path) {
    raise @model.MedSealError::OutputAlreadyExists(path)
  }
  @fs.write_bytes_to_file(path, bytes) catch {
    @fs.IOError(message) => raise @model.MedSealError::IoError(message)
  }
}

///|
fn write_temp_text(
  path : String,
  value : String,
) -> Unit raise @model.MedSealError {
  if @fs.path_exists(path) {
    raise @model.MedSealError::OutputAlreadyExists(path)
  }
  @fs.write_string_to_file(path, value) catch {
    @fs.IOError(message) => raise @model.MedSealError::IoError(message)
  }
}

///|
async fn atomic_replace(
  temp : String,
  target : String,
  force : Bool,
) -> Unit raise @model.MedSealError {
  @async_fs.rename(temp, target, replace=force) catch {
    _ => {
      @fs.remove_file(temp) catch {
        _ => ()
      }
      raise @model.MedSealError::IoError(
        "could not atomically replace \{target}",
      )
    }
  }
}

///|
pub async fn anonymize_file(
  input : String,
  output : String,
  report_path : String?,
  remove_private : Bool,
  force : Bool,
) -> Unit raise @model.MedSealError {
  ensure_output_paths(input, output, report_path, force)
  let parsed = @parser.parse(read_input(input))
  let initial_validation = @validator.validate(parsed)
  if !initial_validation.is_valid() {
    raise @model.MedSealError::OutputVerificationFailed(
      "input contains \{initial_validation.errors()} semantic error(s)",
    )
  }
  let result = @deid.anonymize(parsed.dataset, remove_private~)
  let output_bytes = @dicom_writer.write_bytes(parsed, dataset=result.dataset)
  let temp = "\{output}.medseal.tmp"
  write_temp(temp, output_bytes)
  let verified = @parser.parse(read_input(temp)) catch {
    error => {
      @fs.remove_file(temp) catch {
        _ => ()
      }
      raise error
    }
  }
  let verification = @validator.validate(verified)
  if !verification.is_valid() {
    @fs.remove_file(temp) catch {
      _ => ()
    }
    raise @model.MedSealError::OutputVerificationFailed(
      "output contains \{verification.errors()} semantic error(s)",
    )
  }
  atomic_replace(temp, output, force)
  match report_path {
    Some(path) => {
      let report = @deid.audit_json(
        result,
        input,
        output,
        parsed.transfer_syntax,
        parsed.element_count,
      )
      let report_temp = "\{path}.medseal.tmp"
      write_temp_text(report_temp, report)
      atomic_replace(report_temp, path, force)
    }
    None => ()
  }
  println("Anonymization completed")
  println("Input: \{input}")
  println("Output: \{output}")
  println("Elements changed: \{result.elements_changed}")
  println("Private elements removed: \{result.private_elements_removed}")
  println("Warnings: \{result.warnings.length()}")
  match report_path {
    Some(path) => println("Report: \{path}")
    None => ()
  }
  println("")
  println("The output file has received basic metadata de-identification.")
  println(
    "Pixel data has not been inspected for burned-in personal information.",
  )
  println("This tool does not guarantee complete anonymization.")
}
