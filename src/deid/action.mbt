///|
pub(all) enum DeIdAction {
  Keep
  Empty
  Replace(String)
  Remove
} derive(Eq, Debug)

///|
pub fn DeIdAction::name(self : DeIdAction) -> String {
  match self {
    Keep => "keep"
    Empty => "empty"
    Replace(_) => "replace"
    Remove => "remove"
  }
}
