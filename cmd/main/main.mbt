///|
/// Native CLI entry point. Business logic lives in the app package.
async fn main {
  let args = @env.args()
  let user_args = if args.length() > 1 { args[1:].to_owned() } else { [] }
  let code = @app.run(user_args)
  if code != 0 {
    @sys.exit(code)
  }
}
