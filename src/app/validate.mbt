///|
fn issue_json(issue : @validator.ValidationIssue) -> Json {
  let values : Array[(String, Json)] = [
    (
      "severity",
      Json::string(
        match issue.severity {
          Error => "error"
          Warning => "warning"
        },
      ),
    ),
    ("code", Json::string(issue.code)),
    ("message", Json::string(issue.message)),
  ]
  match issue.tag {
    Some(tag) => values.push(("tag", Json::string(tag.compact())))
    None => ()
  }
  match issue.offset {
    Some(offset) => values.push(("offset", Json::number(offset.to_double())))
    None => ()
  }
  Json::object(Map::from_array(values))
}

///|
pub async fn validate_file(
  path : String,
  json : Bool,
) -> Bool raise @model.MedSealError {
  let parsed = @parser.parse(read_input(path))
  let report = @validator.validate(parsed)
  if json {
    println(
      Json::object(
        Map::from_array([
          ("valid", Json::boolean(report.is_valid())),
          (
            "elements_checked",
            Json::number(report.elements_checked.to_double()),
          ),
          ("warnings", Json::number(report.warnings().to_double())),
          ("errors", Json::number(report.errors().to_double())),
          ("issues", Json::array(report.issues.map(issue_json))),
        ]),
      ).stringify(indent=2),
    )
  } else {
    println(if report.is_valid() { "VALID" } else { "INVALID" })
    println("Elements checked: \{report.elements_checked}")
    println("Warnings: \{report.warnings()}")
    println("Errors: \{report.errors()}")
    for issue in report.issues {
      println("\{issue.code}: \{issue.message}")
      match issue.tag {
        Some(tag) => println("Tag: \{tag.to_string()}")
        None => ()
      }
    }
  }
  report.is_valid()
}
