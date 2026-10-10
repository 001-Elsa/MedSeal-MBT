///|
pub struct DataSet {
  elements : Array[DataElement]
} derive(Eq, Debug)

///|
pub fn DataSet::new(elements : Array[DataElement]) -> DataSet {
  { elements, }
}

///|
pub fn DataSet::empty() -> DataSet {
  { elements: [], }
}

///|
pub fn DataSet::canonical(self : DataSet) -> DataSet {
  let elements = self.elements.map(fn(element) {
    match element.value {
      Sequence(items) =>
        { ..element, value: Sequence(items.map(DataSet::canonical)), }
      _ => element
    }
  })
  elements.sort_by(fn(a, b) {
    if a.tag.group != b.tag.group {
      a.tag.group.compare(b.tag.group)
    } else {
      a.tag.element.compare(b.tag.element)
    }
  })
  DataSet::new(elements)
}

///|
pub fn DataSet::find(self : DataSet, tag : Tag) -> DataElement? {
  match self.elements.search_by(fn(element) { element.tag == tag }) {
    Some(index) => Some(self.elements[index])
    None => None
  }
}

///|
pub fn DataSet::remove(self : DataSet, tag : Tag) -> DataSet {
  DataSet::new(self.elements.filter(fn(element) { element.tag != tag }))
}

///|
pub fn DataSet::replace_text(
  self : DataSet,
  tag : Tag,
  value : String,
) -> DataSet {
  DataSet::new(
    self.elements.map(fn(element) {
      if element.tag == tag {
        DataElement::new(
          element.tag,
          element.vr,
          value.length().reinterpret_as_uint(),
          Text(value),
          element.original_order,
        )
      } else {
        element
      }
    }),
  )
}

///|
pub fn DataSet::count_recursive(self : DataSet) -> Int {
  let mut count = 0
  for element in self.elements {
    count = count + 1
    match element.value {
      Sequence(items) =>
        for item in items {
          count = count + item.count_recursive()
        }
      _ => ()
    }
  }
  count
}

///|
pub extend DataSet with Eq::{equal, not_equal}

///|
pub extend DataSet with Debug::{to_repr}
