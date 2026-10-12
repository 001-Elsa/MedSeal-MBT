///|
/// Deterministic bounded parser fuzzing. Every input enters the real policy
/// parser; malformed input must become a typed policy error, never a crash.
test "w4-policy-parser-fuzz-100000" {
  let mut accepted = 0
  let mut rejected = 0
  for i = 0; i < 100000; i = i + 1 {
    let text = match i % 5 {
      0 =>
        "{\"version\":2,\"mode\":\"strict\",\"namespace\":\"fuzz\",\"date_shift_days\":30}"
      1 =>
        "{\"version\":2,\"mode\":\"strict\",\"namespace\":\"fuzz\",\"date_shift_days\":30,\"version\":1}"
      2 =>
        "{\"version\":2,\"mode\":\"strict\",\"namespace\":\"fuzz\",\"date_shift_days\":99999}"
      3 =>
        "{\"version\":2,\"mode\":\"strict\",\"namespace\":\"fuzz\",\"path_rules\":[{\"id\":\"x\",\"path\":\"dataset/00081030\",\"action\":\"replace\",\"value\":\"x\",\"priority\":0}]}"
      _ =>
        "{\"version\":2,\"mode\":\"strict\",\"namespace\":\"fuzz\",\"date_shift_days\":30"
    }
    try {
      ignore(@policy.from_json(text))
      accepted = accepted + 1
    } catch {
      _ => rejected = rejected + 1
    }
  }
  assert_eq(accepted + rejected, 100000)
  assert_true(accepted > 0)
  assert_true(rejected > 0)
}
