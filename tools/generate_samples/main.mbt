///|
fn text(
  tag : @model.Tag,
  vr : @model.Vr,
  value : String,
  order : Int,
) -> @model.DataElement {
  @model.DataElement::new(
    tag,
    vr,
    @utf8.encode(value).length().reinterpret_as_uint(),
    @model.ElementValue::Text(value),
    order,
  )
}

///|
fn us(
  group : UInt,
  element : UInt,
  value : UInt,
  order : Int,
) -> @model.DataElement {
  @model.DataElement::new(
    @model.Tag::new(group, element),
    @model.Vr::US,
    2U,
    @model.ElementValue::UnsignedShort([value]),
    order,
  )
}

///|
fn raw(
  tag : @model.Tag,
  vr : @model.Vr,
  value : Bytes,
  order : Int,
) -> @model.DataElement {
  @model.DataElement::new(
    tag,
    vr,
    value.length().reinterpret_as_uint(),
    @model.ElementValue::Raw(value),
    order,
  )
}

///|
fn file_meta(transfer_syntax : String) -> @model.DataSet {
  @model.DataSet::new([
    text(
      @model.Tag::new(0x0002U, 0x0002U),
      @model.Vr::UI,
      "1.2.840.10008.5.1.4.1.1.7",
      0,
    ),
    text(
      @model.Tag::new(0x0002U, 0x0003U),
      @model.Vr::UI,
      "1.2.826.0.1.3680043.10.999.1",
      1,
    ),
    text(@model.transfer_syntax_uid_tag, @model.Vr::UI, transfer_syntax, 2),
    text(
      @model.Tag::new(0x0002U, 0x0012U),
      @model.Vr::UI,
      "1.2.826.0.1.3680043.10.999",
      3,
    ),
  ])
}

///|
fn image_metadata() -> Array[@model.DataElement] {
  [
    text(
      @model.Tag::new(0x0008U, 0x0016U),
      @model.Vr::UI,
      "1.2.840.10008.5.1.4.1.1.7",
      0,
    ),
    text(
      @model.Tag::new(0x0008U, 0x0018U),
      @model.Vr::UI,
      "1.2.826.0.1.3680043.10.999.1",
      1,
    ),
    text(
      @model.Tag::new(0x0020U, 0x000DU),
      @model.Vr::UI,
      "1.2.826.0.1.3680043.10.999.2",
      2,
    ),
    text(
      @model.Tag::new(0x0020U, 0x000EU),
      @model.Vr::UI,
      "1.2.826.0.1.3680043.10.999.3",
      3,
    ),
    us(0x0028U, 0x0002U, 1U, 4),
    us(0x0028U, 0x0010U, 2U, 5),
    us(0x0028U, 0x0011U, 2U, 6),
    us(0x0028U, 0x0100U, 8U, 7),
    us(0x0028U, 0x0101U, 8U, 8),
    us(0x0028U, 0x0103U, 0U, 9),
  ]
}

///|
fn patient_elements() -> Array[@model.DataElement] {
  [
    text(@model.Tag::new(0x0010U, 0x0010U), @model.Vr::PN, "TEST^PATIENT", 10),
    text(@model.Tag::new(0x0010U, 0x0020U), @model.Vr::LO, "SYNTHETIC-001", 11),
    text(@model.Tag::new(0x0010U, 0x0030U), @model.Vr::DA, "19700101", 12),
    text(@model.Tag::new(0x0010U, 0x0040U), @model.Vr::CS, "O", 13),
    text(
      @model.Tag::new(0x0008U, 0x0080U),
      @model.Vr::LO,
      "SYNTHETIC HOSPITAL",
      14,
    ),
    text(@model.Tag::new(0x0008U, 0x0090U), @model.Vr::PN, "TEST^DOCTOR", 15),
    text(
      @model.Tag::new(0x0008U, 0x1030U),
      @model.Vr::LO,
      "Synthetic Study",
      16,
    ),
    text(
      @model.Tag::new(0x0008U, 0x103EU),
      @model.Vr::LO,
      "Synthetic Series",
      17,
    ),
    text(
      @model.Tag::new(0x0018U, 0x1030U),
      @model.Vr::LO,
      "Synthetic Protocol",
      18,
    ),
  ]
}

///|
fn parsed(
  dataset : @model.DataSet,
  transfer_syntax? : String = @parser.explicit_vr_little_endian_uid,
) -> @parser.ParsedFile {
  {
    preamble: Bytes::make(128, b'\x00'),
    file_meta: file_meta(transfer_syntax),
    dataset,
    transfer_syntax,
    element_count: dataset.count_recursive() + 4,
  }
}

