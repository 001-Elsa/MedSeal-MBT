///|
pub(all) enum Command {
  Inspect(String, Bool)
  Validate(String, Bool)
  Anonymize(String, String, String?, Bool, Bool)
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
    Some("inspect") => "Usage: medseal inspect <input> [--json]"
    Some("validate") => "Usage: medseal validate <input> [--json]"
    Some("anonymize") =>
      "Usage: medseal anonymize <input> --output <output> [--report <report.json>] [--remove-private] [--force]"
    _ =>
      "MedSeal-MBT \{@model.medseal_version}\nA DICOM metadata validator and basic de-identification tool.\n\nUsage:\n  medseal inspect <input> [--json]\n  medseal validate <input> [--json]\n  medseal anonymize <input> --output <output> [--report <report.json>] [--remove-private] [--force]\n  medseal --version"
  }
}
