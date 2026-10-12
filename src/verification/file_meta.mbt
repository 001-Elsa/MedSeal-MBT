///|
/// Part 10 SOP identity must agree with the actual dataset before conversion.
pub fn check_file_meta(
  file : @parser.ParsedFile,
) -> Unit raise @model.MedSealError {
  let seen : Map[@model.Tag, Bool] = Map([])
  for element in file.file_meta.elements {
    if seen.contains(element.tag) {
      raise @model.MedSealError::RuleViolation(
        "unique-tags", "dataset", "met", "structure",
      )
    }
    seen.set(element.tag, true)
  }
  for
    (dataset_tag, meta_tag) in [
      (@model.Tag::new(0x0008U, 0x0016U), @model.Tag::new(0x0002U, 0x0002U)),
      (@model.Tag::new(0x0008U, 0x0018U), @model.Tag::new(0x0002U, 0x0003U)),
    ] {
    match (file.dataset.find(dataset_tag), file.file_meta.find(meta_tag)) {
      (
        Some({ vr: @model.UI, value: @model.Text(a), .. }),
        Some({ vr: @model.UI, value: @model.Text(b), .. }),
      ) if !a.is_empty() && a == b => ()
      _ =>
        raise @model.MedSealError::RuleViolation(
          "file-meta-identity",
          "dataset/\{dataset_tag.compact()}",
          "met",
          "structure",
        )
    }
  }
}
