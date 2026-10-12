///|
async fn run() -> Unit {
  let args = @env.args()
  if args.length() != 6 {
    println("Synthetic QA only: MODE FIXTURE TAG POLICY OUTPUT")
    @sys.exit(2)
  }
  try {
    let bytes = @storage.read(args[2])
    if args[1] == "collection" {
      let paths = @utf8.decode(bytes)
        .split("\n")
        .filter(fn(path) { !path.is_empty() })
        .to_array()
      let inputs : Array[Bytes] = []
      for path in paths {
        inputs.push(@storage.read(path.to_owned()))
      }
      println(@qa.evaluate_collection(inputs).stringify())
      return
    }
    let configuration = if args[4] == "-" {
      ""
    } else {
      @utf8.decode(@storage.read(args[4]))
    }
    let result = @qa.evaluate(bytes, args[1], tag=args[3], configuration~)
    if args[5] != "-" {
      // Independent reader checks writer bytes, not merely this model function.
      @storage.write_new(
        args[5],
        if args[1] == "field" {
          @qa.roundtrip_bytes(bytes)
        } else {
          @qa.converted_bytes(bytes, configuration~)
        },
      )
    }
    println(result.stringify())
  } catch {
    _ => {
      println("{\"status\":\"qa-operation-failed\"}")
      @sys.exit(5)
    }
  }
}

///|
fn main {
  @async.run_async_main(run)
}
