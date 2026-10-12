// Generated from reviewed catalog. Runs the production field checker.

///|
test "every reviewed attribute accepts its declared VR and rejects another VR" {
  // rule-00080005-valid-field; rule-00080005-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0005U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::CS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00080008-valid-field; rule-00080008-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0008U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::CS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00080012-valid-field; rule-00080012-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0012U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DA,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remove")
  // rule-00080013-valid-field; rule-00080013-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0013U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::TM,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remove")
  // rule-00080015-valid-field; rule-00080015-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0015U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DT,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remove")
  // rule-00080016-valid-field; rule-00080016-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0016U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::UI,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00080018-valid-field; rule-00080018-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0018U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::UI,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remap")
  // rule-00080020-valid-field; rule-00080020-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0020U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DA,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "shift")
  // rule-00080021-valid-field; rule-00080021-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0021U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DA,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "shift")
  // rule-00080022-valid-field; rule-00080022-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0022U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DA,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "shift")
  // rule-00080023-valid-field; rule-00080023-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0023U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DA,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "shift")
  // rule-0008002A-valid-field; rule-0008002A-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x002AU)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DT,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00080030-valid-field; rule-00080030-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0030U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::TM,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00080031-valid-field; rule-00080031-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0031U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::TM,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00080032-valid-field; rule-00080032-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0032U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::TM,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00080033-valid-field; rule-00080033-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0033U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::TM,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00080050-valid-field; rule-00080050-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0050U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::SH,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00080060-valid-field; rule-00080060-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0060U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::CS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00080064-valid-field; rule-00080064-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0064U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::CS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00080070-valid-field; rule-00080070-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0070U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::LO,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00080080-valid-field; rule-00080080-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0080U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::LO,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00080081-valid-field; rule-00080081-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0081U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::ST,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00080090-valid-field; rule-00080090-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0090U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::US,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00080201-valid-field; rule-00080201-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x0201U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::SH,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remove")
  // rule-00081010-valid-field; rule-00081010-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x1010U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::SH,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remove")
  // rule-00081030-valid-field; rule-00081030-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x1030U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::LO,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-0008103E-valid-field; rule-0008103E-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x103EU)
  let value = @model.DataElement::new(
    t,
    @model.Vr::LO,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00081040-valid-field; rule-00081040-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x1040U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::LO,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remove")
  // rule-00081048-valid-field; rule-00081048-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x1048U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::US,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00081050-valid-field; rule-00081050-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x1050U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::US,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00081070-valid-field; rule-00081070-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x1070U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::US,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00081140-valid-field; rule-00081140-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x1140U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::SQ,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "recurse")
  // rule-00081150-valid-field; rule-00081150-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x1150U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::UI,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00081155-valid-field; rule-00081155-wrong-vr
  let t = @model.Tag::new(0x0008U, 0x1155U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::UI,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remap")
  // rule-00100010-valid-field; rule-00100010-wrong-vr
  let t = @model.Tag::new(0x0010U, 0x0010U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::US,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "replace")
  // rule-00100020-valid-field; rule-00100020-wrong-vr
  let t = @model.Tag::new(0x0010U, 0x0020U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::LO,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "replace")
  // rule-00100021-valid-field; rule-00100021-wrong-vr
  let t = @model.Tag::new(0x0010U, 0x0021U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::LO,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00100030-valid-field; rule-00100030-wrong-vr
  let t = @model.Tag::new(0x0010U, 0x0030U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DA,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00100040-valid-field; rule-00100040-wrong-vr
  let t = @model.Tag::new(0x0010U, 0x0040U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::CS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00101000-valid-field; rule-00101000-wrong-vr
  let t = @model.Tag::new(0x0010U, 0x1000U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::LO,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00101001-valid-field; rule-00101001-wrong-vr
  let t = @model.Tag::new(0x0010U, 0x1001U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::US,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00101010-valid-field; rule-00101010-wrong-vr
  let t = @model.Tag::new(0x0010U, 0x1010U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::AS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remove")
  // rule-00101020-valid-field; rule-00101020-wrong-vr
  let t = @model.Tag::new(0x0010U, 0x1020U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remove")
  // rule-00101030-valid-field; rule-00101030-wrong-vr
  let t = @model.Tag::new(0x0010U, 0x1030U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remove")
  // rule-00102160-valid-field; rule-00102160-wrong-vr
  let t = @model.Tag::new(0x0010U, 0x2160U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::SH,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remove")
  // rule-001021B0-valid-field; rule-001021B0-wrong-vr
  let t = @model.Tag::new(0x0010U, 0x21B0U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::LT,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remove")
  // rule-00104000-valid-field; rule-00104000-wrong-vr
  let t = @model.Tag::new(0x0010U, 0x4000U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::LT,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remove")
  // rule-00120063-valid-field; rule-00120063-wrong-vr
  let t = @model.Tag::new(0x0012U, 0x0063U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::LO,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00180015-valid-field; rule-00180015-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x0015U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::CS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remove")
  // rule-00180020-valid-field; rule-00180020-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x0020U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::CS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00180021-valid-field; rule-00180021-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x0021U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::CS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00180022-valid-field; rule-00180022-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x0022U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::CS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00180023-valid-field; rule-00180023-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x0023U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::CS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00180050-valid-field; rule-00180050-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x0050U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00180060-valid-field; rule-00180060-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x0060U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00180080-valid-field; rule-00180080-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x0080U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00180081-valid-field; rule-00180081-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x0081U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00180082-valid-field; rule-00180082-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x0082U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00180083-valid-field; rule-00180083-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x0083U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00180084-valid-field; rule-00180084-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x0084U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00180085-valid-field; rule-00180085-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x0085U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::SH,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00180086-valid-field; rule-00180086-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x0086U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::IS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00180087-valid-field; rule-00180087-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x0087U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00180088-valid-field; rule-00180088-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x0088U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00180089-valid-field; rule-00180089-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x0089U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::IS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00180090-valid-field; rule-00180090-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x0090U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00180091-valid-field; rule-00180091-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x0091U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::IS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00180093-valid-field; rule-00180093-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x0093U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00180094-valid-field; rule-00180094-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x0094U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00181000-valid-field; rule-00181000-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x1000U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::LO,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00181002-valid-field; rule-00181002-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x1002U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::UI,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remove")
  // rule-00181004-valid-field; rule-00181004-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x1004U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::LO,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remove")
  // rule-00181030-valid-field; rule-00181030-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x1030U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::LO,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00181310-valid-field; rule-00181310-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x1310U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::US,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00181312-valid-field; rule-00181312-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x1312U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::CS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00181314-valid-field; rule-00181314-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x1314U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00181315-valid-field; rule-00181315-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x1315U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::CS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00185100-valid-field; rule-00185100-wrong-vr
  let t = @model.Tag::new(0x0018U, 0x5100U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::CS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-0020000D-valid-field; rule-0020000D-wrong-vr
  let t = @model.Tag::new(0x0020U, 0x000DU)
  let value = @model.DataElement::new(
    t,
    @model.Vr::UI,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remap")
  // rule-0020000E-valid-field; rule-0020000E-wrong-vr
  let t = @model.Tag::new(0x0020U, 0x000EU)
  let value = @model.DataElement::new(
    t,
    @model.Vr::UI,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remap")
  // rule-00200010-valid-field; rule-00200010-wrong-vr
  let t = @model.Tag::new(0x0020U, 0x0010U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::SH,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00200011-valid-field; rule-00200011-wrong-vr
  let t = @model.Tag::new(0x0020U, 0x0011U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::IS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00200012-valid-field; rule-00200012-wrong-vr
  let t = @model.Tag::new(0x0020U, 0x0012U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::IS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00200013-valid-field; rule-00200013-wrong-vr
  let t = @model.Tag::new(0x0020U, 0x0013U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::IS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00200020-valid-field; rule-00200020-wrong-vr
  let t = @model.Tag::new(0x0020U, 0x0020U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::CS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00200032-valid-field; rule-00200032-wrong-vr
  let t = @model.Tag::new(0x0020U, 0x0032U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00200037-valid-field; rule-00200037-wrong-vr
  let t = @model.Tag::new(0x0020U, 0x0037U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00200052-valid-field; rule-00200052-wrong-vr
  let t = @model.Tag::new(0x0020U, 0x0052U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::UI,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remap")
  // rule-00200060-valid-field; rule-00200060-wrong-vr
  let t = @model.Tag::new(0x0020U, 0x0060U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::CS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00201040-valid-field; rule-00201040-wrong-vr
  let t = @model.Tag::new(0x0020U, 0x1040U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::LO,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00201041-valid-field; rule-00201041-wrong-vr
  let t = @model.Tag::new(0x0020U, 0x1041U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00204000-valid-field; rule-00204000-wrong-vr
  let t = @model.Tag::new(0x0020U, 0x4000U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::LT,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00280002-valid-field; rule-00280002-wrong-vr
  let t = @model.Tag::new(0x0028U, 0x0002U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::US,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00280004-valid-field; rule-00280004-wrong-vr
  let t = @model.Tag::new(0x0028U, 0x0004U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::CS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00280006-valid-field; rule-00280006-wrong-vr
  let t = @model.Tag::new(0x0028U, 0x0006U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::US,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00280008-valid-field; rule-00280008-wrong-vr
  let t = @model.Tag::new(0x0028U, 0x0008U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::IS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00280009-valid-field; rule-00280009-wrong-vr
  let t = @model.Tag::new(0x0028U, 0x0009U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::AT,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00280010-valid-field; rule-00280010-wrong-vr
  let t = @model.Tag::new(0x0028U, 0x0010U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::US,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00280011-valid-field; rule-00280011-wrong-vr
  let t = @model.Tag::new(0x0028U, 0x0011U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::US,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00280030-valid-field; rule-00280030-wrong-vr
  let t = @model.Tag::new(0x0028U, 0x0030U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00280100-valid-field; rule-00280100-wrong-vr
  let t = @model.Tag::new(0x0028U, 0x0100U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::US,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00280101-valid-field; rule-00280101-wrong-vr
  let t = @model.Tag::new(0x0028U, 0x0101U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::US,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00280102-valid-field; rule-00280102-wrong-vr
  let t = @model.Tag::new(0x0028U, 0x0102U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::US,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00280103-valid-field; rule-00280103-wrong-vr
  let t = @model.Tag::new(0x0028U, 0x0103U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::US,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00280301-valid-field; rule-00280301-wrong-vr
  let t = @model.Tag::new(0x0028U, 0x0301U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::CS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00281050-valid-field; rule-00281050-wrong-vr
  let t = @model.Tag::new(0x0028U, 0x1050U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00281051-valid-field; rule-00281051-wrong-vr
  let t = @model.Tag::new(0x0028U, 0x1051U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00281052-valid-field; rule-00281052-wrong-vr
  let t = @model.Tag::new(0x0028U, 0x1052U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00281053-valid-field; rule-00281053-wrong-vr
  let t = @model.Tag::new(0x0028U, 0x1053U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00281054-valid-field; rule-00281054-wrong-vr
  let t = @model.Tag::new(0x0028U, 0x1054U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::LO,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00282110-valid-field; rule-00282110-wrong-vr
  let t = @model.Tag::new(0x0028U, 0x2110U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::CS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00282112-valid-field; rule-00282112-wrong-vr
  let t = @model.Tag::new(0x0028U, 0x2112U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::DS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00282114-valid-field; rule-00282114-wrong-vr
  let t = @model.Tag::new(0x0028U, 0x2114U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::CS,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-00321032-valid-field; rule-00321032-wrong-vr
  let t = @model.Tag::new(0x0032U, 0x1032U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::US,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00400241-valid-field; rule-00400241-wrong-vr
  let t = @model.Tag::new(0x0040U, 0x0241U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::AE,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "empty")
  // rule-00400275-valid-field; rule-00400275-wrong-vr
  let t = @model.Tag::new(0x0040U, 0x0275U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::SQ,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remove")
  // rule-00400555-valid-field; rule-00400555-wrong-vr
  let t = @model.Tag::new(0x0040U, 0x0555U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::SQ,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remove")
  // rule-04000561-valid-field; rule-04000561-wrong-vr
  let t = @model.Tag::new(0x0400U, 0x0561U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::SQ,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remove")
  // rule-7FE00010-valid-field; rule-7FE00010-wrong-vr
  let t = @model.Tag::new(0x7FE0U, 0x0010U)
  let value = @model.DataElement::new(
    t,
    @model.Vr::OB,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "keep")
  // rule-FFFCFFFC-valid-field; rule-FFFCFFFC-wrong-vr
  let t = @model.Tag::new(0xFFFCU, 0xFFFCU)
  let value = @model.DataElement::new(
    t,
    @model.Vr::OB,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  @conformance.check_attribute(value)
  let wrong = @model.DataElement::new(
    t,
    @model.Vr::PN,
    0U,
    @model.ElementValue::Empty,
    0,
  )
  let rejected = try {
    @conformance.check_attribute(wrong)
    false
  } catch {
    @model.MedSealError::RuleViolation(_, _, _, "vr") => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.lookup(t).unwrap().action, "remove")
}
