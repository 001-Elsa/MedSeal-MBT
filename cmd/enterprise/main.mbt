///|
async fn run() -> Unit {
  let args = @env.args()
  if args.length() != 8 && args.length() != 10 {
    println(
      "Usage: medseal-enterprise INPUT OUTPUT POLICY PYTHON ADAPTER PRIVATE_STORE SOURCE_DOMAIN [PRIVATE_STAGE OWNER_TOKEN]",
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
    let job = @batch.plan(args[1], policy, provider=Some(provider))
    let resume_stage = if args.length() == 10 {
      Some(@batch.ResumeStage::{ path: args[8], token: args[9], })
    } else {
      None
    }
    let checkpoint : (async (String, Int) -> Unit raise @model.MedSealError)? = if resume_stage
      is Some(_) {
      Some(async fn(
        event : String,
        index : Int,
      ) -> Unit raise @model.MedSealError {
        @stdio.stdout.write(
          @utf8.encode("{\"checkpoint\":\"\{event}\",\"index\":\{index}}\n"),
        ) catch {
          _ =>
            raise @model.MedSealError::IoError("checkpoint channel unavailable")
        }
      })
    } else {
      None
    }
    println(job.execute(args[2], resume_stage~, checkpoint~))
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
