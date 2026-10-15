///|
test "private inspection rejects budgets and raw input without any value echo" {
  for input in [[], [b""], Array::make(17, b"x"), [b"PRIVATE-ERROR-CANARY"]] {
    let output = @core.inspect_private(input)
    assert_true(output.contains("blocked"))
    assert_true(output.contains("release_authorized"))
    assert_true(!output.contains("PRIVATE-ERROR-CANARY"))
  }
  assert_true(
    @core.inspect_private([Bytes::make(8 * 1024 * 1024 + 1, b'\x00')]).contains(
      "MEDSEAL-E501",
    ),
  )
  assert_true(
    @core.inspect_private(Array::make(3, Bytes::make(6 * 1024 * 1024, b'\x00'))).contains(
      "MEDSEAL-E501",
    ),
  )
}

///|
test "private reveal revalidates and refuses invalid object indices" {
  for index in [-1, 1, 100] {
    let result = @core.reveal_private([b"PRIVATE-ERROR-CANARY"], index)
    assert_true(result.contains("blocked"))
    assert_true(!result.contains("PRIVATE-ERROR-CANARY"))
  }
  assert_true(
    !@core.reveal_private([b"PRIVATE-ERROR-CANARY"], 0).contains(
      "PRIVATE-ERROR-CANARY",
    ),
  )
}
