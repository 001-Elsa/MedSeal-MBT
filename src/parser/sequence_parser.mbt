///|
// Sequence parsing lives beside ordinary element parsing because both branches
// share the same bounded reader and global element counter.
pub let max_sequence_depth : Int = 32
