///|
pub fn tag_name(tag : @model.Tag) -> String {
  match (tag.group, tag.element) {
    (0x0002U, 0x0000U) => "FileMetaInformationGroupLength"
    (0x0002U, 0x0002U) => "MediaStorageSOPClassUID"
    (0x0002U, 0x0003U) => "MediaStorageSOPInstanceUID"
    (0x0002U, 0x0010U) => "TransferSyntaxUID"
    (0x0002U, 0x0012U) => "ImplementationClassUID"
    (0x0008U, 0x0016U) => "SOPClassUID"
    (0x0008U, 0x0018U) => "SOPInstanceUID"
    (0x0008U, 0x0080U) => "InstitutionName"
    (0x0008U, 0x0081U) => "InstitutionAddress"
    (0x0008U, 0x0090U) => "ReferringPhysicianName"
    (0x0008U, 0x1030U) => "StudyDescription"
    (0x0008U, 0x103EU) => "SeriesDescription"
    (0x0008U, 0x1048U) => "PhysiciansOfRecord"
    (0x0008U, 0x1050U) => "PerformingPhysicianName"
    (0x0008U, 0x1070U) => "OperatorsName"
    (0x0010U, 0x0010U) => "PatientName"
    (0x0010U, 0x0020U) => "PatientID"
    (0x0010U, 0x0030U) => "PatientBirthDate"
    (0x0010U, 0x0040U) => "PatientSex"
    (0x0010U, 0x1000U) => "OtherPatientIDs"
    (0x0010U, 0x1001U) => "OtherPatientNames"
    (0x0018U, 0x1000U) => "DeviceSerialNumber"
    (0x0018U, 0x1030U) => "ProtocolName"
    (0x0020U, 0x000DU) => "StudyInstanceUID"
    (0x0020U, 0x000EU) => "SeriesInstanceUID"
    (0x0028U, 0x0002U) => "SamplesPerPixel"
    (0x0028U, 0x0010U) => "Rows"
    (0x0028U, 0x0011U) => "Columns"
    (0x0028U, 0x0100U) => "BitsAllocated"
    (0x0028U, 0x0101U) => "BitsStored"
    (0x0028U, 0x0103U) => "PixelRepresentation"
    (0x0032U, 0x1032U) => "RequestingPhysician"
    (0x0040U, 0x0241U) => "PerformedStationAETitle"
    (0x7FE0U, 0x0010U) => "PixelData"
    _ => "Unknown"
  }
}

///|
pub fn patient_name_tag() -> @model.Tag {
  @model.Tag::new(0x0010U, 0x0010U)
}

///|
pub fn patient_id_tag() -> @model.Tag {
  @model.Tag::new(0x0010U, 0x0020U)
}
