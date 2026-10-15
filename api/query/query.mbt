///|
/// A path selects a tag and, optionally, a zero-based sequence item at each step.
pub(all) enum Step {
  Field(@dicom.Tag)
  Item(@dicom.Tag, Int)
} derive(Eq, Debug)

///|
pub(all) suberror QueryError {
  Missing
  TypeMismatch
  MultipleValues
  InvalidNumber
  InvalidPath
  BudgetExceeded
} derive(Debug)

///|
/// Private data accessor. Missing, malformed paths and wrong value types differ.
pub fn lookup(
  dataset : @dicom.DataSet,
  path : Array[Step],
) -> @dicom.DataElement raise QueryError {
  if path.is_empty() || path.length() > 32 {
    raise InvalidPath
  }
  let mut current = dataset
  for index, step in path {
    match step {
      Field(tag) => {
        if index != path.length() - 1 {
          raise InvalidPath
        }
        return current.find(tag).unwrap_or_else(() => raise Missing)
      }
      Item(tag, item) => {
        if index == path.length() - 1 || item < 0 {
          raise InvalidPath
        }
        let element = current.find(tag).unwrap_or_else(() => raise Missing)
        match element.value {
          @dicom.ElementValue::Sequence(items) => {
            if item >= items.length() {
              raise Missing
            }
            current = items[item]
          }
          _ => raise TypeMismatch
        }
      }
    }
  }
  raise InvalidPath
}

///|
pub fn values(
  dataset : @dicom.DataSet,
  path : Array[Step],
) -> Array[String] raise QueryError {
  match lookup(dataset, path).value {
    @dicom.ElementValue::Text(text) =>
      text.split("\\").map(s => s.to_owned()).to_array()
    @dicom.ElementValue::UnsignedShort(v)
    | @dicom.ElementValue::UnsignedLong(v) => v.map(n => n.to_string())
    @dicom.ElementValue::SignedShort(v) | @dicom.ElementValue::SignedLong(v) =>
      v.map(n => n.to_string())
    @dicom.ElementValue::Empty => []
    _ => raise TypeMismatch
  }
}

///|
pub fn scalar(
  dataset : @dicom.DataSet,
  path : Array[Step],
) -> String raise QueryError {
  let found = values(dataset, path)
  if found.length() != 1 {
    raise MultipleValues
  }
  found[0]
}

///|
/// Exact bounded integer parsing; no floating point coercion or truncation.
pub fn integer(
  dataset : @dicom.DataSet,
  path : Array[Step],
) -> Int64 raise QueryError {
  let text = scalar(dataset, path).trim().to_owned()
  let chars = text.to_array()
  if chars.is_empty() {
    raise InvalidNumber
  }
  let negative = chars[0] == '-'
  let start = if negative || chars[0] == '+' { 1 } else { 0 }
  if start == chars.length() {
    raise InvalidNumber
  }
  // Bound to +/- 2^53-1 for identical Native/JS/wasm numeric semantics.
  let mut number = 0L
  for i in start..<chars.length() {
    let c = chars[i]
    if c < '0' || c > '9' {
      raise InvalidNumber
    }
    let digit = (c.to_int() - 48).to_int64()
    if number > (9007199254740991L - digit) / 10L {
      raise InvalidNumber
    }
    number = number * 10L + digit
  }
  if negative {
    -number
  } else {
    number
  }
}

///|
pub(all) enum Predicate {
  Exists(Array[Step])
  Equals(Array[Step], String)
  IntegerRange(Array[Step], Int64, Int64)
} derive(Debug)

///|
pub fn select(
  datasets : Array[@dicom.DataSet],
  predicates : Array[Predicate],
) -> Array[Int] raise QueryError {
  if datasets.length() > 10000 || predicates.length() > 64 {
    raise BudgetExceeded
  }
  let result : Array[Int] = []
  for index, dataset in datasets {
    let mut matches = true
    for predicate in predicates {
      let matched = match predicate {
        Exists(path) =>
          try {
            ignore(lookup(dataset, path))
            true
          } catch {
            Missing => false
            e => raise e
          }
        Equals(path, value) =>
          values(dataset, path).contains(value) catch {
            Missing => false
            e => raise e
          }
        IntegerRange(path, low, high) => {
          if low > high {
            raise InvalidNumber
          }
          try {
            let value = integer(dataset, path)
            value >= low && value <= high
          } catch {
            Missing => false
            e => raise e
          }
        }
      }
      matches = matches && matched
    }
    if matches {
      result.push(index)
    }
  }
  result
}

///|
pub(all) struct Column {
  name : String
  path : Array[Step]
}

///|
pub struct Table {
  priv columns : Array[String]
  priv rows : Array[Array[Array[String]?]]
}

