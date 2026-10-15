///|
pub(all) enum Severity {
  Blocking
  Advisory
} derive(Eq, Debug)

///|
pub(all) enum CheckState {
  Passed
  Failed
  NotChecked
  Unsupported
} derive(Eq, Debug)

///|
pub struct Issue {
  object_index : Int
  code : String
  severity : Severity
  location : String
  suggestion : String
}

///|
pub struct Report {
  issues : Array[Issue]
  objects : Int
  object_state : CheckState
  collection_state : CheckState
}

///|
fn issue(
  index : Int,
  code : String,
  location : String,
  suggestion : String,
  severity? : Severity = Blocking,
) -> Issue {
  { object_index: index, code, severity, location, suggestion, }
}

///|
/// Checks available metadata. Does not inspect pixel privacy or certify full IOD.
pub fn check_datasets(
  datasets : Array[@model.DataSet],
  required_fields? : Array[@model.Tag] = [],
) -> Report {
  let issues : Array[Issue] = []
  if datasets.is_empty() ||
    datasets.length() > 10000 ||
    required_fields.length() > 64 {
    return {
      issues: [
        issue(-1, "QUALITY-BUDGET", "collection", "Provide 1 to 10000 objects."),
      ],
      objects: datasets.length(),
      object_state: NotChecked,
      collection_state: NotChecked,
    }
  }
  let count = [0]
  for dataset in datasets {
    if !bounded_model(dataset, 0, count) {
      return {
        issues: [
          issue(
            -1, "QUALITY-BUDGET", "collection", "Limit model depth to 32 and total elements to 1000000.",
          ),
        ],
        objects: datasets.length(),
        object_state: NotChecked,
        collection_state: NotChecked,
      }
    }
  }
  for index, dataset in datasets {
    for tag in required_fields {
      let missing = match dataset.find(tag) {
        None | Some({ value: @model.ElementValue::Empty, .. }) => true
        Some({ value: @model.ElementValue::Text(value), .. }) =>
          value.is_empty()
        _ => false
      }
      if missing {
        issues.push(
          issue(
            index,
            "QUALITY-REQUIRED",
            "dataset/" + tag.compact(),
            "Provide a nonempty value for this caller-required field.",
          ),
        )
      }
    }
    for item in @validator.validate_dataset(dataset).issues {
      issues.push(
        issue(
          index,
          item.code,
          match item.tag {
            Some(tag) => "dataset/" + tag.compact()
            None => "dataset"
          },
          "Check the declared field type and required metadata.",
          severity=if item.severity == @validator.Error {
            Blocking
          } else {
            Advisory
          },
        ),
      )
    }
    @conformance.check_research(dataset, full_pixels=false) catch {
      e =>
        issues.push(
          issue(
            index,
            e.code(),
            "dataset",
            "Check the supported research metadata profile.",
          ),
        )
    }
    @verification.check_unique_tags(dataset) catch {
      e =>
        issues.push(
          issue(
            index,
            e.code(),
            "dataset",
            "Remove conflicting duplicate tags in the source.",
          ),
        )
    }
  }
  let mut collection_state = Passed
  ignore(@verification.check(datasets)) catch {
    e => {
      collection_state = Failed
      issues.push(
        issue(
          -1,
          e.code(),
          "collection",
          "Check SOP uniqueness, patient/study ownership and closed references.",
        ),
      )
    }
  }
  // Constant-per-series acquisition attributes; slice position is intentionally excluded.
  let seen : Map[String, Array[String?]] = Map([])
  for index, dataset in datasets {
    let series_tag = @model.Tag::new(0x0020U, 0x000EU)
    if dataset.find(series_tag) is Some({ value: @model.Text(uid), .. }) {
      let signature = [
        @model.Tag::new(0x0008U, 0x0060U),
        @model.Tag::new(0x0028U, 0x0010U),
        @model.Tag::new(0x0028U, 0x0011U),
        @model.Tag::new(0x0028U, 0x0100U),
      ].map(tag => {
        match dataset.find(tag) {
          None => None
          Some(e) =>
            Some(
              match e.value {
                @model.Text(v) => v
                @model.UnsignedShort(v) => v.map(n => n.to_string()).join("\\")
                _ => "<unsupported>"
              },
            )
        }
      })
      match seen.get(uid) {
        Some(old) if old != signature =>
          issues.push(
            issue(
              index,
              "QUALITY-SERIES",
              "dataset/0020,000E",
              "Review inconsistent modality, dimensions or bit allocation within this series.",
              severity=Advisory,
            ),
          )
        _ => seen.set(uid, signature)
      }
    }
  }
  let object_state = if issues.any(i => {
      i.object_index >= 0 && i.severity == Blocking
    }) {
    Failed
  } else {
    Passed
  }
  { issues, objects: datasets.length(), object_state, collection_state, }
}

