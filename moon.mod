// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "001-Elsa/medseal"

version = "0.4.0"

readme = "README.mbt.md"

repository = "https://github.com/001-Elsa/MedSeal-MBT"

license = "Apache-2.0"

keywords = [ "dicom", "de-identification", "medical-imaging", "moonbit" ]

preferred_target = "native"

description = "DICOM metadata validation, collection-consistent pseudonymization, UID remapping and verified binary rewriting in MoonBit."

import {
  "moonbitlang/async@0.22.4",
  "moonbitlang/x@0.5.5",
  "gmlewis/sha256@0.18.0",
}
