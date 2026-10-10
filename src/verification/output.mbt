///|
pub fn same_values(left : @model.DataSet, right : @model.DataSet) -> Bool {
  if left.elements.length() != right.elements.length() {
    return false
  }
  for index, a in left.elements {
    let b = right.elements[index]
    if a.tag != b.tag || a.vr != b.vr {
      return false
    }
    match (a.value, b.value) {
      (@model.ElementValue::Sequence(xs), @model.ElementValue::Sequence(ys)) => {
        if xs.length() != ys.length() {
          return false
        }
        for i, x in xs {
          if !same_values(x, ys[i]) {
            return false
          }
        }
      }
      _ if a.value != b.value => return false
      _ => ()
    }
  }
  true
}

///|
fn unique_tags(dataset : @model.DataSet) -> Unit raise @model.MedSealError {
  let seen : Map[@model.Tag, Bool] = Map([])
  for element in dataset.elements {
    if seen.contains(element.tag) {
      raise @model.MedSealError::IdentityError("duplicate element tag")
    }
    seen.set(element.tag, true)
    match element.value {
      @model.ElementValue::Sequence(items) =>
        for item in items {
          unique_tags(item)
        }
      _ => ()
    }
  }
}

///|
pub fn check_unique_tags(
  dataset : @model.DataSet,
) -> Unit raise @model.MedSealError {
  unique_tags(dataset)
}

///|
pub fn clean_private(dataset : @model.DataSet) -> Bool {
  dataset.elements.all(fn(element) {
    !element.tag.is_private() &&
    (match element.value {
      @model.ElementValue::Sequence(items) => items.all(clean_private)
      _ => true
    })
  })
}
