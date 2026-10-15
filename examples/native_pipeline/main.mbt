///|
/// Public Native consumer and fault rehearsal; synthetic test paths only.
async fn main {
  let args = @env.args()
  if args.length() != 4 {
    abort("mode input output required")
  }
  let mode = args[1]
  let input = args[2]
  let output = args[3]
  if mode == "cancel-plan" || mode == "cancel-scan" {
    let rejected = try {
      if mode == "cancel-plan" {
        ignore(@native.plan_directory(input, cancelled=Some(() => true)))
      } else {
        ignore(@native.scan_directory(input, cancelled=Some(() => true)))
      }
      false
    } catch {
      _ => true
    }
    if !rejected {
      abort("cancellation ignored")
    }
  } else if mode == "scan-copy" {
    let scan = @native.scan_directory(input)
    let first = scan.private_datasets()
    first[0].elements.clear()
    if scan.private_datasets()[0].elements.is_empty() {
      abort("mutable scan alias")
    }
    println(scan.public_report().stringify())
  } else {
    let job = @native.plan_directory(input)
    if mode == "cancel-execute" || mode == "cancel-commit" {
      let calls = [0]
      let threshold = if mode == "cancel-commit" { 6 } else { 3 }
      let rejected = try {
        job.execute(
          output,
          cancelled=Some(() => {
            calls[0] = calls[0] + 1
            calls[0] > threshold
          }),
        )
        false
      } catch {
        _ => true
      }
      if !rejected {
        abort("execution cancellation ignored")
      }
    } else if mode == "changed-input" {
      @async_fs.write_file((input + "/injected.dcm")[:], b"invalid")
      let rejected = try {
        job.execute(output)
        false
      } catch {
        _ => true
      }
      if !rejected {
        abort("changed input accepted")
      }
    } else {
      job.execute(output)
      if mode == "reuse" {
        let rejected = try {
          job.execute(output + "-second")
          false
        } catch {
          _ => true
        }
        if !rejected {
          abort("single-use job reused")
        }
      }
      println(job.public_report().stringify())
    }
  }
  println("native-consumer-ok")
}
