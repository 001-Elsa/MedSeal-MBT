///|
fn parse_tag(text : String) -> @dicom.Tag raise @dicom.MedSealError {
  if text.length() != 8 ||
    !text.all(c => {
      (c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f')
    }) {
    raise @dicom.MedSealError::InvalidArgument("tag must be eight hex digits")
  }
  let n = @string.parse_uint(text, base=16) catch {
    _ => raise @dicom.MedSealError::InvalidArgument("invalid tag")
  }
  @dicom.Tag::new(n >> 16, n & 65535U)
}

///|
async fn main {
  let all = @env.args()
  let args = all[1:].to_owned()
  if args.is_empty() || args[0] == "--help" {
    println(
      "medseal-data summary|quality INPUT_DIR\nmedseal-data export INPUT_DIR --output NEW_FILE --format csv|jsonl [--fields 00080060,00280010,00280011] [--equals TAG=VALUE] [--group TAG]\nmedseal-data convert INPUT_DIR --output NEW_DIR [--policy POLICY_JSON]\nExports contain private metadata; conversion always uses the complete closed directory.",
    )
    return
  }
  let code = try {
    if args.length() < 2 {
      raise @dicom.MedSealError::InvalidArgument("missing input directory")
    }
    let command = args[0]
    if !["summary", "quality", "export", "convert"].contains(command) {
      raise @dicom.MedSealError::InvalidArgument("unknown data command")
    }
    let input = args[1]
    let options : Map[String, String] = Map([])
    let mut i = 2
    while i < args.length() {
      let key = args[i]
      if ![
          "--output", "--format", "--fields", "--equals", "--group", "--policy",
        ].contains(key) ||
        options.contains(key) ||
        i + 1 >= args.length() {
        raise @dicom.MedSealError::InvalidArgument(
          "invalid or duplicate option",
        )
      }
      options.set(key, args[i + 1])
      i = i + 2
    }
    let allowed = match command {
      "export" => ["--output", "--format", "--fields", "--equals", "--group"]
      "convert" => ["--output", "--policy"]
      _ => []
    }
    for key in options.keys() {
      if !allowed.contains(key) {
        raise @dicom.MedSealError::InvalidArgument(
          "option not supported by this command",
        )
      }
    }
    if command == "convert" {
      let output = options
        .get("--output")
        .unwrap_or_else(() => {
          raise @dicom.MedSealError::InvalidArgument("missing output")
        })
      let policy = match options.get("--policy") {
        None => @policy.strict()
        Some(path) =>
          @policy.from_json(
            @utf8.decode(@storage.read(path, limit=1024 * 1024)) catch {
              _ =>
                raise @dicom.MedSealError::InvalidArgument(
                  "policy must be UTF-8",
                )
            },
          )
      }
      let job = @native.plan_directory(input, policy~)
      job.execute(output)
      println(job.public_report().stringify())
      0
    } else if command == "quality" {
      let report = @native.quality_directory(input)
      println(
        Json::object(
          Map::from_array([
            ("schema", Json::string("medseal-directory-quality-v1")),
            ("scope", Json::string("metadata-only")),
            ("pixels_checked", Json::boolean(false)),
            ("quality", report.public_json()),
            ("release_authorized", Json::boolean(false)),
          ]),
        ).stringify(),
      )
      if report.ready() {
        0
      } else {
        1
      }
    } else {
      let scan = @native.scan_directory(input)
      let datasets = scan.private_datasets()
      let names = options
        .get("--fields")
        .unwrap_or("00080060,00280010,00280011")
        .split(",")
        .map(v => v.to_owned())
        .to_array()
      let columns : Array[@query.Column] = names.map(name => {
        name,
        path: [@query.Step::Field(parse_tag(name))],
      })
      if command == "summary" {
        println(@query.summary(datasets, columns).stringify())
      } else {
        let output = options
          .get("--output")
          .unwrap_or_else(() => {
            raise @dicom.MedSealError::InvalidArgument("missing output")
          })
        let format = options.get("--format").unwrap_or("csv")
        if !["csv", "jsonl"].contains(format) {
          raise @dicom.MedSealError::InvalidArgument(
            "format must be csv or jsonl",
          )
        }
        let selected = match options.get("--equals") {
          None => datasets
          Some(expression) => {
            let parts = expression.split("=").map(v => v.to_owned()).to_array()
            if parts.length() < 2 {
              raise @dicom.MedSealError::InvalidArgument(
                "filter must be TAG=VALUE",
              )
            }
            let indices = @query.select(datasets, [
              @query.Predicate::Equals(
                [@query.Step::Field(parse_tag(parts[0]))],
                parts[1:].to_owned().join("="),
              ),
            ])
            indices.map(index => datasets[index])
          }
        }
        let table = @query.project(selected, columns)
        let content = if format == "csv" {
          table.private_csv()
        } else {
          table.private_jsonl()
        }
        let groups = match options.get("--group") {
          Some(tag) =>
            @query.group_counts(selected, [@query.Step::Field(parse_tag(tag))])
          None => []
        }
        @storage.write_new(output, @utf8.encode(content))
        // Group keys are private: only emit in an explicitly requested export command.
        for (key, count) in groups {
          println(
            Json::object(
              Map::from_array([
                ("key", Json::string(key)),
                ("count", Json::number(count.to_double())),
              ]),
            ).stringify(),
          )
        }
        println("private-export-written")
      }
      0
    }
  } catch {
    _ => {
      // Do not print private error payloads, file names or values.
      println(
        "MEDSEAL-DATA-FAILED: check command options, supported input and output destination; use --help",
      )
      2
    }
  }
  if code != 0 {
    @sys.exit(code)
  }
}