///|
/// Private table. Missing=null, empty=[], VM preserved; unsupported types fail.
pub fn project(
  datasets : Array[@dicom.DataSet],
  columns : Array[Column],
) -> Table raise QueryError {
  if datasets.length() > 10000 || columns.is_empty() || columns.length() > 64 {
    raise BudgetExceeded
  }
  let seen : Map[String, Bool] = Map([])
  for column in columns {
    if column.name.is_empty() ||
      column.name.length() > 64 ||
      seen.contains(column.name) {
      raise InvalidPath
    }
    seen.set(column.name, true)
  }
  let rows : Array[Array[Array[String]?]] = []
  let mut budget = 16 * 1024 * 1024
  for dataset in datasets {
    let row : Array[Array[String]?] = []
    for column in columns {
      let cell = Some(values(dataset, column.path)) catch {
        Missing => None
        e => raise e
      }
      if cell is Some(items) {
        for value in items {
          let size = @utf8.encode(value).length()
          if size > budget {
            raise BudgetExceeded
          }
          budget = budget - size
        }
      }
      row.push(cell)
    }
    rows.push(row)
  }
  { columns: columns.map(c => c.name), rows, }
}

///|
fn quote_csv(text : String) -> String {
  // Guard formula prefixes, including those hidden by leading whitespace.
  let stripped = text.trim_start().to_owned()
  let guarded = if stripped.has_prefix("=") ||
    stripped.has_prefix("+") ||
    stripped.has_prefix("-") ||
    stripped.has_prefix("@") ||
    text.has_prefix("\t") ||
    text.has_prefix("\r") ||
    text.has_prefix("\n") {
    "'" + text
  } else {
    text
  }
  "\"" +
  guarded.split("\"").map(s => s.to_owned()).to_array().join("\"\"") +
  "\""
}

///|
/// RFC 4180 quoting and spreadsheet formula protection; still private content.
pub fn Table::private_csv(self : Table) -> String {
  let lines = [self.columns.map(quote_csv).join(",")]
  for row in self.rows {
    lines.push(
      row
      .map(cell => {
        quote_csv(
          match cell {
            None => ""
            Some(v) => v.join("\\")
          },
        )
      })
      .join(","),
    )
  }
  lines.join("\r\n") + "\r\n"
}

///|
pub fn Table::private_jsonl(self : Table) -> String {
  let lines : Array[String] = []
  for row in self.rows {
    let fields : Map[String, Json] = Map([])
    for i, name in self.columns {
      fields.set(
        name,
        match row[i] {
          None => Json::null()
          Some(v) => Json::array(v.map(Json::string))
        },
      )
    }
    lines.push(Json::object(fields).stringify())
  }
  if lines.is_empty() {
    ""
  } else {
    lines.join("\n") + "\n"
  }
}

///|
/// Values of grouping keys are private. Missing and empty have different keys.
pub fn group_counts(
  datasets : Array[@dicom.DataSet],
  path : Array[Step],
) -> Array[(String, Int)] raise QueryError {
  if datasets.length() > 10000 {
    raise BudgetExceeded
  }
  let counts : Map[String, Int] = Map([])
  for dataset in datasets {
    let key = Json::array(values(dataset, path).map(Json::string)).stringify() catch {
      Missing => "null"
      e => raise e
    }
    counts.set(key, counts.get(key).unwrap_or(0) + 1)
  }
  let keys = counts.keys().to_array()
  keys.sort()
  keys.map(key => (key, counts.get(key).unwrap()))
}

///|
/// Versioned aggregate inventory, no paths, keys, patient values or UIDs.
pub fn summary(
  datasets : Array[@dicom.DataSet],
  columns : Array[Column],
) -> Json raise QueryError {
  let table = project(datasets, columns)
  let missing : Map[String, Json] = Map([])
  for i, column in columns {
    let count = table.rows.filter(row => row[i] is None).length()
    missing.set(column.name, Json::number(count.to_double()))
  }
  let studies : Map[String, Bool] = Map([])
  let series : Map[String, Bool] = Map([])
  for dataset in datasets {
    if dataset.find(@dicom.Tag::new(0x0020U, 0x000DU))
      is Some({ value: @dicom.ElementValue::Text(uid), .. }) {
      studies.set(uid, true)
    }
    if dataset.find(@dicom.Tag::new(0x0020U, 0x000EU))
      is Some({ value: @dicom.ElementValue::Text(uid), .. }) {
      series.set(uid, true)
    }
  }
  Json::object(
    Map::from_array([
      ("schema", Json::string("medseal-inventory-v1")),
      ("objects", Json::number(datasets.length().to_double())),
      ("studies", Json::number(studies.length().to_double())),
      ("series", Json::number(series.length().to_double())),
      ("missing_fields", Json::object(missing)),
      ("release_authorized", Json::boolean(false)),
    ]),
  )
}

///|
pub extend Step with Eq::{equal, not_equal}

///|
pub extend Step with Debug::{to_repr}

///|
pub extend QueryError with Debug::{to_repr}

///|
pub extend Predicate with Debug::{to_repr}

///|
pub fn QueryError::code(self : QueryError) -> String {
  match self {
    Missing => "QUERY-MISSING"
    TypeMismatch => "QUERY-TYPE"
    MultipleValues => "QUERY-VM"
    InvalidNumber => "QUERY-NUMBER"
    InvalidPath => "QUERY-PATH"
    BudgetExceeded => "QUERY-BUDGET"
  }
}
