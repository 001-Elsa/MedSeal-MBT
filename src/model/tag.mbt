///|
pub struct Tag {
  group : UInt
  element : UInt
} derive(Eq, Hash, Debug)

///|
pub fn Tag::new(group : UInt, element : UInt) -> Tag {
  { group, element, }
}

///|
pub fn Tag::is_private(self : Tag) -> Bool {
  (self.group & 1U) == 1U
}

///|
fn hex4(value : UInt) -> String {
  let raw = value.to_string(radix=16)
  let upper = String::from_array(
    raw
    .to_array()
    .map(fn(c) {
      if c >= 'a' && c <= 'f' {
        (c.to_int() - 32).to_char().unwrap()
      } else {
        c
      }
    }),
  )
  match upper.length() {
    0 => "0000"
    1 => "000\{upper}"
    2 => "00\{upper}"
    3 => "0\{upper}"
    _ => upper
  }
}

///|
pub fn Tag::to_string(self : Tag) -> String {
  "(\{hex4(self.group)},\{hex4(self.element)})"
}

///|
pub fn Tag::compact(self : Tag) -> String {
  "\{hex4(self.group)},\{hex4(self.element)}"
}

///|
pub let transfer_syntax_uid_tag : Tag = Tag::new(0x0002U, 0x0010U)

///|
pub let pixel_data_tag : Tag = Tag::new(0x7FE0U, 0x0010U)

///|
pub extend Tag with Eq::{equal, not_equal}

///|
pub extend Tag with Debug::{to_repr}

///|
pub extend Tag with Hash::{hash, hash_combine}
