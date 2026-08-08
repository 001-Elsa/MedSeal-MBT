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

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/001-Elsa/MedSeal-MBT"

license = "Apache-2.0"

keywords = [ "dicom", "de-identification", "medical-imaging", "moonbit" ]

preferred_target = "native"

description = "A small DICOM metadata validator and basic de-identification tool written in MoonBit."

import {
  "moonbitlang/async@0.20.4",
  "moonbitlang/x@0.4.48",
}
