///|
pub(all) suberror MedSealError {
  FileTooSmall
  MissingDicmMarker
  UnexpectedEndOfFile(Int)
  UnsupportedTransferSyntax(String)
  MissingRequiredFileMeta(Tag)
  InvalidFileMetaGroupLength(UInt, UInt)
  InvalidVr(String, Int)
  InvalidLength(Tag, UInt, Int)
  InvalidSequence(Int)
  ExcessiveNesting(Int)
  PixelDataTruncated
  TooManyElements(Int)
  ElementTooLarge(UInt, Int)
  FileTooLarge(Int)
  OutputAlreadyExists(String)
  IoError(String)
  OutputVerificationFailed(String)
  InvalidArgument(String)
  UnsupportedCharacterSet
  InvalidTextEncoding
  InvalidModel(String)
  PolicyError(String)
  IdentityError(String)
  RuleViolation(String, String, String, String)
} derive(Debug)

///|
pub fn MedSealError::code(self : MedSealError) -> String {
  match self {
    FileTooSmall => "MEDSEAL-E101"
    MissingDicmMarker => "MEDSEAL-E102"
    UnsupportedTransferSyntax(_) => "MEDSEAL-E103"
    MissingRequiredFileMeta(_) => "MEDSEAL-E104"
    InvalidFileMetaGroupLength(_, _) => "MEDSEAL-E105"
    UnexpectedEndOfFile(_) => "MEDSEAL-E201"
    InvalidVr(_, _) => "MEDSEAL-E202"
    InvalidLength(_, _, _) | ElementTooLarge(_, _) => "MEDSEAL-E203"
    InvalidSequence(_) => "MEDSEAL-E204"
    ExcessiveNesting(_) => "MEDSEAL-E205"
    PixelDataTruncated => "MEDSEAL-E206"
    TooManyElements(_) | FileTooLarge(_) => "MEDSEAL-E207"
    OutputAlreadyExists(_) => "MEDSEAL-E301"
    IoError(_) => "MEDSEAL-E302"
    OutputVerificationFailed(_) => "MEDSEAL-E401"
    InvalidArgument(_) => "MEDSEAL-E501"
    UnsupportedCharacterSet => "MEDSEAL-E108"
    InvalidTextEncoding => "MEDSEAL-E109"
    InvalidModel(_) => "MEDSEAL-E402"
    PolicyError(_) => "MEDSEAL-E510"
    IdentityError(_) => "MEDSEAL-E520"
    RuleViolation(_, _, _, _) => "MEDSEAL-E530"
  }
}

///|
pub fn MedSealError::message(self : MedSealError) -> String {
  match self {
    FileTooSmall => "file is smaller than the 132-byte DICOM Part 10 header"
    MissingDicmMarker => "missing DICM marker at offset 128"
    UnexpectedEndOfFile(offset) => "unexpected end of file at offset \{offset}"
    UnsupportedTransferSyntax(uid) =>
      "unsupported transfer syntax: \{uid}\nOnly Explicit VR Little Endian is supported in version \{medseal_version}."
    MissingRequiredFileMeta(tag) =>
      "missing required File Meta Information element \{tag.to_string()}"
    InvalidFileMetaGroupLength(declared, actual) =>
      "File Meta Information Group Length declares \{declared} bytes but \{actual} bytes were parsed"
    InvalidVr(vr, offset) => "invalid VR '\{vr}' at offset \{offset}"
    InvalidLength(tag, length, offset) =>
      "element length \{length} exceeds remaining file size at offset \{offset}, tag \{tag.to_string()}"
    InvalidSequence(offset) => "invalid sequence structure at offset \{offset}"
    ExcessiveNesting(depth) =>
      "sequence nesting depth \{depth} exceeds limit 32"
    PixelDataTruncated => "pixel data is truncated"
    TooManyElements(count) => "element count \{count} exceeds limit 100000"
    ElementTooLarge(length, offset) =>
      "element length \{length} exceeds 128 MiB limit at offset \{offset}"
    FileTooLarge(length) => "file size \{length} exceeds 256 MiB limit"
    OutputAlreadyExists(_) => "output destination already exists"
    IoError(message) => "file I/O failed: \{message}"
    OutputVerificationFailed(message) =>
      "write-back verification failed: \{message}"
    InvalidArgument(message) => message
    UnsupportedCharacterSet =>
      "only default ASCII and ISO_IR 192 character sets are supported"
    InvalidTextEncoding =>
      "text bytes are invalid for the declared character set"
    InvalidModel(message) => "cannot serialize data model: \{message}"
    PolicyError(message) => "invalid de-identification policy: \{message}"
    IdentityError(message) => "identity consistency check failed: \{message}"
    RuleViolation(_, _, _, _) =>
      "declared rule validation failed; use the public explanation API for a safe field location"
  }
}

///|
pub fn MedSealError::display(self : MedSealError) -> String {
  "\{self.code()}: \{self.message()}"
}

///|
pub extend MedSealError with Debug::{to_repr}
