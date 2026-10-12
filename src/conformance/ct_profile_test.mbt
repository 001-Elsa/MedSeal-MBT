///|
fn ct_fixture() -> @model.DataSet {
  let text = fn(g : UInt, e : UInt, vr : @model.Vr, value : String) {
    @model.DataElement::new(
      @model.Tag::new(g, e),
      vr,
      value.length().reinterpret_as_uint(),
      @model.Text(value),
      0,
    )
  }
  let us = fn(g : UInt, e : UInt, value : UInt) {
    @model.DataElement::new(
      @model.Tag::new(g, e),
      @model.US,
      2U,
      @model.UnsignedShort([value]),
      0,
    )
  }
  @model.DataSet::new([
    text(0x0008U, 0x0016U, @model.UI, "1.2.840.10008.5.1.4.1.1.2"),
    text(0x0008U, 0x0018U, @model.UI, "1.2.3.4"),
    text(0x0008U, 0x0008U, @model.CS, "ORIGINAL\\PRIMARY\\AXIAL"),
    text(0x0008U, 0x0060U, @model.CS, "CT"),
    text(0x0008U, 0x0020U, @model.DA, "20240229"),
    text(0x0008U, 0x0030U, @model.TM, "120000"),
    text(0x0008U, 0x0050U, @model.SH, ""),
    text(0x0008U, 0x0070U, @model.LO, "SYNTHETIC"),
    text(0x0008U, 0x0090U, @model.PN, ""),
    text(0x0010U, 0x0010U, @model.PN, "PATIENT"),
    text(0x0010U, 0x0020U, @model.LO, "P1"),
    text(0x0010U, 0x0030U, @model.DA, ""),
    text(0x0010U, 0x0040U, @model.CS, ""),
    text(0x0020U, 0x000DU, @model.UI, "1.2.3.5"),
    text(0x0020U, 0x000EU, @model.UI, "1.2.3.6"),
    text(0x0020U, 0x0010U, @model.SH, ""),
    text(0x0020U, 0x0011U, @model.IS, "1"),
    text(0x0020U, 0x0012U, @model.IS, "1"),
    text(0x0020U, 0x0013U, @model.IS, "1"),
    text(0x0020U, 0x0052U, @model.UI, "1.2.3.7"),
    text(0x0020U, 0x1040U, @model.LO, ""),
    text(0x0020U, 0x0032U, @model.DS, "0\\0\\0"),
    text(0x0020U, 0x0037U, @model.DS, "1\\0\\0\\0\\1\\0"),
    text(0x0028U, 0x0004U, @model.CS, "MONOCHROME2"),
    text(0x0028U, 0x0030U, @model.DS, "0.7\\0.7"),
    text(0x0018U, 0x0050U, @model.DS, "1.0"),
    text(0x0018U, 0x0060U, @model.DS, "120"),
    text(0x0028U, 0x1052U, @model.DS, "-1024"),
    text(0x0028U, 0x1053U, @model.DS, "1"),
    text(0x0028U, 0x1054U, @model.LO, "HU"),
    us(0x0028U, 0x0002U, 1U),
    us(0x0028U, 0x0010U, 2U),
    us(0x0028U, 0x0011U, 2U),
    us(0x0028U, 0x0100U, 16U),
    us(0x0028U, 0x0101U, 12U),
    us(0x0028U, 0x0102U, 11U),
    us(0x0028U, 0x0103U, 1U),
    @model.DataElement::new(
      @model.pixel_data_tag,
      @model.OW,
      8U,
      @model.Raw(b"\x00\x00\x01\x00\x02\x00\x03\x00"),
      0,
    ),
  ])
}

///|
fn reject_ct(candidate : @model.DataSet, expected : String) -> Unit raise {
  let result = try {
    @conformance.check_classic_ct(candidate)
    "accepted"
  } catch {
    @model.MedSealError::RuleViolation(id, _, _, _) => id
    _ => "wrong-error"
  }
  assert_eq(result, expected)
}

///|
test "ct-classic-research-v1-valid and ct-classic-research-v1-invalid" {
  let ds = ct_fixture()
  @conformance.check_classic_ct(ds)
  reject_ct(
    ds.replace_text(@model.Tag::new(0x0028U, 0x1054U), "US"),
    "ct-intensity-contract",
  )
  reject_ct(ds.remove(@model.Tag::new(0x0020U, 0x0032U)), "required-type1")
  reject_ct(
    ds.replace_text(@model.Tag::new(0x0008U, 0x0060U), "MR"),
    "ct-classic-sop",
  )
}
