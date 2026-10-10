// Generated dictionary data by tools/generate_strict_dictionary.py; see THIRD_PARTY.md.

///|
pub(all) struct Attribute {
  vr : String
  vm : String
  role : String
  name : String
}

///|
pub let strict_dictionary_digest : String = "ad82badfa7185b9c39f2c10ba43a2f85971bdcaccfd6aa690a0bfae00b28d236"

///|
pub fn strict_attribute(tag : @model.Tag) -> Attribute? {
  match (tag.group, tag.element) {
    (0x0008U, 0x0005U) =>
      Some({ vr: "CS", vm: "1-n", role: "keep", name: "SpecificCharacterSet", })
    (0x0008U, 0x0008U) =>
      Some({ vr: "CS", vm: "2-n", role: "keep", name: "ImageType", })
    (0x0008U, 0x0012U) =>
      Some({ vr: "DA", vm: "1", role: "remove", name: "InstanceCreationDate", })
    (0x0008U, 0x0013U) =>
      Some({ vr: "TM", vm: "1", role: "remove", name: "InstanceCreationTime", })
    (0x0008U, 0x0015U) =>
      Some({
        vr: "DT",
        vm: "1",
        role: "remove",
        name: "InstanceCoercionDateTime",
      })
    (0x0008U, 0x0016U) =>
      Some({ vr: "UI", vm: "1", role: "standard-uid", name: "SOPClassUID", })
    (0x0008U, 0x0018U) =>
      Some({ vr: "UI", vm: "1", role: "instance-uid", name: "SOPInstanceUID", })
    (0x0008U, 0x0020U) =>
      Some({ vr: "DA", vm: "1", role: "shift-da", name: "StudyDate", })
    (0x0008U, 0x0021U) =>
      Some({ vr: "DA", vm: "1", role: "shift-da", name: "SeriesDate", })
    (0x0008U, 0x0022U) =>
      Some({ vr: "DA", vm: "1", role: "shift-da", name: "AcquisitionDate", })
    (0x0008U, 0x0023U) =>
      Some({ vr: "DA", vm: "1", role: "shift-da", name: "ContentDate", })
    (0x0008U, 0x002AU) =>
      Some({ vr: "DT", vm: "1", role: "empty", name: "AcquisitionDateTime", })
    (0x0008U, 0x0030U) =>
      Some({ vr: "TM", vm: "1", role: "empty", name: "StudyTime", })
    (0x0008U, 0x0031U) =>
      Some({ vr: "TM", vm: "1", role: "empty", name: "SeriesTime", })
    (0x0008U, 0x0032U) =>
      Some({ vr: "TM", vm: "1", role: "empty", name: "AcquisitionTime", })
    (0x0008U, 0x0033U) =>
      Some({ vr: "TM", vm: "1", role: "empty", name: "ContentTime", })
    (0x0008U, 0x0050U) =>
      Some({ vr: "SH", vm: "1", role: "empty", name: "AccessionNumber", })
    (0x0008U, 0x0060U) =>
      Some({ vr: "CS", vm: "1", role: "keep", name: "Modality", })
    (0x0008U, 0x0064U) =>
      Some({ vr: "CS", vm: "1", role: "keep", name: "ConversionType", })
    (0x0008U, 0x0070U) =>
      Some({ vr: "LO", vm: "1", role: "empty", name: "Manufacturer", })
    (0x0008U, 0x0080U) =>
      Some({ vr: "LO", vm: "1", role: "empty", name: "InstitutionName", })
    (0x0008U, 0x0081U) =>
      Some({ vr: "ST", vm: "1", role: "empty", name: "InstitutionAddress", })
    (0x0008U, 0x0090U) =>
      Some({ vr: "PN", vm: "1", role: "empty", name: "ReferringPhysicianName", })
    (0x0008U, 0x0201U) =>
      Some({ vr: "SH", vm: "1", role: "remove", name: "TimezoneOffsetFromUTC", })
    (0x0008U, 0x1010U) =>
      Some({ vr: "SH", vm: "1", role: "remove", name: "StationName", })
    (0x0008U, 0x1030U) =>
      Some({ vr: "LO", vm: "1", role: "descriptive", name: "StudyDescription", })
    (0x0008U, 0x103EU) =>
      Some({
        vr: "LO",
        vm: "1",
        role: "descriptive",
        name: "SeriesDescription",
      })
    (0x0008U, 0x1040U) =>
      Some({
        vr: "LO",
        vm: "1",
        role: "remove",
        name: "InstitutionalDepartmentName",
      })
    (0x0008U, 0x1048U) =>
      Some({ vr: "PN", vm: "1-n", role: "empty", name: "PhysiciansOfRecord", })
    (0x0008U, 0x1050U) =>
      Some({
        vr: "PN",
        vm: "1-n",
        role: "empty",
        name: "PerformingPhysicianName",
      })
    (0x0008U, 0x1070U) =>
      Some({ vr: "PN", vm: "1-n", role: "empty", name: "OperatorsName", })
    (0x0008U, 0x1140U) =>
      Some({
        vr: "SQ",
        vm: "1",
        role: "sequence",
        name: "ReferencedImageSequence",
      })
    (0x0008U, 0x1150U) =>
      Some({
        vr: "UI",
        vm: "1",
        role: "standard-uid",
        name: "ReferencedSOPClassUID",
      })
    (0x0008U, 0x1155U) =>
      Some({
        vr: "UI",
        vm: "1",
        role: "instance-uid",
        name: "ReferencedSOPInstanceUID",
      })
    (0x0010U, 0x0010U) =>
      Some({ vr: "PN", vm: "1", role: "identity", name: "PatientName", })
    (0x0010U, 0x0020U) =>
      Some({ vr: "LO", vm: "1", role: "identity", name: "PatientID", })
    (0x0010U, 0x0021U) =>
      Some({ vr: "LO", vm: "1", role: "empty", name: "IssuerOfPatientID", })
    (0x0010U, 0x0030U) =>
      Some({ vr: "DA", vm: "1", role: "empty", name: "PatientBirthDate", })
    (0x0010U, 0x0040U) =>
      Some({ vr: "CS", vm: "1", role: "empty", name: "PatientSex", })
    (0x0010U, 0x1000U) =>
      Some({ vr: "LO", vm: "1-n", role: "empty", name: "OtherPatientIDs", })
    (0x0010U, 0x1001U) =>
      Some({ vr: "PN", vm: "1-n", role: "empty", name: "OtherPatientNames", })
    (0x0010U, 0x1010U) =>
      Some({ vr: "AS", vm: "1", role: "remove", name: "PatientAge", })
    (0x0010U, 0x1020U) =>
      Some({ vr: "DS", vm: "1", role: "remove", name: "PatientSize", })
    (0x0010U, 0x1030U) =>
      Some({ vr: "DS", vm: "1", role: "remove", name: "PatientWeight", })
    (0x0010U, 0x2160U) =>
      Some({ vr: "SH", vm: "1", role: "remove", name: "EthnicGroup", })
    (0x0010U, 0x21B0U) =>
      Some({
        vr: "LT",
        vm: "1",
        role: "remove",
        name: "AdditionalPatientHistory",
      })
    (0x0010U, 0x4000U) =>
      Some({ vr: "LT", vm: "1", role: "remove", name: "PatientComments", })
    (0x0018U, 0x0015U) =>
      Some({ vr: "CS", vm: "1", role: "remove", name: "BodyPartExamined", })
    (0x0018U, 0x0020U) =>
      Some({ vr: "CS", vm: "1-n", role: "keep", name: "ScanningSequence", })
    (0x0018U, 0x0021U) =>
      Some({ vr: "CS", vm: "1-n", role: "keep", name: "SequenceVariant", })
    (0x0018U, 0x0022U) =>
      Some({ vr: "CS", vm: "1-n", role: "keep", name: "ScanOptions", })
    (0x0018U, 0x0023U) =>
      Some({ vr: "CS", vm: "1", role: "keep", name: "MRAcquisitionType", })
    (0x0018U, 0x0050U) =>
      Some({ vr: "DS", vm: "1", role: "keep", name: "SliceThickness", })
    (0x0018U, 0x0060U) =>
      Some({ vr: "DS", vm: "1", role: "keep", name: "KVP", })
    (0x0018U, 0x0080U) =>
      Some({ vr: "DS", vm: "1", role: "keep", name: "RepetitionTime", })
    (0x0018U, 0x0081U) =>
      Some({ vr: "DS", vm: "1", role: "keep", name: "EchoTime", })
    (0x0018U, 0x0082U) =>
      Some({ vr: "DS", vm: "1", role: "keep", name: "InversionTime", })
    (0x0018U, 0x0083U) =>
      Some({ vr: "DS", vm: "1", role: "keep", name: "NumberOfAverages", })
    (0x0018U, 0x0084U) =>
      Some({ vr: "DS", vm: "1", role: "keep", name: "ImagingFrequency", })
    (0x0018U, 0x0085U) =>
      Some({ vr: "SH", vm: "1", role: "keep", name: "ImagedNucleus", })
    (0x0018U, 0x0086U) =>
      Some({ vr: "IS", vm: "1-n", role: "keep", name: "EchoNumbers", })
    (0x0018U, 0x0087U) =>
      Some({ vr: "DS", vm: "1", role: "keep", name: "MagneticFieldStrength", })
    (0x0018U, 0x0088U) =>
      Some({ vr: "DS", vm: "1", role: "keep", name: "SpacingBetweenSlices", })
    (0x0018U, 0x0089U) =>
      Some({
        vr: "IS",
        vm: "1",
        role: "keep",
        name: "NumberOfPhaseEncodingSteps",
      })
    (0x0018U, 0x0090U) =>
      Some({ vr: "DS", vm: "1", role: "keep", name: "DataCollectionDiameter", })
    (0x0018U, 0x0091U) =>
      Some({ vr: "IS", vm: "1", role: "keep", name: "EchoTrainLength", })
    (0x0018U, 0x0093U) =>
      Some({ vr: "DS", vm: "1", role: "keep", name: "PercentSampling", })
    (0x0018U, 0x0094U) =>
      Some({ vr: "DS", vm: "1", role: "keep", name: "PercentPhaseFieldOfView", })
    (0x0018U, 0x1000U) =>
      Some({ vr: "LO", vm: "1", role: "empty", name: "DeviceSerialNumber", })
    (0x0018U, 0x1002U) =>
      Some({ vr: "UI", vm: "1", role: "remove", name: "DeviceUID", })
    (0x0018U, 0x1004U) =>
      Some({ vr: "LO", vm: "1", role: "remove", name: "PlateID", })
    (0x0018U, 0x1030U) =>
      Some({ vr: "LO", vm: "1", role: "descriptive", name: "ProtocolName", })
    (0x0018U, 0x1310U) =>
      Some({ vr: "US", vm: "4", role: "keep", name: "AcquisitionMatrix", })
    (0x0018U, 0x1312U) =>
      Some({
        vr: "CS",
        vm: "1",
        role: "keep",
        name: "InPlanePhaseEncodingDirection",
      })
    (0x0018U, 0x1314U) =>
      Some({ vr: "DS", vm: "1", role: "keep", name: "FlipAngle", })
    (0x0018U, 0x1315U) =>
      Some({ vr: "CS", vm: "1", role: "keep", name: "VariableFlipAngleFlag", })
    (0x0018U, 0x5100U) =>
      Some({ vr: "CS", vm: "1", role: "keep", name: "PatientPosition", })
    (0x0020U, 0x000DU) =>
      Some({
        vr: "UI",
        vm: "1",
        role: "instance-uid",
        name: "StudyInstanceUID",
      })
    (0x0020U, 0x000EU) =>
      Some({
        vr: "UI",
        vm: "1",
        role: "instance-uid",
        name: "SeriesInstanceUID",
      })
    (0x0020U, 0x0010U) =>
      Some({ vr: "SH", vm: "1", role: "empty", name: "StudyID", })
    (0x0020U, 0x0011U) =>
      Some({ vr: "IS", vm: "1", role: "keep", name: "SeriesNumber", })
    (0x0020U, 0x0012U) =>
      Some({ vr: "IS", vm: "1", role: "keep", name: "AcquisitionNumber", })
    (0x0020U, 0x0013U) =>
      Some({ vr: "IS", vm: "1", role: "keep", name: "InstanceNumber", })
    (0x0020U, 0x0020U) =>
      Some({ vr: "CS", vm: "2", role: "keep", name: "PatientOrientation", })
    (0x0020U, 0x0032U) =>
      Some({ vr: "DS", vm: "3", role: "keep", name: "ImagePositionPatient", })
    (0x0020U, 0x0037U) =>
      Some({ vr: "DS", vm: "6", role: "keep", name: "ImageOrientationPatient", })
    (0x0020U, 0x0052U) =>
      Some({
        vr: "UI",
        vm: "1",
        role: "instance-uid",
        name: "FrameOfReferenceUID",
      })
    (0x0020U, 0x0060U) =>
      Some({ vr: "CS", vm: "1", role: "keep", name: "Laterality", })
    (0x0020U, 0x1040U) =>
      Some({
        vr: "LO",
        vm: "1",
        role: "keep",
        name: "PositionReferenceIndicator",
      })
    (0x0020U, 0x1041U) =>
      Some({ vr: "DS", vm: "1", role: "keep", name: "SliceLocation", })
    (0x0020U, 0x4000U) =>
      Some({ vr: "LT", vm: "1", role: "descriptive", name: "ImageComments", })
    (0x0028U, 0x0002U) =>
      Some({ vr: "US", vm: "1", role: "keep", name: "SamplesPerPixel", })
    (0x0028U, 0x0004U) =>
      Some({
        vr: "CS",
        vm: "1",
        role: "keep",
        name: "PhotometricInterpretation",
      })
    (0x0028U, 0x0006U) =>
      Some({ vr: "US", vm: "1", role: "keep", name: "PlanarConfiguration", })
    (0x0028U, 0x0008U) =>
      Some({ vr: "IS", vm: "1", role: "keep", name: "NumberOfFrames", })
    (0x0028U, 0x0009U) =>
      Some({ vr: "AT", vm: "1-n", role: "keep", name: "FrameIncrementPointer", })
    (0x0028U, 0x0010U) =>
      Some({ vr: "US", vm: "1", role: "keep", name: "Rows", })
    (0x0028U, 0x0011U) =>
      Some({ vr: "US", vm: "1", role: "keep", name: "Columns", })
    (0x0028U, 0x0030U) =>
      Some({ vr: "DS", vm: "2", role: "keep", name: "PixelSpacing", })
    (0x0028U, 0x0100U) =>
      Some({ vr: "US", vm: "1", role: "keep", name: "BitsAllocated", })
    (0x0028U, 0x0101U) =>
      Some({ vr: "US", vm: "1", role: "keep", name: "BitsStored", })
    (0x0028U, 0x0102U) =>
      Some({ vr: "US", vm: "1", role: "keep", name: "HighBit", })
    (0x0028U, 0x0103U) =>
      Some({ vr: "US", vm: "1", role: "keep", name: "PixelRepresentation", })
    (0x0028U, 0x0301U) =>
      Some({ vr: "CS", vm: "1", role: "keep", name: "BurnedInAnnotation", })
    (0x0028U, 0x1050U) =>
      Some({ vr: "DS", vm: "1-n", role: "keep", name: "WindowCenter", })
    (0x0028U, 0x1051U) =>
      Some({ vr: "DS", vm: "1-n", role: "keep", name: "WindowWidth", })
    (0x0028U, 0x1052U) =>
      Some({ vr: "DS", vm: "1", role: "keep", name: "RescaleIntercept", })
    (0x0028U, 0x1053U) =>
      Some({ vr: "DS", vm: "1", role: "keep", name: "RescaleSlope", })
    (0x0028U, 0x1054U) =>
      Some({ vr: "LO", vm: "1", role: "keep", name: "RescaleType", })
    (0x0028U, 0x2110U) =>
      Some({ vr: "CS", vm: "1", role: "keep", name: "LossyImageCompression", })
    (0x0028U, 0x2112U) =>
      Some({
        vr: "DS",
        vm: "1-n",
        role: "keep",
        name: "LossyImageCompressionRatio",
      })
    (0x0028U, 0x2114U) =>
      Some({
        vr: "CS",
        vm: "1-n",
        role: "keep",
        name: "LossyImageCompressionMethod",
      })
    (0x0032U, 0x1032U) =>
      Some({ vr: "PN", vm: "1", role: "empty", name: "RequestingPhysician", })
    (0x0040U, 0x0241U) =>
      Some({
        vr: "AE",
        vm: "1",
        role: "empty",
        name: "PerformedStationAETitle",
      })
    (0x0040U, 0x0275U) =>
      Some({
        vr: "SQ",
        vm: "1",
        role: "remove",
        name: "RequestAttributesSequence",
      })
    (0x0040U, 0x0555U) =>
      Some({
        vr: "SQ",
        vm: "1",
        role: "remove",
        name: "AcquisitionContextSequence",
      })
    (0x0400U, 0x0561U) =>
      Some({
        vr: "SQ",
        vm: "1",
        role: "remove",
        name: "OriginalAttributesSequence",
      })
    (0x7FE0U, 0x0010U) =>
      Some({ vr: "OB or OW", vm: "1", role: "keep", name: "PixelData", })
    (0xFFFCU, 0xFFFCU) =>
      Some({
        vr: "OB",
        vm: "1",
        role: "remove",
        name: "DataSetTrailingPadding",
      })
    _ => None
  }
}
