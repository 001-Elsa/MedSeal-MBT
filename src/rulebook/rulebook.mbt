///|
pub struct Entry {
  id : String
  tag : @model.Tag
  vr : String
  vm : String
  role : String
  action : String
  confidentiality_table : Bool
}

///|
pub fn accepts_vr(tag : @model.Tag, vr : @model.Vr) -> Bool {
  lookup(tag)
  .map(fn(e) { e.vr.split(" or ").any(fn(value) { value == vr.to_string() }) })
  .unwrap_or(false)
}

///|
pub fn accepts_vm(tag : @model.Tag, count : Int) -> Bool {
  guard count >= 0 else { return false }
  guard lookup(tag) is Some(entry) else { return false }
  if count == 0 {
    return true
  } // Requiredness is a separate IOD constraint.
  let parts = entry.vm.split("-").to_array()
  let low = @string.parse_int(parts[0]) catch { _ => return false }
  if parts.length() == 1 {
    return count == low
  }
  let high = parts[1]
  if high == "n" {
    return count >= low
  }
  if high.has_suffix("n") {
    let step = @string.parse_int(high[0:high.length() - 1]) catch {
      _ => return false
    }
    return step > 0 && count >= low && count % step == 0
  }
  let maximum = @string.parse_int(high) catch { _ => return false }
  count >= low && count <= maximum
}

///|
pub(all) enum ConditionOutcome {
  Met
  NotMet
  Unknown
} derive(Eq, Debug)

///|
pub fn ConditionOutcome::both(
  self : ConditionOutcome,
  other : ConditionOutcome,
) -> ConditionOutcome {
  match (self, other) {
    (NotMet, _) | (_, NotMet) => NotMet
    (Met, Met) => Met
    _ => Unknown
  }
}

///|
pub fn ConditionOutcome::either(
  self : ConditionOutcome,
  other : ConditionOutcome,
) -> ConditionOutcome {
  match (self, other) {
    (Met, _) | (_, Met) => Met
    (NotMet, NotMet) => NotMet
    _ => Unknown
  }
}

///|
pub fn ConditionOutcome::name(self : ConditionOutcome) -> String {
  match self {
    Met => "met"
    NotMet => "not-met"
    Unknown => "unknown"
  }
}

///|
pub fn presence(
  dataset : @model.DataSet,
  tag : @model.Tag,
  complete? : Bool = true,
) -> ConditionOutcome {
  if dataset.find(tag) is Some(_) {
    Met
  } else if complete {
    NotMet
  } else {
    Unknown
  }
}

///|
pub fn sop_condition(
  dataset : @model.DataSet,
  expected : String,
) -> ConditionOutcome {
  match dataset.find(@model.Tag::new(0x0008U, 0x0016U)) {
    Some({ value: @model.ElementValue::Text(actual), vr: @model.Vr::UI, .. }) if !actual.is_empty() =>
      if actual == expected {
        Met
      } else {
        NotMet
      }
    _ => Unknown
  }
}

///|
pub fn require_condition(
  outcome : ConditionOutcome,
) -> Bool raise @model.MedSealError {
  match outcome {
    Met => true
    NotMet => false
    Unknown =>
      raise @model.MedSealError::RuleViolation(
        "condition-resolved", "dataset", "unknown", "condition",
      )
  }
}

///|
pub struct RuleDecision {
  path : String
  rule_id : String
  action : String
  condition : ConditionOutcome
  source : String
  reason : String
}

///|
pub fn safe_path(path : String) -> Bool {
  if path == "dataset" {
    return true
  }
  if path.length() > 1024 || !path.has_prefix("dataset/") {
    return false
  }
  let parts = path.split("/").to_array()
  if parts.length() > 34 {
    return false
  }
  for i = 1; i < parts.length(); i = i + 1 {
    let part = parts[i]
    if part.length() < 9 || part[4] != ',' {
      return false
    }
    let tag = part[0:4].to_owned() + part[5:9].to_owned()
    if !tag.all(fn(c) { (c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') }) {
      return false
    }
    if i == parts.length() - 1 {
      if part.length() != 9 {
        return false
      }
    } else {
      if part.length() < 12 || part[9] != '[' || !part.has_suffix("]") {
        return false
      }
      let index = part[10:part.length() - 1]
      if index.length() > 6 ||
        !index.all(fn(c) { c >= '0' && c <= '9' }) ||
        (index.length() > 1 && index[0] == '0') {
        return false
      }
    }
  }
  true
}

///|
/// Construct an allowlisted public decision without accepting any patient value.
pub fn decision(
  tag : @model.Tag,
  path : String,
  action : String,
  custom? : Bool = false,
) -> RuleDecision raise @model.MedSealError {
  guard safe_path(path) else {
    raise @model.MedSealError::PolicyError("invalid public field path")
  }
  if path.split("/").to_array().last() != Some(tag.compact()) {
    raise @model.MedSealError::PolicyError("decision tag differs from path")
  }
  let entry = lookup(tag)
  let privacy_group = tag.is_private() ||
    tag.element == 0U ||
    [0x0400U, 0xFFFAU, 0xFFFCU].contains(tag.group) ||
    (tag.group >= 0x6000U && tag.group <= 0x60FFU)
  if (privacy_group || tag == @model.Tag::new(0x0008U, 0x0001U)) &&
    action == "remove" {
    return {
      path,
      rule_id: "structure-remove",
      action,
      condition: Met,
      source: "DICOM 2025e PS3.15 E.1",
      reason: "removed-sensitive-or-obsolete-structure",
    }
  }
  guard entry is Some(e) else {
    raise @model.MedSealError::PolicyError("unclassified decision")
  }
  guard action == e.action ||
    (action == "keep" && ["shift-da", "instance-uid"].contains(e.role)) ||
    (e.role == "descriptive" && ["empty", "remove", "replace"].contains(action)) else {
    raise @model.MedSealError::PolicyError(
      "decision action violates strict classification",
    )
  }
  {
    path,
    rule_id: e.id,
    action,
    condition: Met,
    source: if e.confidentiality_table {
      "DICOM 2025e PS3.15 Table E.1-1; PS3.6 Table 6-1"
    } else {
      "DICOM 2025e PS3.6 Table 6-1; MedSeal reviewed policy"
    },
    reason: if custom {
      "compiled-descriptive-override"
    } else {
      "reviewed-attribute-classification"
    },
  }
}

///|
pub fn RuleDecision::to_json(self : RuleDecision) -> Json {
  Json::object(
    Map::from_array([
      ("path", Json::string(self.path)),
      ("rule_id", Json::string(self.rule_id)),
      ("action", Json::string(self.action)),
      (
        "condition",
        Json::object(
          Map::from_array([
            ("result", Json::string(self.condition.name())),
            ("predicate", Json::string("validated-strict-context")),
          ]),
        ),
      ),
      ("source", Json::string(self.source)),
      ("reason", Json::string(self.reason)),
      ("stage", Json::string("transform")),
      (
        "evidence_id",
        Json::string(
          if self.rule_id.has_prefix("attr-") {
            "rule-" + self.rule_id[5:].to_owned() + "-valid-field"
          } else {
            "structure-remove-valid"
          },
        ),
      ),
    ]),
  )
}

///|
pub extend ConditionOutcome with Eq::{equal, not_equal}

///|
pub extend ConditionOutcome with Debug::{to_repr}
