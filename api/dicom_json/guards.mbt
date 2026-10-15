///|
fn invalid(reason : String) -> @dicom.MedSealError {
  // Only fixed developer-authored reasons. Never append source data or keys.
  @dicom.MedSealError::InvalidModel("DICOM JSON: " + reason)
}

///|
priv struct Budget {
  mut nodes : Int
  mut remaining : Int
}

///|
fn Budget::new() -> Budget {
  { nodes: 0, remaining: 8 * 1024 * 1024, }
}

///|
fn Budget::node(self : Budget, depth : Int) -> Unit raise @dicom.MedSealError {
  if depth > 16 || self.nodes >= 20000 {
    raise invalid("depth or entry budget")
  }
  self.nodes = self.nodes + 1
  self.spend(128)
}

///|
fn Budget::spend(self : Budget, bytes : Int) -> Unit raise @dicom.MedSealError {
  if bytes < 0 || bytes > self.remaining {
    raise invalid("encoding budget")
  }
  self.remaining = self.remaining - bytes
}

///|
fn Budget::text(self : Budget, text : String) -> Unit raise @dicom.MedSealError {
  if text.length() > 1024 * 1024 {
    raise invalid("text value budget")
  }
  let size = @utf8.encode(text).length()
  if size > 1024 * 1024 {
    raise invalid("text value budget")
  }
  // Conservative JSON escaping allowance; bound allocations before stringify.
  self.spend(size * 6)
}

///|
priv struct Frame {
  keys : Map[String, Bool]
  object : Bool
  mut expects_key : Bool
}

///|
// Preflight raw JSON before the parser collapses duplicate keys. Escaped keys
// are decoded before comparing, so "vr" and "v\u0072" cannot bypass this.
// Core JSON may round a Number and discard its lexeme. Replace numeric tokens
// with an internal tagged object before parsing; reject that key in ALL source
// objects (including escaped spellings), so input cannot forge the marker.
fn preflight(text : String) -> String raise @dicom.MedSealError {
  if text.length() > 8 * 1024 * 1024 ||
    @utf8.encode(text).length() > 8 * 1024 * 1024 {
    raise invalid("input exceeds 8 MiB")
  }
  let chars = text.to_array()
  let stack : Array[Frame] = []
  let mut i = 0
  let mut segment = 0
  let pieces : Array[String] = []
  let mut numbers = 0
  let mut containers = 0
  let mut keys = 0
  while i < chars.length() {
    match chars[i] {
      '{' | '[' => {
        containers = containers + 1
        if containers > 40002 {
          raise invalid("container budget")
        }
        if stack.length() >= 64 {
          raise invalid("JSON nesting budget")
        }
        stack.push({
          keys: Map([]),
          object: chars[i] == '{',
          expects_key: chars[i] == '{',
        })
      }
      '}' | ']' => if !stack.is_empty() { ignore(stack.pop()) }
      ',' =>
        if stack.last() is Some(frame) && frame.object {
          frame.expects_key = true
        }
      '"' => {
        let start = i
        i = i + 1
        while i < chars.length() {
          if chars[i] == '\\' {
            i = i + 2
          } else if chars[i] == '"' {
            break
          } else {
            i = i + 1
          }
        }
        if i >= chars.length() {
          raise invalid("unterminated JSON string")
        }
        if stack.last() is Some(frame) && frame.object && frame.expects_key {
          let key = match
            (@json.parse(String::from_array(chars[start:i + 1].to_owned())) catch {
              _ => Json::null()
            }) {
            Json::String(value) => value
            _ => raise invalid("invalid JSON key")
          }
          if key == "__medseal_exact_number__" {
            raise invalid("reserved internal member")
          }
          if frame.keys.contains(key) {
            raise invalid("duplicate JSON key")
          }
          keys = keys + 1
          if keys > 80001 {
            raise invalid("member budget")
          }
          frame.keys.set(key, true)
          frame.expects_key = false
        }
      }
      '-' | '0'..='9' => {
        let start = i
        while i < chars.length() &&
              ![' ', '\t', '\r', '\n', ',', ']', '}'].contains(chars[i]) {
          i = i + 1
        }
        let token = String::from_array(chars[start:i].to_owned())
        match (@json.parse(token) catch { _ => Json::null() }) {
          Json::Number(n, ..) if !n.is_nan() && !n.is_inf() => ()
          _ => raise invalid("invalid or non-finite JSON number")
        }
        numbers = numbers + 1
        if numbers > 20000 {
          raise invalid("numeric token budget")
        }
        pieces.push(String::from_array(chars[segment:start].to_owned()))
        pieces.push(
          "{\"__medseal_exact_number__\":" +
          Json::string(token).stringify() +
          "}",
        )
        segment = i
        i = i - 1
      }
      _ => ()
    }
    i = i + 1
  }
  pieces.push(String::from_array(chars[segment:].to_owned()))
  pieces.join("")
}

