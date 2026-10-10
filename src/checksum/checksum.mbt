///|
pub fn sha256(bytes : Bytes) -> String {
  let digest = @sha256.Digest::new()
  for byte in bytes {
    digest.write(byte)
  }
  digest.check_sum()
}
