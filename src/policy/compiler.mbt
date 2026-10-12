///|
pub(all) struct PathRule {
  id : String
  path : String
  action : Action
  priority : Int
  sop : String?
  present : @model.Tag?
}

///|
fn segments(path : String) -> Array[String] {
  path
  .replace(old=",", new="")
  .split("/")
  .map(fn(value) { value.to_owned() })
  .to_array()
}

///|
fn path_match(pattern : String, location : String) -> Bool {
  let a = segments(pattern)
  let b = segments(location)
  if a.length() != b.length() {
    return false
  }
  for i, part in a {
    if part.has_suffix("[*]") {
      let prefix = part[0:part.length() - 3].to_owned()
      if !b[i].has_prefix(prefix + "[") || !b[i].has_suffix("]") {
        return false
      }
    } else if part != b[i] {
      return false
    }
  }
  true
}

///|
fn overlap(left : String, right : String) -> Bool {
  let a = segments(left)
  let b = segments(right)
  if a.length() != b.length() {
    return false
  }
  for i, part in a {
    if part != b[i] && !part.has_suffix("[*]") && !b[i].has_suffix("[*]") {
      return false
    }
    if part.has_suffix("[*]") || b[i].has_suffix("[*]") {
      let x = part.split("[").take(1).to_array()
      let y = b[i].split("[").take(1).to_array()
      if x != y {
        return false
      }
    }
  }
  true
}

///|
pub fn strict(
  scope_name? : String = "research",
  date_shift_days? : Int = 30,
  path_rules? : Array[PathRule] = [],
  retain_dt? : Bool = false,
) -> Policy raise @model.MedSealError {
  let base = research(scope_name~, date_shift_days~)
  if path_rules.length() > 1000 {
    raise @model.MedSealError::PolicyError("too many path rules")
  }
  let ids : Map[String, Bool] = Map([])
  for i, rule in path_rules {
    if rule.id.is_empty() ||
      rule.id.length() > 64 ||
      !rule.id.all(fn(c) {
        (c >= 'A' && c <= 'Z') ||
        (c >= 'a' && c <= 'z') ||
        (c >= '0' && c <= '9') ||
        c == '-' ||
        c == '_'
      }) ||
      ids.contains(rule.id) {
      raise @model.MedSealError::PolicyError(
        "invalid or duplicate path rule id",
      )
    }
    ids.set(rule.id, true)
    let parts = segments(rule.path)
    if parts.length() < 2 ||
      parts.length() > 34 ||
      parts[0] != "dataset" ||
      rule.priority < -1000 ||
      rule.priority > 1000 {
      raise @model.MedSealError::PolicyError("invalid rule path or priority")
    }
    for j = 1; j < parts.length(); j = j + 1 {
      let part = parts[j]
      let tag_text = if part.has_suffix("[*]") {
        part[0:part.length() - 3].to_owned()
      } else {
        part
      }
      let tag = parse_tag(tag_text)
      if tag_text != tag.compact().replace(old=",", new="") {
        raise @model.MedSealError::PolicyError(
          "rule paths use uppercase hexadecimal tags",
        )
      }
      if j < parts.length() - 1 {
        if !part.has_suffix("[*]") ||
          @dictionary.strict_attribute(tag).map(fn(a) { a.role }) !=
          Some("sequence") {
          raise @model.MedSealError::PolicyError(
            "only reviewed Sequence wildcard ancestors are supported",
          )
        }
      } else if @dictionary.strict_attribute(tag).map(fn(a) { a.role }) !=
        Some("descriptive") {
        raise @model.MedSealError::PolicyError(
          "path rule cannot override identity, structure or unclassified fields",
        )
      }
    }
    match rule.action {
      Keep =>
        raise @model.MedSealError::PolicyError(
          "strict descriptive fields cannot be kept",
        )
      Replace(value) if value.length() > 64 ||
        value.any(fn(c) { c.to_int() < 32 || c.to_int() > 126 }) =>
        raise @model.MedSealError::PolicyError(
          "replacement must be printable ASCII within 64 characters",
        )
      _ => ()
    }
    if rule.sop is Some(value) &&
      ![
        "1.2.840.10008.5.1.4.1.1.2", "1.2.840.10008.5.1.4.1.1.4", "1.2.840.10008.5.1.4.1.1.7",
      ].contains(value) {
      raise @model.MedSealError::PolicyError("unsupported SOP condition")
    }
    if rule.present is Some(tag) && @dictionary.strict_attribute(tag) is None {
      raise @model.MedSealError::PolicyError(
        "presence condition uses unclassified tag",
      )
    }
    for j = 0; j < i; j = j + 1 {
      let previous = path_rules[j]
      if previous.priority == rule.priority &&
        overlap(previous.path, rule.path) &&
        (previous.sop is None || rule.sop is None || previous.sop == rule.sop) {
        raise @model.MedSealError::PolicyError(
          "overlapping rules need different priorities",
        )
      }
    }
  }
  { ..base, strict_metadata: true, retain_dt, path_rules: path_rules.copy(), }
}

