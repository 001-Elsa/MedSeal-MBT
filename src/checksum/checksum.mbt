///|
pub fn sha256(bytes : Bytes) -> String {
  let digest = @sha256.Digest::new()
  for byte in bytes {
    digest.write(byte)
  }
  digest.check_sum()
}

///|
pub struct StreamDigest {
  priv digest : @sha256.Digest
}

///|
pub fn StreamDigest::new() -> StreamDigest {
  { digest: @sha256.Digest::new(), }
}

///|
pub fn StreamDigest::update(self : StreamDigest, bytes : BytesView) -> Unit {
  for byte in bytes {
    self.digest.write(byte)
  }
}

///|
pub fn StreamDigest::finish(self : StreamDigest) -> String {
  self.digest.check_sum()
}
