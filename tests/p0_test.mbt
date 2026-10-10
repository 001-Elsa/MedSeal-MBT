///|
async test "P0 discovery includes extensionless Part 10 and counts excluded files" {
  let root = @async_fs.tmpdir(prefix="medseal-discovery")
  defer @async_fs.rmdir(root, recursive=true)
  @storage.write_new(
    "\{root}/no-extension",
    object_bytes("A", "1.2.3", "1.2.10", "1.2.20", "20240228"),
  )
  @storage.write_new("\{root}/notes.txt", b"not medical data")
  let discovered = @inventory.discover(root)
  assert_eq(discovered.candidates.length(), 1)
  assert_eq(discovered.excluded.length(), 1)
  let job = @batch.plan(root, @policy.research())
  assert_true(job.preview().contains("excluded_non_part10"))
  let output = "\{root}-output"
  defer (@async_fs.rmdir(output, recursive=true) catch { _ => () })
  let result = job.execute(output)
  assert_true(result.contains("\"release_authorized\": false"))
  ignore(@batch.verify(output))
}

///|
async test "P0 storage failures after partial data and before sync never publish" {
  for operation in ["create", "after-partial-write", "before-sync", "publish"] {
    for occurrence in (if operation == "publish" { [1] } else { [1, 3] }) {
      let root = @async_fs.tmpdir(prefix="medseal-fault")
      defer @async_fs.rmdir(root, recursive=true)
      let input = "\{root}/input"
      @storage.mkdir(input)
      @storage.write_new(
        "\{input}/a.dcm",
        object_bytes("A", "1.2.3", "1.2.10", "1.2.20", "20240228"),
      )
      @storage.write_new(
        "\{input}/b.dcm",
        object_bytes("A", "1.2.4", "1.2.10", "1.2.21", "20240313"),
      )
      let job = @batch.plan(input, @policy.research())
      let rejected = try {
        ignore(
          job.execute(
            "\{root}/output",
            faults=Some(@storage.Faults::new(operation, occurrence~)),
          ),
        )
        false
      } catch {
        @model.MedSealError::IoError(_) => true
        _ => false
      }
      assert_true(rejected)
      assert_eq(@storage.list(root), ["input"])
    }
  }
}

///|
async test "P0 mutation after first verified object is detected during execution" {
  let root = @async_fs.tmpdir(prefix="medseal-mutation")
  defer @async_fs.rmdir(root, recursive=true)
  let input = "\{root}/input"
  @storage.mkdir(input)
  @storage.write_new(
    "\{input}/a.dcm",
    object_bytes("A", "1.2.3", "1.2.10", "1.2.20", "20240228"),
  )
  @storage.write_new(
    "\{input}/b.dcm",
    object_bytes("A", "1.2.4", "1.2.10", "1.2.21", "20240313"),
  )
  let job = @batch.plan(input, @policy.research())
  let rejected = try {
    ignore(
      job.execute(
        "\{root}/output",
        checkpoint=Some(async fn(event, index) raise @model.MedSealError {
          if event == "object-verified" && index == 0 {
            @async_fs.remove("\{input}/b.dcm") catch {
              _ => raise @model.MedSealError::IoError("test mutation failed")
            }
            @storage.write_new("\{input}/b.dcm", b"changed while executing")
          }
        }),
      ),
    )
    false
  } catch {
    @model.MedSealError::IoError(_) => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@storage.list(root), ["input"])
}

///|
async test "P0 target created at publication boundary is not overwritten" {
  let root = @async_fs.tmpdir(prefix="medseal-target-race")
  defer @async_fs.rmdir(root, recursive=true)
  let input = "\{root}/input"
  @storage.mkdir(input)
  @storage.write_new(
    "\{input}/a.dcm",
    object_bytes("A", "1.2.3", "1.2.10", "1.2.20", "20240228"),
  )
  let job = @batch.plan(input, @policy.research())
  let rejected = try {
    ignore(
      job.execute(
        "\{root}/output",
        checkpoint=Some(async fn(event, _) raise @model.MedSealError {
          if event == "before-publication" {
            @storage.mkdir("\{root}/output")
            @storage.write_new("\{root}/output/owner", b"other owner")
          }
        }),
      ),
    )
    false
  } catch {
    @model.MedSealError::IoError(_) => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@storage.read("\{root}/output/owner"), b"other owner")
  assert_eq(@storage.list(root), ["input", "output"])
}

///|
async test "P0 bounded reader accepts limit and rejects limit plus one" {
  let root = @async_fs.tmpdir(prefix="medseal-read-boundary")
  defer @async_fs.rmdir(root, recursive=true)
  @storage.write_new("\{root}/file", b"12345678")
  assert_eq(@storage.read("\{root}/file", limit=8).length(), 8)
  assert_eq(@storage.read("\{root}/file", limit=9).length(), 8)
  let rejected = try {
    ignore(@storage.read("\{root}/file", limit=7))
    false
  } catch {
    @model.MedSealError::FileTooLarge(_) => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "P0 SV and UV use extended VR header and eight byte value units" {
  for vr in [@model.Vr::SV, @model.Vr::UV] {
    assert_true(vr.uses_u32_length())
    let dataset = @model.DataSet::new([
      @model.DataElement::new(
        @model.Tag::new(0x7776U, 0x0010U),
        vr,
        8U,
        @model.ElementValue::Raw(b"12345678"),
        0,
      ),
    ])
    let writer = @byteio.ByteWriter::new()
    @dicom_writer.write_element(writer, dataset.elements[0])
    let bytes = writer.to_bytes()
    assert_eq(bytes.length(), 20)
    assert_eq(
      @parser.parse_dataset_bytes(bytes).elements[0].value,
      @model.ElementValue::Raw(b"12345678"),
    )
  }
}