///|
pub fn Policy::path_action(
  self : Policy,
  location : String,
  sop : String,
  dataset : @model.DataSet,
) -> (String, Action)? {
  let mut selected : PathRule? = None
  for rule in self.path_rules {
    if path_match(rule.path, location) &&
      (rule.sop is None || rule.sop == Some(sop)) &&
      (match rule.present {
        None => true
        Some(tag) => dataset.find(tag) is Some(_)
      }) {
      if selected is None || rule.priority > selected.unwrap().priority {
        selected = Some(rule)
      }
    }
  }
  selected.map(fn(rule) { (rule.id, rule.action) })
}

///|
fn action_json(action : Action) -> Json {
  match action {
    Keep => Json::string("keep")
    Empty => Json::string("empty")
    Remove => Json::string("remove")
    Replace(value) =>
      Json::object(Map::from_array([("replace", Json::string(value))]))
  }
}

///|
pub fn Policy::canonical_json(self : Policy) -> String {
  let rules = self.rules.copy()
  rules.sort_by(fn(a, b) { a.tag.compact().compare(b.tag.compact()) })
  let paths = self.path_rules.copy()
  paths.sort_by(fn(a, b) { a.id.compare(b.id) })
  let canonical = [
    Json::string(if self.strict_metadata { "strict-v1" } else { "research-v1" }),
    Json::string(self.scope_name),
    Json::number(self.date_shift_days.to_double()),
    Json::boolean(self.allow_external_references),
    Json::string(@dictionary.strict_dictionary_digest),
    Json::array(
      rules.map(fn(r) {
        Json::array([Json::string(r.tag.compact()), action_json(r.action)])
      }),
    ),
    Json::array(
      paths.map(fn(r) {
        Json::array([
          Json::string(r.id),
          Json::string(r.path),
          action_json(r.action),
          Json::number(r.priority.to_double()),
          match r.sop {
            None => Json::null()
            Some(s) => Json::string(s)
          },
          match r.present {
            None => Json::null()
            Some(t) => Json::string(t.compact())
          },
        ])
      }),
    ),
  ]
  if self.retain_dt {
    canonical.push(Json::string("retain-dt-precision-v1"))
  }
  Json::array(canonical).stringify()
}

///|
pub fn Policy::digest(self : Policy) -> String {
  @checksum.sha256(@utf8.encode(self.canonical_json()))
}

///|
pub fn Policy::name(self : Policy) -> String {
  if self.strict_metadata {
    "strict-v1"
  } else {
    "research-v1"
  }
}

///|
pub fn Policy::explain(self : Policy) -> String {
  Json::object(
    Map::from_array([
      ("profile", Json::string(self.name())),
      ("policy_sha256", Json::string(self.digest())),
      ("dictionary_sha256", Json::string(@dictionary.strict_dictionary_digest)),
      (
        "unknown_public_fields",
        Json::string(
          if self.strict_metadata {
            "reject"
          } else {
            "retained-subset-risk"
          },
        ),
      ),
      (
        "custom_rules",
        Json::array(
          self.path_rules.map(fn(r) {
            Json::object(
              Map::from_array([
                ("id", Json::string(r.id)),
                ("path", Json::string(r.path)),
                ("priority", Json::number(r.priority.to_double())),
              ]),
            )
          }),
        ),
      ),
    ]),
  ).stringify(indent=2)
}

///|
/// Public configuration excludes administrator IDs, namespace and replacement values.
pub fn Policy::public_explain(self : Policy) -> Json {
  let paths = self.path_rules.copy()
  paths.sort_by(fn(a, b) { a.id.compare(b.id) })
  Json::object(
    Map::from_array([
      ("profile", Json::string(self.name())),
      ("policy_sha256", Json::string(self.digest())),
      ("rulebook_sha256", Json::string(@rulebook.digest)),
      (
        "unknown_public_fields",
        Json::string(
          if self.strict_metadata {
            "reject"
          } else {
            "retained-subset-risk"
          },
        ),
      ),
      (
        "custom_rules",
        Json::array(
          paths.map(fn(rule) {
            Json::object(
              Map::from_array([
                ("path", Json::string(rule.path)),
                ("priority", Json::number(rule.priority.to_double())),
                (
                  "action",
                  Json::string(
                    match rule.action {
                      Keep => "keep"
                      Empty => "empty"
                      Remove => "remove"
                      Replace(_) => "replace"
                    },
                  ),
                ),
                ("has_sop_condition", Json::boolean(rule.sop is Some(_))),
                (
                  "has_presence_condition",
                  Json::boolean(rule.present is Some(_)),
                ),
              ]),
            )
          }),
        ),
      ),
    ]),
  )
}

///|
/// A parsed complete object is required to conclude that an absent tag is absent.
pub fn Policy::public_conditions(
  self : Policy,
  dataset : @model.DataSet,
  complete? : Bool = true,
) -> Json {
  let paths = self.path_rules.copy()
  paths.sort_by(fn(a, b) { a.id.compare(b.id) })
  Json::array(
    paths.map(fn(rule) {
      let sop = match rule.sop {
        None => @rulebook.Met
        Some(expected) => @rulebook.sop_condition(dataset, expected)
      }
      let present = match rule.present {
        None => @rulebook.Met
        Some(tag) => @rulebook.presence(dataset, tag, complete~)
      }
      Json::object(
        Map::from_array([
          ("rule_id", Json::string("policy-priority")),
          ("path", Json::string(rule.path)),
          ("sop", Json::string(sop.name())),
          ("presence", Json::string(present.name())),
          ("result", Json::string(sop.both(present).name())),
        ]),
      )
    }),
  )
}
