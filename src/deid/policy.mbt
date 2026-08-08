///|
pub fn basic_policy() -> Map[@model.Tag, DeIdAction] {
  Map::from_array([
    (@model.Tag::new(0x0010U, 0x0010U), Replace("ANONYMOUS")),
    (@model.Tag::new(0x0010U, 0x0020U), Replace("MEDSEAL-ID")),
    (@model.Tag::new(0x0010U, 0x0030U), Empty),
    (@model.Tag::new(0x0010U, 0x0040U), Keep),
    (@model.Tag::new(0x0010U, 0x1000U), Empty),
    (@model.Tag::new(0x0010U, 0x1001U), Empty),
    (@model.Tag::new(0x0008U, 0x0080U), Empty),
    (@model.Tag::new(0x0008U, 0x0081U), Empty),
    (@model.Tag::new(0x0008U, 0x0090U), Empty),
    (@model.Tag::new(0x0008U, 0x1050U), Empty),
    (@model.Tag::new(0x0008U, 0x1070U), Empty),
    (@model.Tag::new(0x0008U, 0x1048U), Empty),
    (@model.Tag::new(0x0008U, 0x1030U), Keep),
    (@model.Tag::new(0x0008U, 0x103EU), Keep),
    (@model.Tag::new(0x0018U, 0x1000U), Empty),
    (@model.Tag::new(0x0018U, 0x1030U), Keep),
    (@model.Tag::new(0x0032U, 0x1032U), Empty),
    (@model.Tag::new(0x0040U, 0x0241U), Empty),
  ])
}