///|
fn write_sample(path : String, value : Bytes) -> Unit raise {
  @fs.write_bytes_to_file(path, value)
}

///|
fn generate() -> Unit raise {
  let image = image_metadata()
  let minimal = @model.DataSet::new(image)
  write_sample(
    "samples/valid/minimal-valid.dcm",
    @dicom_writer.write_bytes(parsed(minimal)),
  )
  let patient_data = @model.DataSet::new(image + patient_elements())
  let patient_file = @dicom_writer.write_bytes(parsed(patient_data))
  write_sample("samples/valid/patient-fields.dcm", patient_file)
  let private = text(
    @model.Tag::new(0x0011U, 0x1010U),
    @model.Vr::LO,
    "SYNTHETIC PRIVATE VALUE",
    19,
  )
  write_sample(
    "samples/valid/private-tags.dcm",
    @dicom_writer.write_bytes(
      parsed(@model.DataSet::new(image + patient_elements() + [private])),
    ),
  )
  let nested_item = @model.DataSet::new([
    text(@model.Tag::new(0x0010U, 0x0010U), @model.Vr::PN, "NESTED^PATIENT", 0),
    text(@model.Tag::new(0x0010U, 0x0020U), @model.Vr::LO, "NESTED-ID", 1),
  ])
  let sequence = @model.DataElement::new(
    @model.Tag::new(0x0040U, 0x0275U),
    @model.Vr::SQ,
    0U,
    @model.ElementValue::Sequence([nested_item]),
    19,
  )
  write_sample(
    "samples/valid/nested-sequence.dcm",
    @dicom_writer.write_bytes(parsed(@model.DataSet::new(image + [sequence]))),
  )
  let pixel = raw(@model.pixel_data_tag, @model.Vr::OB, b"\x00\x40\x80\xFF", 19)
  write_sample(
    "samples/valid/pixel-data.dcm",
    @dicom_writer.write_bytes(
      parsed(@model.DataSet::new(image + patient_elements() + [pixel])),
    ),
  )
  write_sample(
    "samples/input.dcm",
    @dicom_writer.write_bytes(
      parsed(@model.DataSet::new(image + patient_elements() + [private, pixel])),
    ),
  )
  write_sample(
    "samples/invalid/unsupported-transfer-syntax.dcm",
    @dicom_writer.write_bytes(
      parsed(minimal, transfer_syntax="1.2.840.10008.1.2"),
    ),
  )
  let prefix = @dicom_writer.write_bytes(parsed(@model.DataSet::empty()))
  let truncated = @byteio.ByteWriter::new()
  truncated.write_u16_le(0x0010U)
  truncated.write_u16_le(0x0010U)
  truncated.write_ascii("PN")
  truncated.write_u16_le(100U)
  truncated.write_ascii("X")
  write_sample(
    "samples/invalid/truncated-element.dcm",
    prefix + truncated.to_bytes(),
  )
  let invalid_vr = @byteio.ByteWriter::new()
  invalid_vr.write_u16_le(0x0008U)
  invalid_vr.write_u16_le(0x0008U)
  invalid_vr.write_ascii("ZZ")
  invalid_vr.write_u16_le(0U)
  write_sample("samples/invalid/invalid-vr.dcm", prefix + invalid_vr.to_bytes())
  let invalid_sequence = @byteio.ByteWriter::new()
  invalid_sequence.write_u16_le(0x0040U)
  invalid_sequence.write_u16_le(0x0275U)
  invalid_sequence.write_ascii("SQ")
  invalid_sequence.write_u16_le(0U)
  invalid_sequence.write_u32_le(0xFFFFFFFFU)
  invalid_sequence.write_u16_le(0xFFFEU)
  invalid_sequence.write_u16_le(0xE000U)
  invalid_sequence.write_u32_le(0xFFFFFFFFU)
  invalid_sequence.write_u16_le(0x0010U)
  invalid_sequence.write_u16_le(0x0010U)
  invalid_sequence.write_ascii("PN")
  invalid_sequence.write_u16_le(4U)
  invalid_sequence.write_ascii("TEST")
  write_sample(
    "samples/invalid/invalid-sequence.dcm",
    prefix + invalid_sequence.to_bytes(),
  )
  println("Generated synthetic DICOM samples")
}

///|
fn main {
  generate() catch {
    _ => println("Failed to generate samples")
  }
}
