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
) -> @model.DataSet raise @model.MedSealError {
  let result : Array[@model.DataElement] = []
  let basic = @deid.basic_policy()
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
    let output = match element.value {
      @model.ElementValue::Sequence(items) => {
        let nested : Array[@model.DataSet] = []
        for index, item in items {
          nested.push(
            transform(context, item, patient, "\{location}[\{index}]", events),
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
        replace(element, patient)
      }
      _ => {
        let configured = context.policy.action(element.tag)
        match configured {
          Some(@policy.Action::Remove) => {
            events.push({
              path: location,
              rule: "custom-descriptive",
              action: "remove",
            })
            continue
          }
          Some(@policy.Action::Empty) => {
            action = "empty"
            rule = "descriptive"
            replace(element, "")
          }
          Some(@policy.Action::Replace(value)) => {
            if !element.vr.is_text() {
              raise @model.MedSealError::PolicyError(
                "text replacement applied to non-text VR",
              )
            }
            action = "replace"
            rule = "custom-descriptive"
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
    if action != "keep" {
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
  let events : Array[Event] = []
  let output = transform(self, dataset, patient, "dataset", events)
  // A method marker supports double-processing detection. A YES declaration of
  // complete identity removal is deliberately omitted for this limited profile.
  let marker = @model.DataElement::new(
    @model.Tag::new(0x0012U, 0x0063U),
    @model.Vr::LO,
    0U,
    @model.ElementValue::Text(
      "MedSeal research-v1; metadata subset; pixels unchecked",
    ),
    output.elements.length(),
  )
  { dataset: @model.DataSet::new(output.elements + [marker]), events, }
}
