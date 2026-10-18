"""Build Jood.rbxlx: take the base map (geometry + embedded assets, edited in Studio)
and inject every script from src/ into it. Scripts missing from the base are created.

  src/shared/<Name>.luau            -> ReplicatedStorage/HaraShared/<Name>      (ModuleScript)
  src/server/<Name>.server.luau     -> ServerScriptService/<Name>               (Script)
  src/client/<Name>.client.luau     -> StarterPlayer/StarterPlayerScripts/<Name> (LocalScript)

usage: python3 tools/build_place.py [--base base/Joud-Hara.rbxlx] [--out Jood.rbxlx]
"""

import argparse
import itertools
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_ref = itertools.count(1)

TARGETS = [
    ("shared", ".luau", "ModuleScript", ["ReplicatedStorage", "HaraShared"]),
    ("server", ".server.luau", "Script", ["ServerScriptService"]),
    ("client", ".client.luau", "LocalScript", ["StarterPlayer", "StarterPlayerScripts"]),
]


def name_of(item):
    return item.findtext("Properties/string[@name='Name']")


def find_path(root, path):
    node = next(i for i in root.findall("Item") if i.get("class") == path[0])
    for name in path[1:]:
        node = next(c for c in node.findall("Item") if name_of(c) == name)
    return node


def new_script(cls, name):
    item = ET.Element("Item", {"class": cls, "referent": f"RBXJOODSRC{next(_ref):04d}"})
    props = ET.SubElement(item, "Properties")
    ET.SubElement(props, "string", {"name": "Name"}).text = name
    ET.SubElement(props, "ProtectedString", {"name": "Source"}).text = ""
    if cls != "ModuleScript":
        ET.SubElement(props, "bool", {"name": "Disabled"}).text = "false"
    return item


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default=str(ROOT / "base/Joud-Hara.rbxlx"))
    ap.add_argument("--out", default=str(ROOT / "Jood.rbxlx"))
    a = ap.parse_args()

    tree = ET.parse(a.base)
    root = tree.getroot()
    count = 0
    for folder, suffix, cls, parent_path in TARGETS:
        parent = find_path(root, parent_path)
        for f in sorted((ROOT / "src" / folder).glob("*" + suffix)):
            if folder == "shared" and (f.name.endswith(".server.luau") or f.name.endswith(".client.luau")):
                continue
            name = f.name[: -len(suffix)]
            hits = [c for c in parent.findall("Item") if name_of(c) == name and c.get("class") == cls]
            if len(hits) > 1:
                raise SystemExit(f"duplicate {cls} {name}")
            item = hits[0] if hits else new_script(cls, name)
            if not hits:
                parent.append(item)
            item.find("Properties/ProtectedString[@name='Source']").text = f.read_text(encoding="utf-8")
            print(("updated " if hits else "added   ") + "/".join(parent_path + [name]))
            count += 1
    tree.write(a.out, encoding="utf-8", xml_declaration=True)
    print(f"{count} scripts -> {a.out}")


if __name__ == "__main__":
    main()
