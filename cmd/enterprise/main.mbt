///|
async fn run() -> Unit {
  let args = @env.args()
  let verifying = args.length() > 1 && args[1] == "--verify"
  let start = if verifying { 1 } else { 0 }
  if (verifying && args.length() != 10) ||
    (!verifying && ![8, 10, 11].contains(args.length())) {
    println(
      "Usage: medseal-enterprise INPUT OUTPUT POLICY PYTHON ADAPTER PRIVATE_STORE SOURCE_DOMAIN [PRIVATE_STAGE OWNER_TOKEN]",
    )
    @sys.exit(2)
  }
  try {
    let text = @utf8.decode(@storage.read(args[3 + start], limit=1024 * 1024))
    let policy = @policy.from_json(text)
    if !policy.strict_metadata {
      fail("enterprise entry requires strict policy")
    }
    let provider : @identity_store.Provider = {
      python: args[4 + start],
      adapter: args[5 + start],
      store: args[6 + start],
      source_domain: args[7 + start],
    }
    let job = @batch.plan(
      args[1 + start],
      policy,
      provider=Some(provider),
      streamed=true,
      program_sha256=@storage.file_digest(args[0]),
      destination=if verifying || args.length() == 11 {
        Some(
          @json.parse(
            @utf8.decode(
              @storage.read(args[if verifying { 9 } else { 10 }], limit=4096),
            ),
          ),
        )
      } else {
        None
      },
    )
    if verifying {
      println(job.verify_output(args[3]))
      return
    }
    let resume_stage = if args.length() >= 10 {
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
    println(job.execute(args[2 + start], resume_stage~, checkpoint~))
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
