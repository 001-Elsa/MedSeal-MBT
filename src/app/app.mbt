///|
fn exit_code_for(command : Command, error : @model.MedSealError) -> Int {
  match error {
    @model.MedSealError::UnsupportedTransferSyntax(_) => 3
    @model.MedSealError::IoError(_)
    | @model.MedSealError::OutputAlreadyExists(_) => 4
    @model.MedSealError::InvalidArgument(_) => 2
    _ =>
      match command {
        Validate(_, _) => 1
        Anonymize(_, _, _, _, _) | Plan(_, _) | Batch(_, _, _) | Verify(_) => 5
        _ => 3
      }
  }
}

///|
pub async fn run(args : Array[String]) -> Int {
  let command = parse_command(args) catch {
    error => {
      println(error.display())
      println(help_text(None))
      return 2
    }
  }
  try {
    match command {
      Help(which) => {
        println(help_text(which))
        0
      }
      Version => {
        println("medseal \{@model.medseal_version}")
        0
      }
      Plan(path, policy_path) => {
        let job = @batch.plan(path, load_policy(policy_path))
        println(job.preview())
        0
      }
      Batch(input, output, policy_path) => {
        println(@batch.run(input, output, load_policy(policy_path)))
        0
      }
      Verify(path) => {
        println(@batch.verify(path))
        0
      }
      Explain(path) => {
        println(load_policy(Some(path)).explain())
        0
      }
      ExplainObject(path, policy_path) => {
        let report = @public_explain.object(
          @storage.read(path),
          match policy_path {
            None => @policy.strict()
            Some(_) => load_policy(policy_path)
          },
        )
        println(report.stringify(indent=2))
        match report {
          Json::Object(fields) if fields.get("status") ==
            Some(Json::string("blocked")) => 5
          _ => 0
        }
      }
      Inspect(path, json) => {
        inspect_file(path, json)
        0
      }
      Validate(path, json) => if validate_file(path, json) { 0 } else { 1 }
      Anonymize(input, output, report, remove_private, force) => {
        anonymize_file(input, output, report, remove_private, force)
        0
      }
    }
  } catch {
    error => {
      match command {
        ExplainObject(_, _) =>
          println(
            Json::object(
              Map::from_array([
                ("schema", Json::number(1.0)),
                ("status", Json::string("blocked")),
                ("release_authorized", Json::boolean(false)),
                ("issue", @public_explain.public_error(error)),
              ]),
            ).stringify(indent=2),
          )
        Validate(_, json) if !json => {
          println("INVALID")
          println(error.display())
        }
        _ => println(error.display())
      }
      exit_code_for(command, error)
    }
  }
}
