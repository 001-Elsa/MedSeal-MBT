///|
pub using @model {
  type DataSet,
  type DataElement,
  type ElementValue,
  type Tag,
  type Vr,
  type MedSealError,
}

///|
pub using @parser {type ParsedFile}

///|
/// Parsing alone neither validates an IOD nor authorizes disclosure.
pub fn parse(bytes : Bytes) -> ParsedFile raise MedSealError {
  @parser.parse(bytes)
}

///|
pub fn write(file : ParsedFile, dataset? : DataSet) -> Bytes raise MedSealError {
  match dataset {
    Some(value) => @dicom_writer.write_bytes(file, dataset=value)
    None => @dicom_writer.write_bytes(file)
  }
}
