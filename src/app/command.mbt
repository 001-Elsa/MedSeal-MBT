///|
pub(all) enum Command {
  Inspect(String, Bool)
  Validate(String, Bool)
  Anonymize(String, String, String?, Bool, Bool)
  Plan(String, String?)
  Batch(String, String, String?)
  Verify(String)
  Explain(String)
  Help(String?)
  Version
} derive(Eq, Debug)

///|
fn option_value(
  args : Array[String],
  index : Int,
  name : String,
) -> String raise @model.MedSealError {
  if index + 1 >= args.length() {
    raise @model.MedSealError::InvalidArgument("missing value for \{name}")
  }
  if args[index + 1].has_prefix("--") {
    raise @model.MedSealError::InvalidArgument("missing option value")
  }
  args[index + 1]
}

///|
pub fn parse_command(args : Array[String]) -> Command raise @model.MedSealError {
  if args.is_empty() {
    return Help(None)
  }
  if args[0] == "--help" || args[0] == "-h" {
    return Help(None)
  }
  if args[0] == "--version" || args[0] == "-V" {
    return Version
  }
  let name = args[0]
  if args.length() >= 2 && (args[1] == "--help" || args[1] == "-h") {
    return Help(Some(name))
  }
  match name {
    "plan" | "batch" => {
      if args.length() < 2 {
        raise @model.MedSealError::InvalidArgument("missing input directory")
      }
      let mut output : String? = None
      let mut policy : String? = None
      let mut index = 2
      while index < args.length() {
        match args[index] {
          "--output" if name == "batch" && output is None => {
            output = Some(option_value(args, index, "--output"))
            index = index + 2
          }
          "--policy" if policy is None => {
            policy = Some(option_value(args, index, "--policy"))
            index = index + 2
          }
          _ =>
            raise @model.MedSealError::InvalidArgument(
              "unknown or duplicate batch option",
            )
        }
      }
      if name == "plan" {
        Plan(args[1], policy)
      } else {
        match output {
          Some(output) => Batch(args[1], output, policy)
          None =>
            raise @model.MedSealError::InvalidArgument(
              "batch requires --output",
            )
        }
      }
    }
    "verify" => {
      if args.length() != 2 {
        raise @model.MedSealError::InvalidArgument(
          "verify requires one job directory",
        )
      }
      Verify(args[1])
    }
    "explain" => {
      if args.length() != 2 {
        raise @model.MedSealError::InvalidArgument(
          "explain requires one policy file",
        )
      }
      Explain(args[1])
    }
    "inspect" | "validate" => {
      if args.length() < 2 {
        raise @model.MedSealError::InvalidArgument(
          "missing input file for \{name}",
        )
      }
      let mut json = false
      for index = 2; index < args.length(); index = index + 1 {
        if args[index] == "--json" {
          json = true
        } else {
          raise @model.MedSealError::InvalidArgument(
            "unknown option: \{args[index]}",
          )
        }
      }
      if name == "inspect" {
        Inspect(args[1], json)
      } else {
        Validate(args[1], json)
      }
    }
    "anonymize" => {
      if args.length() < 2 {
        raise @model.MedSealError::InvalidArgument(
          "missing input file for anonymize",
        )
      }
      let input = args[1]
      let mut output : String? = None
      let mut report : String? = None
      let mut remove_private = false
      let mut force = false
      let mut index = 2
      while index < args.length() {
        match args[index] {
          "--output" => {
            output = Some(option_value(args, index, "--output"))
            index = index + 2
          }
          "--report" => {
            report = Some(option_value(args, index, "--report"))
            index = index + 2
          }
          "--remove-private" => {
            remove_private = true
            index = index + 1
          }
          "--force" => {
            force = true
            index = index + 1
          }
          option =>
            raise @model.MedSealError::InvalidArgument(
              "unknown option: \{option}",
            )
        }
      }
      match output {
        Some(path) => Anonymize(input, path, report, remove_private, force)
        None =>
          raise @model.MedSealError::InvalidArgument(
            "missing required --output <path>",
          )
      }
    }
    _ => raise @model.MedSealError::InvalidArgument("unknown command: \{name}")
  }
}

///|
pub fn help_text(command : String?) -> String {
  match command {
    Some("plan") => "Usage: medseal plan <input-dir> [--policy <policy.json>]"
    Some("batch") =>
      "Usage: medseal batch <input-dir> --output <new-job-dir> [--policy <policy.json>]"
    Some("verify") => "Usage: medseal verify <job-dir>"
    Some("explain") => "Usage: medseal explain <policy.json>"
    Some("inspect") => "Usage: medseal inspect <input> [--json]"
    Some("validate") => "Usage: medseal validate <input> [--json]"
    Some("anonymize") =>
      "Compatibility basic mode: fixed aliases, retained UIDs, no collection or release authorization.\nUsage: medseal anonymize <input> --output <output> [--report <report.json>] [--remove-private] [--force]"
    _ =>
      "MedSeal-MBT \{@model.medseal_version}\nA DICOM metadata validation and collection de-identification tool.\n\nUsage:\n  medseal inspect <input> [--json]\n  medseal validate <input> [--json]\n  medseal anonymize <input> --output <output> [--report <report.json>] [--remove-private] [--force]\n  medseal plan <input-dir> [--policy <policy.json>]\n  medseal batch <input-dir> --output <new-job-dir> [--policy <policy.json>]\n  medseal verify <job-dir>\n  medseal --version"
  }
}

///|
pub extend Command with Eq::{equal, not_equal}

///|
pub extend Command with Debug::{to_repr}