///|
fn tag(text : String) -> @dicom.Tag raise @dicom.MedSealError {
  if text.length() != 8 ||
    !text.all(c => (c >= '0' && c <= '9') || (c >= 'A' && c <= 'F')) {
    raise invalid("tag must be eight uppercase hexadecimal digits")
  }
  let mut value = 0U
  for c in text {
    value = value * 16U +
      (if c <= '9' { c.to_int() - 48 } else { c.to_int() - 55 }).reinterpret_as_uint()
  }
  let result = @dicom.Tag::new(value >> 16, value & 65535U)
  if result.element == 0U || result.group == 0x0002U || result.group == 0xFFFEU {
    raise invalid("group length, file meta or delimiter in dataset")
  }
  result
}

///|
fn supported(vr : @dicom.Vr) -> Bool {
  vr.is_text() ||
  [
    @dicom.Vr::US,
    @dicom.Vr::SS,
    @dicom.Vr::UL,
    @dicom.Vr::SL,
    @dicom.Vr::SQ,
    @dicom.Vr::OB,
    @dicom.Vr::OW,
    @dicom.Vr::UN,
  ].contains(vr)
}

///|
fn single_text(vr : @dicom.Vr) -> Bool {
  [@dicom.Vr::LT, @dicom.Vr::ST, @dicom.Vr::UT, @dicom.Vr::UR].contains(vr)
}

///|
fn fields(json : Json) -> Map[String, Json] raise @dicom.MedSealError {
  match json {
    Json::Object(values) => values
    _ => raise invalid("expected object")
  }
}

///|
fn integer_text(text : String) -> Bool {
  let digits = if text.has_prefix("-") || text.has_prefix("+") {
    text[1:].to_owned()
  } else {
    text
  }
  !digits.is_empty() && digits.all(c => c >= '0' && c <= '9')
}

///|
// Preserve number lexemes for DS/IS instead of round-tripping through Double.
fn numeric_text(json : Json) -> String raise @dicom.MedSealError {
  match json {
    Json::Object(obj) =>
      match obj.get("__medseal_exact_number__") {
        Some(Json::String(token)) if obj.length() == 1 => token
        _ => raise invalid("expected exact numeric token")
      }
    Json::String(value) => value
    _ => raise invalid("expected finite number or numeric string")
  }
}

///|
fn check_numeric(
  text : String,
  vr : @dicom.Vr,
) -> Unit raise @dicom.MedSealError {
  let clean = text.trim(chars=" ").to_owned()
  if vr == @dicom.Vr::IS {
    if text.length() > 12 || !integer_text(clean) {
      raise invalid("invalid IS")
    }
    ignore(
      @string.parse_int(clean) catch {
        _ => raise invalid("IS outside signed 32-bit range")
      },
    )
  } else {
    if text.length() > 16 || clean.is_empty() {
      raise invalid("invalid DS")
    }
    let chars = clean.to_array()
    let mut i = if chars[0] == '+' || chars[0] == '-' { 1 } else { 0 }
    let mut digits = 0
    while i < chars.length() && chars[i] >= '0' && chars[i] <= '9' {
      digits = digits + 1
      i = i + 1
    }
    if i < chars.length() && chars[i] == '.' {
      i = i + 1
      while i < chars.length() && chars[i] >= '0' && chars[i] <= '9' {
        digits = digits + 1
        i = i + 1
      }
    }
    if digits == 0 {
      raise invalid("invalid DS")
    }
    if i < chars.length() && (chars[i] == 'e' || chars[i] == 'E') {
      i = i + 1
      if i < chars.length() && (chars[i] == '+' || chars[i] == '-') {
        i = i + 1
      }
      let start = i
      while i < chars.length() && chars[i] >= '0' && chars[i] <= '9' {
        i = i + 1
      }
      if i == start {
        raise invalid("invalid DS exponent")
      }
    }
    if i != chars.length() {
      raise invalid("invalid DS")
    }
    let n = @string.parse_double(clean) catch {
      _ => raise invalid("invalid DS")
    }
    if n.is_inf() || n.is_nan() {
      raise invalid("non-finite DS")
    }
  }
}
