///|
pub(all) enum ElementValue {
  Text(String)
  UnsignedShort(Array[UInt])
  SignedShort(Array[Int])
  UnsignedLong(Array[UInt])
  SignedLong(Array[Int])
  Sequence(Array[DataSet])
  Raw(Bytes)
  Empty
} derive(Eq, Debug)

///|
pub extend ElementValue with Eq::{equal, not_equal}

///|
pub extend ElementValue with Debug::{to_repr}
