///|
/// Compile and inspect a policy through the public package only.
///
/// The consumer deliberately does not import MedSeal `src/` packages. Policy
/// compilation alone is not an IOD or privacy approval; conversion and review
/// remain explicit host workflow steps.
fn main {
  try {
    let policy = @policy.strict()
    ignore(policy)
    println("public-policy-ok")
  } catch {
    _ => println("public-policy-rejected")
  }
}
