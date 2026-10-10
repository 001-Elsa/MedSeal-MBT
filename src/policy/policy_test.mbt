///|
test "policy loading accepts an explicit supported schema" {
  let policy = @policy.from_json(
    "{\"version\":1,\"mode\":\"research\",\"namespace\":\"lab\",\"date_shift_days\":30,\"rules\":[{\"tag\":\"00081030\",\"action\":\"empty\"}]}",
  )
  assert_eq(policy.scope_name, "lab")
  assert_eq(policy.date_shift_days, 30)
}

///|
test "policies reject unknown fields and unsafe structural overrides" {
  let unknown = try {
    ignore(
      @policy.from_json(
        "{\"version\":1,\"mode\":\"research\",\"namespace\":\"lab\",\"date_shift_days\":30,\"typo\":true}",
      ),
    )
    false
  } catch {
    _ => true
  }
  let pixels = try {
    ignore(
      @policy.research(rules=[
        { tag: @model.pixel_data_tag, action: @policy.Action::Remove, },
      ]),
    )
    false
  } catch {
    _ => true
  }
  let duplicates = try {
    ignore(
      @policy.research(rules=[
        {
          tag: @model.Tag::new(0x0008U, 0x1030U),
          action: @policy.Action::Empty,
        },
        {
          tag: @model.Tag::new(0x0008U, 0x1030U),
          action: @policy.Action::Keep,
        },
      ]),
    )
    false
  } catch {
    _ => true
  }
  assert_true(unknown && pixels && duplicates)
}
