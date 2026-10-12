///|
pub async fn inspect(
  path : String,
) -> @parser.PixelSpan raise @model.MedSealError {
  let size = @storage.snapshot(path).0
  let span = @parser.index_pixel_prefix(
    @storage.read_prefix(path, 2 * 1024 * 1024),
    size,
  )
  @conformance.check_pixel_length(
    span.parsed.dataset.remove(@model.Tag::new(0x0012U, 0x0063U)),
    span.length,
  )
  span
}

///|
pub async fn produce(
  source : String,
  target : String,
  span : @parser.PixelSpan,
  dataset : @model.DataSet,
  reuse? : Bool = false,
) -> String raise @model.MedSealError {
  let metadata = @dicom_writer.write_deidentified(span.parsed, dataset)
  let writer = @byteio.ByteWriter::new()
  writer.write_bytes(metadata)
  writer.write_u16_le(0x7FE0U)
  writer.write_u16_le(0x0010U)
  writer.write_ascii(span.vr.to_string())
  writer.write_u16_le(0U)
  writer.write_u32_le(span.length.reinterpret_as_uint())
  let prefix = writer.to_bytes()
  let expected = @storage.stream_range(
    source,
    span.offset,
    span.length,
    prefix~,
  )
  if reuse && @storage.exists(target) {
    if @storage.file_digest(target) == expected {
      return expected
    }
    @async_fs.remove(target) catch {
      _ =>
        raise @model.MedSealError::IoError(
          "could not remove owned incomplete streamed object",
        )
    }
  }
  let actual = @storage.stream_range(
    source,
    span.offset,
    span.length,
    prefix~,
    output=Some(target),
  )
  if actual != expected || @storage.file_digest(target) != expected {
    raise @model.MedSealError::OutputVerificationFailed(
      "streamed result checksum differs",
    )
  }
  let written = inspect(target)
  if !@verification.same_values(dataset, written.parsed.dataset) ||
    span.vr != written.vr ||
    span.length != written.length ||
    @storage.stream_range(source, span.offset, span.length) !=
    @storage.stream_range(target, written.offset, written.length) {
    raise @model.MedSealError::OutputVerificationFailed(
      "streamed metadata or pixel span differs",
    )
  }
  expected
}
