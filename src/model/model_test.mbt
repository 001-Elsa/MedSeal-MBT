///|
test "Tag formats and identifies private groups" {
  assert_eq(@model.Tag::new(0x0010U, 0x0010U).to_string(), "(0010,0010)")
  assert_false(@model.Tag::new(0x0010U, 0x0010U).is_private())
  assert_true(@model.Tag::new(0x0011U, 0x0010U).is_private())
}

///|
test "VR parsing recognizes supported values" {
  assert_true(@model.Vr::from_string("PN") is Some(PN))
  assert_true(@model.Vr::from_string("SQ") is Some(SQ))
  assert_true(@model.Vr::from_string("ZZ") is None)
  assert_true(@model.Vr::OW.uses_u32_length())
}
