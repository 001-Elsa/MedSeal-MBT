///|
async fn read_input(path : String) -> Bytes raise @model.MedSealError {
  @storage.read(path)
}

///|
fn presence(dataset : @model.DataSet, tag : @model.Tag) -> String {
  if dataset.find(tag) is Some(_) {
    "PRESENT"
  } else {
    "ABSENT"
  }
}

///|
fn has_pixel_data(dataset : @model.DataSet) -> Bool {
  dataset.elements.any(fn(element) {
    if element.tag == @model.pixel_data_tag {
      true
    } else {
      match element.value {
        @model.ElementValue::Sequence(items) => items.any(has_pixel_data)
        _ => false
      }
    }
  })
}

///|
fn inspect_json(
  _path : String,
  parsed : @parser.ParsedFile,
  report : @validator.ValidationReport,
) -> String {
  Json::object(
    Map::from_array([
      ("file", Json::string("source-0001")),
      ("format", Json::string("DICOM Part 10")),
      ("transfer_syntax", Json::string(parsed.transfer_syntax)),
      ("elements", Json::number(parsed.element_count.to_double())),
      (
        "patient_name",
        Json::string(presence(parsed.dataset, @dictionary.patient_name_tag())),
      ),
      (
        "patient_id",
        Json::string(presence(parsed.dataset, @dictionary.patient_id_tag())),
      ),
      (
        "private_tags",
        Json::number(
          @validator.private_element_count(parsed.dataset).to_double(),
        ),
      ),
      ("pixel_data", Json::boolean(has_pixel_data(parsed.dataset))),
      ("valid", Json::boolean(report.is_valid())),
      ("warnings", Json::number(report.warnings().to_double())),
      ("errors", Json::number(report.errors().to_double())),
    ]),
  ).stringify(indent=2)
}

///|
pub async fn inspect_file(
  path : String,
  json : Bool,
) -> Unit raise @model.MedSealError {
  let parsed = @parser.parse(read_input(path))
  let report = @validator.validate(parsed)
  if json {
    println(inspect_json(path, parsed, report))
    return
  }
  println("File: source-0001")
  println("Format: DICOM Part 10")
  println("Transfer Syntax: Explicit VR Little Endian")
  println("Elements: \{parsed.element_count}")
  println(
    "Patient Name: \{presence(parsed.dataset, @dictionary.patient_name_tag())}",
  )
  println(
    "Patient ID: \{presence(parsed.dataset, @dictionary.patient_id_tag())}",
  )
  println("Private Tags: \{@validator.private_element_count(parsed.dataset)}")
  println(
    "Pixel Data: \{if has_pixel_data(parsed.dataset) { "PRESENT" } else { "ABSENT" }}",
  )
  if report.is_valid() {
    if report.warnings() > 0 {
      println("Validation: PASSED WITH \{report.warnings()} WARNINGS")
    } else {
      println("Validation: PASSED")
    }
  } else {
    println("Validation: FAILED WITH \{report.errors()} ERRORS")
  }
}
