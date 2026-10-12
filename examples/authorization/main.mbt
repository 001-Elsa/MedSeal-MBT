///|
async fn run() -> Unit {
  let args = @env.args()
  if args.length() != 7 {
    @sys.exit(2)
  }
  try {
    let names = [
      "api_authorization.py", "enterprise_job.py", "risk_gate.py", "verify_delivery.py",
      "private_store.py", "ledger_cache.py", "history_outbox.py", "local_fs.py",
    ]
    let files : Array[(String, String)] = []
    for name in names {
      let path = args[2] + "/" + name
      files.push((path, @storage.file_digest(path)))
    }
    let verifier = @evidence.Verifier::new(
      args[1],
      args[2] + "/api_authorization.py",
      files,
    )
    if args[3] == "review" {
      let evidence = verifier.review(args[4], args[5], args[6])
      println("review:\{evidence.objects}:\{evidence.context}")
    } else {
      let evidence = verifier.authorized_package(
        args[4],
        args[6],
        acceptance=if args[5] == "synthetic-test" {
          @evidence.SyntheticTest
        } else {
          @evidence.Controlled
        },
      )
      println("package:\{evidence.objects}:\{evidence.context}")
    }
  } catch {
    _ => {
      println("evidence-revalidation-failed")
      @sys.exit(6)
    }
  }
}

///|
fn main {
  @async.run_async_main(run)
}
