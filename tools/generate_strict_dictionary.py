#!/usr/bin/env python3
"""Generate an explicitly reviewed subset from pinned pydicom dictionary data.

This is data generation, not a copied parser or privacy implementation.
Unknown attributes remain unsupported; membership is not a safety decision.
"""
from pathlib import Path
import hashlib
import json
import sys
REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO.parent / "moonbit工具链/python-packages"))
import pydicom
from pydicom.datadict import DicomDictionary

ROLES = {
    "identity": "00100010 00100020",
    "instance-uid": "00080018 0020000D 0020000E 00200052 00081155",
    "standard-uid": "00080016 00081150",
    "shift-da": "00080020 00080021 00080022 00080023",
    "empty": "0008002A 00080030 00080031 00080032 00080033 00080050 00080070 00080080 00080081 00080090 00081048 00081050 00081070 00100021 00100030 00100040 00101000 00101001 00181000 00200010 00321032 00400241",
    "descriptive": "00081030 0008103E 00181030 00204000",
    "remove": "00180015 00080012 00080013 00080015 00080201 00081010 00081040 00101010 00101020 00101030 00102160 001021B0 00104000 00181002 00181004 00400275 00400555 04000561 FFFA FFFCFFFC",
    "sequence": "00081140",
    "keep": "00120063 00080005 00080008 00080060 00080064 00180020 00180021 00180022 00180023 00180050 00180060 00180080 00180081 00180082 00180083 00180084 00180085 00180086 00180087 00180088 00180089 00180090 00180091 00180093 00180094 00181310 00181312 00181314 00181315 00185100 00200011 00200012 00200013 00200020 00200032 00200037 00200060 00201040 00201041 00280002 00280004 00280006 00280008 00280009 00280010 00280011 00280030 00280100 00280101 00280102 00280103 00280301 00281050 00281051 00281052 00281053 00281054 00282110 00282112 00282114 7FE00010",
}


def main():
    if pydicom.__version__ != "3.0.1":
        raise RuntimeError("pydicom 3.0.1 is required for reproducible dictionary data")
    rows = []
    for role, tags in ROLES.items():
        for text in tags.split():
            if len(text) != 8:
                continue  # wildcard groups handled by the explicit privacy classifier
            value = int(text, 16)
            vr, vm, name, retired, keyword = DicomDictionary[value]
            rows.append({"tag": text, "vr": vr, "vm": vm, "name": keyword,
                         "role": role, "retired": bool(retired)})
    rows.sort(key=lambda x: x["tag"])
    data = {"schema": 1, "dictionary": "pydicom-3.0.1", "standard_rules": "DICOM-2025e-reviewed-subset",
            "scope": "Reviewed attributes only; not complete IOD or Annex E conformance", "attributes": rows}
    raw = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    folder = REPO / "resources/rules"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "strict-v1.json").write_text(raw)
    digest = hashlib.sha256(raw.encode()).hexdigest()
    lines = ["// Generated dictionary data by tools/generate_strict_dictionary.py; see THIRD_PARTY.md.",
             "///|", "pub(all) struct Attribute {", "  vr : String", "  vm : String", "  role : String", "  name : String", "}",
             "///|", f'pub let strict_dictionary_digest : String = "{digest}"',
             "///|", "pub fn strict_attribute(tag : @model.Tag) -> Attribute? {", "  match (tag.group, tag.element) {"]
    for row in rows:
        lines.append(f'    (0x{row["tag"][:4]}U, 0x{row["tag"][4:]}U) => Some({{ vr: "{row["vr"]}", vm: "{row["vm"]}", role: "{row["role"]}", name: "{row["name"]}" }})')
    lines += ["    _ => None", "  }", "}", ""]
    (REPO / "src/dictionary/strict_attributes.mbt").write_text("\n".join(lines))
    print(f"Generated {len(rows)} reviewed attributes; digest {digest}")


if __name__ == "__main__":
    main()
