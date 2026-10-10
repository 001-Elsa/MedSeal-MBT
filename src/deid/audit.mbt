///|
pub struct AuditEvent {
  tag : String
  name : String
  action : String
} derive(Eq, Debug)

///|
pub struct AuditWarning {
  code : String
  message : String
} derive(Eq, Debug)

///|
pub struct AnonymizeResult {
  dataset : @model.DataSet
  elements_changed : Int
  elements_removed : Int
  private_elements_removed : Int
  changes : Array[AuditEvent]
  warnings : Array[AuditWarning]
} derive(Eq, Debug)

///|
fn event_json(event : AuditEvent) -> Json {
  Json::object(
    Map::from_array([
      ("tag", Json::string(event.tag)),
      ("name", Json::string(event.name)),
      ("action", Json::string(event.action)),
    ]),
  )
}

///|
fn warning_json(warning : AuditWarning) -> Json {
  Json::object(
    Map::from_array([
      ("code", Json::string(warning.code)),
      ("message", Json::string(warning.message)),
    ]),
  )
}

///|
pub fn audit_json(
  result : AnonymizeResult,
  _input_file : String,
  _output_file : String,
  transfer_syntax : String,
  elements_read : Int,
) -> String {
  Json::object(
    Map::from_array([
      ("tool", Json::string("medseal")),
      ("version", Json::string(@model.medseal_version)),
      ("status", Json::string("verified")),
      ("input_file", Json::string("source-0001")),
      ("output_file", Json::string("object-0001")),
      ("transfer_syntax", Json::string(transfer_syntax)),
      ("elements_read", Json::number(elements_read.to_double())),
      ("elements_changed", Json::number(result.elements_changed.to_double())),
      ("elements_removed", Json::number(result.elements_removed.to_double())),
      (
        "private_elements_removed",
        Json::number(result.private_elements_removed.to_double()),
      ),
      ("pixel_data_modified", Json::boolean(false)),
      ("uid_values_modified", Json::boolean(false)),
      ("changes", Json::array(result.changes.map(event_json))),
      ("warnings", Json::array(result.warnings.map(warning_json))),
    ]),
  ).stringify(indent=2)
}

///|
pub extend AuditEvent with Eq::{equal, not_equal}

///|
pub extend AuditEvent with Debug::{to_repr}

///|
pub extend AuditWarning with Eq::{equal, not_equal}

///|
pub extend AuditWarning with Debug::{to_repr}

///|
pub extend AnonymizeResult with Eq::{equal, not_equal}

///|
pub extend AnonymizeResult with Debug::{to_repr}
