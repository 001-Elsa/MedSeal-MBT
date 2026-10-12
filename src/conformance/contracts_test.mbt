///|
fn fixture() -> @model.DataSet {
  let elements : Array[@model.DataElement] = []
  for
    (g, e, vr, text) in [
      (0x0008U, 0x0016U, @model.UI, "1.2.840.10008.5.1.4.1.1.7"),
      (0x0008U, 0x0018U, @model.UI, "1.2.3.4"),
      (0x0008U, 0x0060U, @model.CS, "OT"),
      (0x0008U, 0x0064U, @model.CS, "WSD"),
      (0x0020U, 0x000DU, @model.UI, "1.2.3"),
      (0x0020U, 0x000EU, @model.UI, "1.2.3.1"),
      (0x0028U, 0x0004U, @model.CS, "MONOCHROME2"),
      (0x0010U, 0x0010U, @model.PN, "CANARY^NAME"),
      (0x0010U, 0x0020U, @model.LO, "CANARY-ID"),
      (0x0008U, 0x0020U, @model.DA, "20240229"),
      (0x0010U, 0x0030U, @model.DA, ""),
      (0x0010U, 0x0040U, @model.CS, ""),
      (0x0008U, 0x0030U, @model.TM, ""),
      (0x0008U, 0x0070U, @model.LO, ""),
      (0x0008U, 0x0090U, @model.PN, ""),
      (0x0020U, 0x0010U, @model.SH, ""),
      (0x0008U, 0x0050U, @model.SH, ""),
      (0x0020U, 0x0011U, @model.IS, "1"),
      (0x0020U, 0x0013U, @model.IS, "1"),
      (0x0020U, 0x0020U, @model.CS, ""),
    ] {
    elements.push(
      @model.DataElement::new(
        @model.Tag::new(g, e),
        vr,
        0U,
        if text.is_empty() {
          @model.Empty
        } else {
          @model.Text(text)
        },
        0,
      ),
    )
  }
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
      @model.DataElement::new(
        @model.Tag::new(0x0028U, e),
        @model.US,
        2U,
        @model.UnsignedShort([value]),
        0,
      ),
    )
  }
  elements.push(
    @model.DataElement::new(
      @model.pixel_data_tag,
      @model.OB,
      4U,
      @model.Raw(b"\x01\x02\x03\x04"),
      0,
    ),
  )
  @model.DataSet::new(elements)
}

///|
fn reject(dataset : @model.DataSet, expected : String) -> Unit raise {
  let result = try {
    @conformance.check(dataset, full_pixels=true)
    "accepted"
  } catch {
    @model.MedSealError::RuleViolation(id, _, _, _) => id
    _ => "wrong-error"
  }
  assert_eq(result, expected)
}

///|
test "basic-values-valid and basic-values-invalid; unique-tags-valid and unique-tags-invalid" {
  let ds = fixture()
  @conformance.check(ds, full_pixels=true)
  reject(
    ds.replace_text(@model.Tag::new(0x0008U, 0x0018U), "INVALID"),
    "basic-values",
  )
  reject(@model.DataSet::new(ds.elements + [ds.elements[0]]), "unique-tags")
}

///|
test "known-public-attribute-valid and known-public-attribute-invalid; reference-context-valid and reference-context-invalid" {
  let ds = fixture()
  @conformance.check(ds)
  reject(
    @model.DataSet::new(
      ds.elements +
      [
        @model.DataElement::new(
          @model.Tag::new(0x7776U, 0x0001U),
          @model.LO,
          0U,
          @model.Text("CANARY"),
          0,
        ),
      ],
    ),
    "known-public-attribute",
  )
  let reference = @model.DataSet::new([
    @model.DataElement::new(
      @model.Tag::new(0x0008U, 0x1150U),
      @model.UI,
      0U,
      @model.Text("1.2.840.10008.5.1.4.1.1.7"),
      0,
    ),
    @model.DataElement::new(
      @model.Tag::new(0x0008U, 0x1155U),
      @model.UI,
      0U,
      @model.Text("1.2.3.4"),
      0,
    ),
  ])
  let add = fn(item) {
    @model.DataSet::new(
      ds.elements +
      [
        @model.DataElement::new(
          @model.Tag::new(0x0008U, 0x1140U),
          @model.SQ,
          0U,
          @model.Sequence([item]),
          0,
        ),
      ],
    )
  }
  @conformance.check(add(reference))
  reject(
    add(@model.DataSet::new(reference.elements + [ds.elements[7]])),
    "reference-context",
  )
}

