///|
pub struct Event {
  path : String
  rule : String
  action : String
}

///|
pub struct Result {
  dataset : @model.DataSet
  events : Array[Event]
}

///|
/// Private pinned-producer audit replay; this is not a validation or review grant.
pub fn Context::restore_cached(
  self : Context,
  dataset : @model.DataSet,
  audit : String,
) -> Result raise @model.MedSealError {
  if !self.ready || !self.is_strict() {
    raise @model.MedSealError::IdentityError("invalid cached context")
  }
  let root = match (@json.parse(audit) catch { _ => Json::null() }) {
    Json::Object(fields) => fields
    _ => raise @model.MedSealError::IdentityError("invalid cached audit")
  }
  if root.get("policy_sha256") != Some(Json::string(self.policy.digest())) ||
    root.get("conversion") != Some(Json::string("verified")) ||
    root.get("pixel_bytes_preserved") != Some(Json::boolean(true)) ||
    root.get("pixels_inspected") != Some(Json::boolean(false)) {
    raise @model.MedSealError::IdentityError("cached audit binding differs")
  }
  let rows = match root.get("events") {
    Some(Json::Array(rows)) if rows.length() <= 100000 => rows
    _ => raise @model.MedSealError::IdentityError("invalid cached event count")
  }
  let events = rows.map(row => {
    let fields = match row {
      Json::Object(fields) if fields.length() == 3 => fields
      _ => raise @model.MedSealError::IdentityError("invalid cached event")
    }
    let field = fn(name) -> String raise @model.MedSealError {
      match fields.get(name) {
        Some(Json::String(value)) => value
        _ =>
          raise @model.MedSealError::IdentityError("invalid cached event field")
      }
    }
    { path: field("path"), rule: field("rule"), action: field("action"), }
  })
  { dataset, events, }
}

///|
fn replace(element : @model.DataElement, value : String) -> @model.DataElement {
  @model.DataElement::new(
    element.tag,
    element.vr,
    @utf8.encode(value).length().reinterpret_as_uint(),
    if value.is_empty() {
      @model.ElementValue::Empty
    } else {
      @model.ElementValue::Text(value)
    },
    element.original_order,
  )
}

