///|
pub(all) enum ValidationSeverity {
  Error
  Warning
} derive(Eq, Debug)

///|
pub struct ValidationIssue {
  severity : ValidationSeverity
  code : String
  message : String
  tag : @model.Tag?
  offset : Int?
} derive(Eq, Debug)

///|
pub fn ValidationIssue::new(
  severity : ValidationSeverity,
  code : String,
  message : String,
  tag? : @model.Tag? = None,
  offset? : Int? = None,
) -> ValidationIssue {
  { severity, code, message, tag, offset, }
}

///|
pub struct ValidationReport {
  issues : Array[ValidationIssue]
  elements_checked : Int
} derive(Eq, Debug)

///|
pub fn ValidationReport::errors(self : ValidationReport) -> Int {
  self.issues.count_if(fn(issue) { issue.severity == Error })
}

///|
pub fn ValidationReport::warnings(self : ValidationReport) -> Int {
  self.issues.count_if(fn(issue) { issue.severity == Warning })
}

///|
pub fn ValidationReport::is_valid(self : ValidationReport) -> Bool {
  self.errors() == 0
}

///|
pub extend ValidationSeverity with Eq::{equal, not_equal}

///|
pub extend ValidationSeverity with Debug::{to_repr}

///|
pub extend ValidationIssue with Eq::{equal, not_equal}

///|
pub extend ValidationIssue with Debug::{to_repr}

///|
pub extend ValidationReport with Eq::{equal, not_equal}

///|
pub extend ValidationReport with Debug::{to_repr}
