///|
async fn run() -> Unit {
  let args = @env.args()
  if args.length() != 8 {
    println(
      "Usage: medseal-enterprise INPUT OUTPUT POLICY PYTHON ADAPTER PRIVATE_STORE SOURCE_DOMAIN",
    )
    @sys.exit(2)
  }
  try {
    let text = @utf8.decode(@storage.read(args[3], limit=1024 * 1024))
    let policy = @policy.from_json(text)
    if !policy.strict_metadata {
      fail("enterprise entry requires strict policy")
    }
    let provider : @identity_store.Provider = {
      python: args[4],
      adapter: args[5],
      store: args[6],
      source_domain: args[7],
    }
    println(@batch.run(args[1], args[2], policy, provider=Some(provider)))
  } catch {
    _ => {
      println("enterprise operation failed; no delivery authorization granted")
      @sys.exit(5)
    }
  }
}

///|
fn main {
  @async.run_async_main(run)
}