///|
test "required-type1-valid and required-type1-invalid; required-type2-valid and required-type2-invalid; nonempty-type1-valid and nonempty-type1-invalid; required-sop-conditional-valid and required-sop-conditional-invalid" {
  let ds = fixture()
  @conformance.check(ds)
  reject(ds.remove(@model.Tag::new(0x0008U, 0x0018U)), "required-type1")
  reject(ds.remove(@model.Tag::new(0x0008U, 0x0030U)), "required-type2")
  reject(
    @model.DataSet::new(
      ds.elements.map(fn(e) {
        if e.tag == @model.Tag::new(0x0008U, 0x0018U) {
          @model.DataElement::new(e.tag, e.vr, 0U, @model.Empty, 0)
        } else {
          e
        }
      }),
    ),
    "nonempty-type1",
  )
  reject(ds.remove(@model.Tag::new(0x0008U, 0x0064U)), "required-type1")
  @conformance.check(
    ds.replace_text(
      @model.Tag::new(0x0008U, 0x0016U),
      "1.2.840.10008.5.1.4.1.1.2",
    ),
  ) catch {
    @model.MedSealError::RuleViolation("required-type1", path, _, _) =>
      assert_eq(path, "dataset/0008,0008")
    _ => fail("wrong conditional profile outcome")
  }
}

///|
test "supported-sop-valid and supported-sop-invalid; pixel-high-bit-valid and pixel-high-bit-invalid; pixel-sample-bits-valid and pixel-sample-bits-invalid; pixel-photometric-valid and pixel-photometric-invalid; pixel-single-frame-valid and pixel-single-frame-invalid" {
  let ds = fixture()
  @conformance.check(ds)
  reject(
    ds.replace_text(@model.Tag::new(0x0008U, 0x0016U), "1.2.3.99"),
    "supported-sop",
  )
  let us = fn(element, value) {
    @model.DataSet::new(
      ds.elements.map(fn(e) {
        if e.tag == @model.Tag::new(0x0028U, element) {
          @model.DataElement::new(
            e.tag,
            e.vr,
            2U,
            @model.UnsignedShort([value]),
            0,
          )
        } else {
          e
        }
      }),
    )
  }
  reject(us(0x0102U, 6U), "pixel-high-bit")
  reject(us(0x0002U, 3U), "pixel-sample-bits")
  reject(
    ds.replace_text(@model.Tag::new(0x0028U, 0x0004U), "RGB"),
    "pixel-photometric",
  )
  reject(
    @model.DataSet::new(
      ds.elements +
      [
        @model.DataElement::new(
          @model.Tag::new(0x0028U, 0x0008U),
          @model.IS,
          0U,
          @model.Text("2"),
          0,
        ),
      ],
    ),
    "pixel-single-frame",
  )
}

///|
test "pixel-length-valid and pixel-length-invalid; pixel-representation-valid and pixel-representation-invalid" {
  let ds = fixture()
  @conformance.check_pixel_length(ds, 4)
  let rejected = try {
    @conformance.check_pixel_length(ds, 2)
    false
  } catch {
    @model.MedSealError::RuleViolation("pixel-length", _, _, _) => true
    _ => false
  }
  assert_true(rejected)
  reject(
    @model.DataSet::new(
      ds.elements.map(fn(e) {
        if e.tag == @model.pixel_data_tag {
          @model.DataElement::new(
            e.tag,
            e.vr,
            4U,
            @model.UnsignedShort([1U]),
            0,
          )
        } else {
          e
        }
      }),
    ),
    "pixel-representation",
  )
}

///|
test "condition-resolved-valid and condition-resolved-invalid; true false unknown and Kleene logic" {
  assert_true(@rulebook.require_condition(@rulebook.Met))
  assert_false(@rulebook.require_condition(@rulebook.NotMet))
  let rejected = try {
    ignore(@rulebook.require_condition(@rulebook.Unknown))
    false
  } catch {
    @model.MedSealError::RuleViolation("condition-resolved", _, "unknown", _) =>
      true
    _ => false
  }
  assert_true(rejected)
  assert_eq(@rulebook.Unknown.both(@rulebook.NotMet), @rulebook.NotMet)
  assert_eq(@rulebook.Unknown.both(@rulebook.Met), @rulebook.Unknown)
  assert_eq(@rulebook.Unknown.either(@rulebook.Met), @rulebook.Met)
  assert_eq(
    @rulebook.sop_condition(@model.DataSet::empty(), "1.2.3"),
    @rulebook.Unknown,
  )
  assert_eq(
    @rulebook.presence(
      @model.DataSet::empty(),
      @model.pixel_data_tag,
      complete=false,
    ),
    @rulebook.Unknown,
  )
}
