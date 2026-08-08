///|
priv struct MutableAudit {
  mut changed : Int
  mut removed : Int
  mut private_removed : Int
  mut private_retained : Int
  changes : Array[AuditEvent]
  warnings : Array[AuditWarning]
}

///|
fn push_warning_once(
  audit : MutableAudit,
  code : String,
  message : String,
) -> Unit {
  if !audit.warnings.any(fn(warning) { warning.code == code }) {
    audit.warnings.push({ code, message })
  }
}

///|
fn changed_element(
  element : @model.DataElement,
  action : DeIdAction,
) -> @model.DataElement {
  match action {
    Replace(value) =>
      @model.DataElement::new(
        element.tag,
        element.vr,
        @utf8.encode(value).length().reinterpret_as_uint(),
        @model.ElementValue::Text(value),
        element.original_order,
      )
    Empty =>
      @model.DataElement::new(
        element.tag,
        element.vr,
        0U,
        @model.ElementValue::Empty,
        element.original_order,
      )
    _ => element
  }
}

///|
fn action_changes(element : @model.DataElement, action : DeIdAction) -> Bool {
  match action {
    Keep => false
    Remove => true
    Empty => element.value != @model.ElementValue::Empty
    Replace(value) =>
      match element.value {
        @model.ElementValue::Text(current) => current != value
        _ => true
      }
  }
}

///|
fn anonymize_dataset(
  dataset : @model.DataSet,
  policy : Map[@model.Tag, DeIdAction],
  remove_private : Bool,
  audit : MutableAudit,
) -> @model.DataSet {
  let output : Array[@model.DataElement] = []
  for element in dataset.elements {
    if element.tag == @model.pixel_data_tag {
      output.push(element)
      continue
    }
    if remove_private && element.tag.is_private() {
      audit.removed = audit.removed + 1
      audit.private_removed = audit.private_removed + 1
      audit.changes.push({
        tag: element.tag.compact(),
        name: @dictionary.tag_name(element.tag),
        action: "remove",
      })
      continue
    }
    if element.tag.is_private() {
      audit.private_retained = audit.private_retained + 1
    }
    match policy.get(element.tag) {
      Some(Keep) => {
        match @dictionary.sensitive_rule(element.tag) {
          Some(@dictionary.SensitiveRule::KeepWithWarning(code, message)) =>
            push_warning_once(audit, code, message)
          _ => ()
        }
        match element.value {
          @model.ElementValue::Sequence(items) => {
            let nested = items.map(fn(item) {
              anonymize_dataset(item, policy, remove_private, audit)
            })
            output.push(
              @model.DataElement::new(
                element.tag,
                element.vr,
                element.value_length,
                @model.ElementValue::Sequence(nested),
                element.original_order,
              ),
            )
          }
          _ => output.push(element)
        }
      }
      Some(Remove) => {
        audit.removed = audit.removed + 1
        audit.changes.push({
          tag: element.tag.compact(),
          name: @dictionary.tag_name(element.tag),
          action: "remove",
        })
      }
      Some(action) =>
        if action_changes(element, action) {
          audit.changed = audit.changed + 1
          audit.changes.push({
            tag: element.tag.compact(),
            name: @dictionary.tag_name(element.tag),
            action: action.name(),
          })
          output.push(changed_element(element, action))
        } else {
          output.push(element)
        }
      None =>
        match element.value {
          @model.ElementValue::Sequence(items) => {
            let nested = items.map(fn(item) {
              anonymize_dataset(item, policy, remove_private, audit)
            })
            output.push(
              @model.DataElement::new(
                element.tag,
                element.vr,
                element.value_length,
                @model.ElementValue::Sequence(nested),
                element.original_order,
              ),
            )
          }
          _ => output.push(element)
        }
    }
  }
  @model.DataSet::new(output)
}

///|
pub fn anonymize(
  dataset : @model.DataSet,
  remove_private? : Bool = false,
) -> AnonymizeResult {
  let audit : MutableAudit = {
    changed: 0,
    removed: 0,
    private_removed: 0,
    private_retained: 0,
    changes: [],
    warnings: [],
  }
  let output = anonymize_dataset(dataset, basic_policy(), remove_private, audit)
  if audit.private_retained > 0 {
    push_warning_once(
      audit, "MEDSEAL-W102", "Private elements were retained and may contain identifying information",
    )
  }
  push_warning_once(audit, "MEDSEAL-W105", "UID values were retained")
  push_warning_once(audit, "MEDSEAL-W106", "Pixel data was not inspected")
  {
    dataset: output,
    elements_changed: audit.changed,
    elements_removed: audit.removed,
    private_elements_removed: audit.private_removed,
    changes: audit.changes,
    warnings: audit.warnings,
  }
}
