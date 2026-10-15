///|
/// Tiny synthetic SC objects, not clinical images. This package deliberately
/// constructs and serializes them using only public MedSeal imports.
pub fn object(
  sop : String,
  reference? : String? = None,
  name? : String = "SDKCANARY^SYNTHETIC",
) -> Bytes raise @dicom.MedSealError {
  fn text(
    g : UInt,
    e : UInt,
    vr : @dicom.Vr,
    value : String,
  ) -> @dicom.DataElement {
    @dicom.DataElement::new(
      @dicom.Tag::new(g, e),
      vr,
      0U,
      @dicom.ElementValue::Text(value),
      0,
    )
  }
  let sop_class = "1.2.840.10008.5.1.4.1.1.7"
  let elements = [
    text(0x0008U, 0x0016U, @dicom.Vr::UI, sop_class),
    text(0x0008U, 0x0018U, @dicom.Vr::UI, sop),
    text(0x0008U, 0x0060U, @dicom.Vr::CS, "OT"),
    text(0x0008U, 0x0064U, @dicom.Vr::CS, "WSD"),
    text(0x0020U, 0x000DU, @dicom.Vr::UI, "1.2.826.0.1.999.10"),
    text(0x0020U, 0x000EU, @dicom.Vr::UI, "1.2.826.0.1.999.11"),
    text(0x0028U, 0x0004U, @dicom.Vr::CS, "MONOCHROME2"),
    text(0x0010U, 0x0010U, @dicom.Vr::PN, name),
    text(0x0010U, 0x0020U, @dicom.Vr::LO, "SDKCANARY-ID"),
    text(0x0008U, 0x0020U, @dicom.Vr::DA, "20240229"),
    text(0x0010U, 0x0030U, @dicom.Vr::DA, ""),
    text(0x0010U, 0x0040U, @dicom.Vr::CS, ""),
    text(0x0008U, 0x0030U, @dicom.Vr::TM, ""),
    text(0x0008U, 0x0070U, @dicom.Vr::LO, ""),
    text(0x0008U, 0x0090U, @dicom.Vr::PN, ""),
    text(0x0020U, 0x0010U, @dicom.Vr::SH, ""),
    text(0x0008U, 0x0050U, @dicom.Vr::SH, ""),
    text(0x0020U, 0x0011U, @dicom.Vr::IS, "1"),
    text(0x0020U, 0x0013U, @dicom.Vr::IS, "1"),
    text(0x0020U, 0x0020U, @dicom.Vr::CS, ""),
    text(0x0008U, 0x103EU, @dicom.Vr::LO, "SDKCANARY-DESCRIPTION"),
  ]
  for
    (e, value) in [
      (0x0002U, 1U),
      (0x0010U, 2U),
      (0x0011U, 2U),
      (0x0100U, 8U),
      (0x0101U, 8U),
      (0x0102U, 7U),
      (0x0103U, 0U),
    ] {
    elements.push(
      @dicom.DataElement::new(
        @dicom.Tag::new(0x0028U, e),
        @dicom.Vr::US,
        2U,
        @dicom.ElementValue::UnsignedShort([value]),
        0,
      ),
    )
  }
  elements.push(
    @dicom.DataElement::new(
      @dicom.Tag::new(0x7FE0U, 0x0010U),
      @dicom.Vr::OB,
      4U,
      @dicom.ElementValue::Raw(b"\x01\x02\x03\x04"),
      0,
    ),
  )
  if reference is Some(uid) {
    elements.push(
      @dicom.DataElement::new(
        @dicom.Tag::new(0x0008U, 0x1140U),
        @dicom.Vr::SQ,
        0U,
        @dicom.ElementValue::Sequence([
          @dicom.DataSet::new([
            text(0x0008U, 0x1150U, @dicom.Vr::UI, sop_class),
            text(0x0008U, 0x1155U, @dicom.Vr::UI, uid),
          ]),
        ]),
        0,
      ),
    )
  }
  let parsed : @dicom.ParsedFile = {
    preamble: Bytes::make(128, b'\x00'),
    file_meta: @dicom.DataSet::new([
      text(0x0002U, 0x0002U, @dicom.Vr::UI, sop_class),
      text(0x0002U, 0x0003U, @dicom.Vr::UI, sop),
      text(0x0002U, 0x0010U, @dicom.Vr::UI, "1.2.840.10008.1.2.1"),
      text(0x0002U, 0x0012U, @dicom.Vr::UI, "1.2.826.0.1.999"),
    ]),
    dataset: @dicom.DataSet::new(elements).canonical(),
    transfer_syntax: "1.2.840.10008.1.2.1",
    element_count: elements.length(),
  }
  @dicom.write(parsed)
}

///|
pub fn linked_pair() -> Array[Bytes] raise @dicom.MedSealError {
  let first = "1.2.826.0.1.999.1"
  [object(first), object("1.2.826.0.1.999.2", reference=Some(first))]
}
