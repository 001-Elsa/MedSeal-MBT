///|
pub let explicit_vr_little_endian_uid : String = "1.2.840.10008.1.2.1"

///|
pub(all) struct ParsedFile {
  preamble : Bytes
  file_meta : @model.DataSet
  dataset : @model.DataSet
  transfer_syntax : String
  element_count : Int
} derive(Eq, Debug)