///|
/// Parse errors are recorded, never dropped to label a successful subset ready.
pub fn check(
  inputs : Array[Bytes],
  required_fields? : Array[@model.Tag] = [],
) -> Report {
  if inputs.is_empty() || inputs.length() > 256 {
    return {
      issues: [
        issue(
          -1, "QUALITY-BUDGET", "collection", "Use 1 to 256 buffered objects or the Native scanner.",
        ),
      ],
      objects: inputs.length(),
      object_state: NotChecked,
      collection_state: NotChecked,
    }
  }
  let mut remaining = 128 * 1024 * 1024
  for input in inputs {
    if input.length() > 64 * 1024 * 1024 || input.length() > remaining {
      return {
        issues: [
          issue(
            -1, "QUALITY-BUDGET", "collection", "Use the bounded Native scanner for larger files.",
          ),
        ],
        objects: inputs.length(),
        object_state: NotChecked,
        collection_state: NotChecked,
      }
    }
    remaining = remaining - input.length()
  }
  let datasets : Array[@model.DataSet] = []
  let issues : Array[Issue] = []
  let mut unsupported = false
  for index, input in inputs {
    try {
      let parsed = @parser.parse(input)
      @verification.check_file_meta(parsed)
      @conformance.check_research(parsed.dataset, full_pixels=true)
      datasets.push(parsed.dataset)
    } catch {
      e => {
        match e {
          @model.UnsupportedTransferSyntax(_)
          | @model.UnsupportedImplicitTag(_)
          | @model.AmbiguousImplicitVr(_) => unsupported = true
          _ => ()
        }
        issues.push(
          issue(
            index,
            e.code(),
            "object",
            "Check supported syntax, encoding, structure and research profile.",
          ),
        )
      }
    }
  }
  if !issues.is_empty() {
    return {
      issues,
      objects: inputs.length(),
      object_state: if unsupported {
        Unsupported
      } else {
        Failed
      },
      collection_state: NotChecked,
    }
  }
  check_datasets(datasets, required_fields~)
}

///|
pub fn Report::ready(self : Report) -> Bool {
  self.object_state == Passed &&
  self.collection_state == Passed &&
  !self.issues.any(i => i.severity == Blocking)
}

///|
fn state_name(state : CheckState) -> String {
  match state {
    Passed => "passed"
    Failed => "failed"
    NotChecked => "not-checked"
    Unsupported => "unsupported"
  }
}

///|
pub fn Report::public_json(self : Report) -> Json {
  Json::object(
    Map::from_array([
      ("schema", Json::string("medseal-quality-v1")),
      ("objects", Json::number(self.objects.to_double())),
      ("object_checks", Json::string(state_name(self.object_state))),
      ("collection_checks", Json::string(state_name(self.collection_state))),
      ("ready", Json::boolean(self.ready())),
      ("release_authorized", Json::boolean(false)),
      (
        "issues",
        Json::array(
          self.issues.map(i => {
            Json::object(
              Map::from_array([
                ("object_index", Json::number(i.object_index.to_double())),
                ("code", Json::string(i.code)),
                (
                  "severity",
                  Json::string(
                    if i.severity == Blocking {
                      "blocking"
                    } else {
                      "advisory"
                    },
                  ),
                ),
                ("location", Json::string(i.location)),
                ("suggestion", Json::string(i.suggestion)),
              ]),
            )
          }),
        ),
      ),
    ]),
  )
}

///|
pub extend Severity with Eq::{equal, not_equal}

///|
pub extend Severity with Debug::{to_repr}

///|
pub extend CheckState with Eq::{equal, not_equal}

///|
pub extend CheckState with Debug::{to_repr}

///|
fn bounded_model(
  dataset : @model.DataSet,
  depth : Int,
  count : Array[Int],
) -> Bool {
  if depth > 32 || dataset.elements.length() > 1000000 - count[0] {
    return false
  }
  count[0] = count[0] + dataset.elements.length()
  for element in dataset.elements {
    if element.value is @model.ElementValue::Sequence(items) {
      if items.length() > 1000000 - count[0] {
        return false
      }
      count[0] = count[0] + items.length()
      for item in items {
        if !bounded_model(item, depth + 1, count) {
          return false
        }
      }
    }
  }
  true
}

///|
/// Turn Native per-object failures into safe diagnostics with original indices.
pub fn from_errors(
  objects : Int,
  failures : Array[(Int, @model.MedSealError)],
) -> Report {
  let issues : Array[Issue] = []
  let mut unsupported = false
  if objects < 1 ||
    objects > 10000 ||
    failures.is_empty() ||
    failures.length() > objects {
    return {
      issues: [
        issue(
          -1, "QUALITY-BUDGET", "collection", "Provide the original object count and one or more object failures.",
        ),
      ],
      objects,
      object_state: NotChecked,
      collection_state: NotChecked,
    }
  }
  for (index, error) in failures {
    if index < 0 || index >= objects {
      return {
        issues: [
          issue(
            -1, "QUALITY-BUDGET", "collection", "Use original in-range object indices.",
          ),
        ],
        objects,
        object_state: NotChecked,
        collection_state: NotChecked,
      }
    }
    match error {
      @model.MedSealError::UnsupportedTransferSyntax(_)
      | @model.MedSealError::UnsupportedImplicitTag(_)
      | @model.MedSealError::AmbiguousImplicitVr(_) => unsupported = true
      _ => ()
    }
    issues.push(
      issue(
        index,
        error.code(),
        "object",
        "Check supported syntax, encoding, structure and research profile.",
      ),
    )
  }
  {
    issues,
    objects,
    object_state: if unsupported {
      Unsupported
    } else {
      Failed
    },
    collection_state: NotChecked,
  }
}
