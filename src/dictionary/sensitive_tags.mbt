///|
pub(all) enum SensitiveRule {
  Replace(String)
  Empty
  KeepWithWarning(String, String)
} derive(Eq, Debug)

///|
pub fn sensitive_rule(tag : @model.Tag) -> SensitiveRule? {
  match (tag.group, tag.element) {
    (0x0010U, 0x0010U) => Some(Replace("ANONYMOUS"))
    (0x0010U, 0x0020U) => Some(Replace("MEDSEAL-ID"))
    (0x0010U, 0x0030U) => Some(Empty)
    (0x0010U, 0x0040U) => None
    (0x0010U, 0x1000U) => Some(Empty)
    (0x0010U, 0x1001U) => Some(Empty)
    (0x0008U, 0x0080U) => Some(Empty)
    (0x0008U, 0x0081U) => Some(Empty)
    (0x0008U, 0x0090U) => Some(Empty)
    (0x0008U, 0x1050U) => Some(Empty)
    (0x0008U, 0x1070U) => Some(Empty)
    (0x0008U, 0x1048U) => Some(Empty)
    (0x0008U, 0x1030U) =>
      Some(
        KeepWithWarning(
          "MEDSEAL-W103", "Study Description may contain sensitive text",
        ),
      )
    (0x0008U, 0x103EU) =>
      Some(
        KeepWithWarning(
          "MEDSEAL-W104", "Series Description may contain sensitive text",
        ),
      )
    (0x0018U, 0x1000U) => Some(Empty)
    (0x0018U, 0x1030U) =>
      Some(
        KeepWithWarning(
          "MEDSEAL-W107", "Protocol Name may contain sensitive text",
        ),
      )
    (0x0032U, 0x1032U) => Some(Empty)
    (0x0040U, 0x0241U) => Some(Empty)
    _ => None
  }
}