///|
fn transform(
  context : Context,
  dataset : @model.DataSet,
  patient : String,
  path : String,
  events : Array[Event],
  sop : String,
) -> @model.DataSet raise @model.MedSealError {
  let result : Array[@model.DataElement] = []
  let basic = @deid.basic_policy()
  let retain_zone = context.policy.retain_dt &&
    (match text(dataset, @model.Tag::new(0x0008U, 0x002AU)) {
      Some(value) =>
        match @date.parse_dt(value) {
          Some(temporal) =>
            temporal.precision >= 8 &&
            temporal.zone_minutes is None &&
            !temporal.leap_second
          None => false
        }
      None => false
    })
  for element in dataset.elements {
    let location = "\{path}/\{element.tag.compact()}"
    let mut action = "keep"
    let mut rule = "retain-supported"
    if element.tag.is_private() ||
      element.tag.element == 0x0000U ||
      element.tag == @model.Tag::new(0x0008U, 0x0001U) {
      events.push({
        path: location,
        rule: "remove-private-or-obsolete-length",
        action: "remove",
      })
      continue
    }
    let strict_attribute = @dictionary.strict_attribute(element.tag)
    if context.policy.strict_metadata {
      if element.tag.group == 0x0400U ||
        element.tag.group == 0xFFFAU ||
        element.tag.group == 0xFFFCU ||
        (element.tag.group >= 0x6000U && element.tag.group <= 0x60FFU) ||
        (
          strict_attribute.map(fn(a) { a.role }) == Some("remove") &&
          !(retain_zone && element.tag == @model.Tag::new(0x0008U, 0x0201U))
        ) {
        events.push({
          path: location,
          rule: "strict-remove-sensitive-structure",
          action: "remove",
        })
        continue
      }
      if strict_attribute is None {
        raise @model.MedSealError::PolicyError("unclassified public field")
      }
    }
    let output = match element.value {
      @model.Text(value) if context.policy.retain_dt &&
        element.tag == @model.Tag::new(0x0008U, 0x002AU) => {
        let shifted = @date.shift_dt(value, context.date_offset(patient))
        action = if shifted.is_empty() { "empty" } else { "shift" }
        rule = "precision-preserving-dt"
        replace(element, shifted)
      }
      _ if retain_zone && element.tag == @model.Tag::new(0x0008U, 0x0201U) => {
        action = "keep"
        rule = "retained-timezone-context"
        element
      }
      @model.ElementValue::Sequence(items) => {
        action = "recurse"
        rule = "reference-sequence"
        let nested : Array[@model.DataSet] = []
        for index, item in items {
          nested.push(
            transform(
              context,
              item,
              patient,
              "\{location}[\{index}]",
              events,
              sop,
            ),
          )
        }
        @model.DataElement::new(
          element.tag,
          element.vr,
          0U,
          @model.ElementValue::Sequence(nested),
          element.original_order,
        )
      }
      @model.ElementValue::Text(value) if instance_uid(element.tag) => {
        if element.vr != @model.Vr::UI {
          raise @model.MedSealError::IdentityError("identity UID has wrong VR")
        }
        let mapped : Array[String] = []
        for uid in value.split("\\") {
          mapped.push(context.mapped_uid(uid.to_owned()))
        }
        action = "remap"
        rule = "identity-uid"
        replace(element, mapped.join("\\"))
      }
      @model.ElementValue::Text(value) if shifted_date(element.tag) => {
        if element.vr != @model.Vr::DA {
          raise @model.MedSealError::IdentityError("selected date has wrong VR")
        }
        let values : Array[String] = []
        for date in value.split("\\") {
          values.push(
            @date.shift(date.to_owned(), context.date_offset(patient)),
          )
        }
        action = "shift"
        rule = "full-date-offset"
        replace(element, values.join("\\"))
      }
      _ if element.tag == @model.Tag::new(0x0010U, 0x0010U) ||
        element.tag == @model.Tag::new(0x0010U, 0x0020U) => {
        if element.vr !=
          (if element.tag.element == 0x0010U {
            @model.Vr::PN
          } else {
            @model.Vr::LO
          }) {
          raise @model.MedSealError::IdentityError(
            "patient identity has wrong VR",
          )
        }
        action = "replace"
        rule = "patient-pseudonym"
        replace(
          element,
          if context.policy.strict_metadata && element.vr == @model.Vr::PN {
            patient + "^"
          } else {
            patient
          },
        )
      }
      _ => {
        let selected = context.policy.path_action(location, sop, dataset)
        let configured = match selected {
          Some((_, action)) => Some(action)
          None if context.policy.strict_metadata &&
            strict_attribute.map(fn(a) { a.role }) == Some("empty") =>
            Some(@policy.Action::Empty)
          None if context.policy.strict_metadata &&
            strict_attribute.map(fn(a) { a.role }) == Some("descriptive") =>
            Some(@policy.Action::Empty)
          None => context.policy.action(element.tag)
        }
        match configured {
          Some(@policy.Action::Remove) => {
            events.push({
              path: location,
              rule: selected.map(fn(s) { s.0 }).unwrap_or("custom-descriptive"),
              action: "remove",
            })
            continue
          }
          Some(@policy.Action::Empty) => {
            action = "empty"
            rule = selected
              .map(fn(s) { s.0 })
              .unwrap_or("strict-empty-or-descriptive")
            replace(element, "")
          }
          Some(@policy.Action::Replace(value)) => {
            if !element.vr.is_text() {
              raise @model.MedSealError::PolicyError(
                "text replacement applied to non-text VR",
              )
            }
            action = "replace"
            rule = selected.map(fn(s) { s.0 }).unwrap_or("custom-descriptive")
            replace(element, value)
          }
          Some(@policy.Action::Keep) => element
          None =>
            if element.tag == @model.Tag::new(0x0010U, 0x0021U) ||
              element.tag == @model.Tag::new(0x0008U, 0x0050U) ||
              element.tag == @model.Tag::new(0x0018U, 0x1000U) {
              action = "empty"
              rule = "direct-identifier"
              replace(element, "")
            } else {
              match basic.get(element.tag) {
                Some(@deid.DeIdAction::Empty) => {
                  action = "empty"
                  rule = "direct-identifier"
                  replace(element, "")
                }
                Some(@deid.DeIdAction::Remove) => {
                  events.push({
                    path: location,
                    rule: "direct-identifier",
                    action: "remove",
                  })
                  continue
                }
                _ => element
              }
            }
        }
      }
    }
    if action != "keep" || context.policy.strict_metadata {
      events.push({ path: location, rule, action, })
    }
    result.push(output)
  }
  @model.DataSet::new(result)
}

///|
pub fn Context::apply(
  self : Context,
  dataset : @model.DataSet,
) -> Result raise @model.MedSealError {
  if text(dataset, @model.Tag::new(0x0012U, 0x0063U)) is Some(_) ||
    text(dataset, @model.Tag::new(0x0012U, 0x0062U)) == Some("YES") {
    raise @model.MedSealError::IdentityError(
      "already processed dataset; refusing another date shift",
    )
  }
  let patient = self.patient(dataset)
  if self.policy.strict_metadata {
    @conformance.check(dataset)
  }
  let events : Array[Event] = []
  let output = transform(
    self,
    dataset,
    patient,
    "dataset",
    events,
    required_text(dataset, @model.Tag::new(0x0008U, 0x0016U)),
  )
  // A method marker supports double-processing detection. A YES declaration of
  // complete identity removal is deliberately omitted for this limited profile.
  let marker = @model.DataElement::new(
    @model.Tag::new(0x0012U, 0x0063U),
    @model.Vr::LO,
    0U,
    @model.ElementValue::Text(
      "MedSeal \{self.policy.name()}; metadata subset; pixels unchecked",
    ),
    output.elements.length(),
  )
  { dataset: @model.DataSet::new(output.elements + [marker]), events, }
}
