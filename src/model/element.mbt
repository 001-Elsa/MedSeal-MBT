///|
pub struct DataElement {
  tag : Tag
  vr : Vr
  value_length : UInt
  value : ElementValue
  original_order : Int
  original_bytes : Bytes?
} derive(Eq, Debug)

///|
pub fn DataElement::new(
  tag : Tag,
  vr : Vr,
  value_length : UInt,
  value : ElementValue,
  original_order : Int,
  original_bytes? : Bytes? = None,
) -> DataElement {
  { tag, vr, value_length, value, original_order, original_bytes, }
}

///|
pub extend DataElement with Eq::{equal, not_equal}

///|
pub extend DataElement with Debug::{to_repr}
