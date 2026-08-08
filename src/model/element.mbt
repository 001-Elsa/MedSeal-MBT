///|
pub struct DataElement {
  tag : Tag
  vr : Vr
  value_length : UInt
  value : ElementValue
  original_order : Int
} derive(Eq, Debug)

///|
pub fn DataElement::new(
  tag : Tag,
  vr : Vr,
  value_length : UInt,
  value : ElementValue,
  original_order : Int,
) -> DataElement {
  { tag, vr, value_length, value, original_order }
}
