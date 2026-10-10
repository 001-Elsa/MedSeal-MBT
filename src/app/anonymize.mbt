///|
fn same_path(left : String, right : String) -> Bool {
  if @path.sep == '\\' {
    left.to_lower() == right.to_lower()
  } else {
    left == right
  }
}

///|
async fn ensure_output_paths(
  input : String,
  output : String,
  report : String?,
  force : Bool,
) -> Unit raise @model.MedSealError {
  let source = @storage.canonical(input)
  let target = @storage.output_path(output)
  if same_path(source, target) {
    raise @model.MedSealError::InvalidArgument(
      "output path must differ from input path",
    )
  }
  if @storage.exists(target) {
    if !force {
      raise @model.MedSealError::OutputAlreadyExists("object-0001")
    }
    if @storage.kind(target) != @async_fs.FileKind::Regular {
      raise @model.MedSealError::InvalidArgument(
        "existing output must be a regular file",
      )
    }
  }
  match report {
    Some(path) => {
      let report = @storage.output_path(path)
      if same_path(source, report) || same_path(target, report) {
        raise @model.MedSealError::InvalidArgument(
          "report path must differ from input and output paths",
        )
      }
      if @storage.exists(report) {
        if !force {
          raise @model.MedSealError::OutputAlreadyExists("audit-report")
        }
        if @storage.kind(report) != @async_fs.FileKind::Regular {
          raise @model.MedSealError::InvalidArgument(
            "existing report must be a regular file",
          )
        }
      }
    }
    None => ()
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
  let initial = @validator.validate(parsed)
  if !initial.is_valid() {
    raise @model.MedSealError::OutputVerificationFailed(
      "input contains semantic errors",
    )
  }
  let result = @deid.anonymize(parsed.dataset, remove_private~)
  let bytes = @dicom_writer.write_deidentified(parsed, result.dataset)
  let output = @storage.output_path(output)
  let temp = "\{output}.medseal-\{@storage.token()}.tmp"
  @storage.write_new(temp, bytes)
  defer (@async_fs.remove(temp) catch { _ => () })
  let verified = @parser.parse(read_input(temp))
  if !@validator.validate(verified).is_valid() {
    raise @model.MedSealError::OutputVerificationFailed(
      "output contains semantic errors",
    )
  }
  // Separate file destinations cannot be committed atomically. A report says
  // verified, not job-complete; batch uses a single directory publication.
  match report_path {
    Some(path) => {
      let path = @storage.output_path(path)
      let report = @deid.audit_json(
        result,
        "source-0001",
        "object-0001",
        parsed.transfer_syntax,
        parsed.element_count,
      )
      let staged = "\{path}.medseal-\{@storage.token()}.tmp"
      @storage.write_new(staged, @utf8.encode(report))
      defer (@async_fs.remove(staged) catch { _ => () })
      @storage.publish(staged, path, replace=force)
    }
    None => ()
  }
  @storage.publish(temp, output, replace=force)
  println("Anonymization completed")
  println("Source: source-0001")
  println("Output: object-0001")
  println("Elements changed: \{result.elements_changed}")
  println("Private elements removed: \{result.private_elements_removed}")
  println("Warnings: \{result.warnings.length()}")
  println(
    "Basic metadata de-identification only; pixel content was not inspected.",
  )
}
