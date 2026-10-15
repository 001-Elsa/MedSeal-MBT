///|
pub let implicit_vr_little_endian_uid : String = "1.2.840.10008.1.2"

///|
/// Deliberately bounded dictionary. Never guess private/unknown/ambiguous VRs.
fn implicit_vr_of(tag : @model.Tag) -> @model.Vr raise @model.MedSealError {
  if tag == @model.pixel_data_tag {
    return @model.Vr::OW
  }
  match @dictionary.strict_attribute(tag) {
    Some(attribute) =>
      match @model.Vr::from_string(attribute.vr) {
        Some(vr) => vr
        None => raise @model.AmbiguousImplicitVr(tag)
      }
    None => raise @model.UnsupportedImplicitTag(tag)
  }
}
