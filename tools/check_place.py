"""Structural check of the built Jood.rbxlx."""
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def name_of(i):
    return i.findtext("Properties/string[@name='Name']")


def main(path):
    root = ET.parse(path).getroot()
    services = {i.get("class"): i for i in root.findall("Item")}
    errors = []

    def node(cls, *names):
        n = services.get(cls)
        for name in names:
            n = next((c for c in n.findall("Item") if name_of(c) == name), None) if n is not None else None
        return n

    expected = []
    for f in (ROOT / "src/shared").glob("*.luau"):
        expected.append(("ModuleScript", node("ReplicatedStorage", "HaraShared", f.stem), f))
    for f in (ROOT / "src/server").glob("*.server.luau"):
        expected.append(("Script", node("ServerScriptService", f.name[:-12]), f))
    for f in (ROOT / "src/client").glob("*.client.luau"):
        expected.append(("LocalScript", node("StarterPlayer", "StarterPlayerScripts", f.name[:-12]), f))
    for cls, item, f in expected:
        if item is None or item.get("class") != cls:
            errors.append(f"missing {cls} for {f.name}")
            continue
        src = item.findtext("Properties/ProtectedString[@name='Source']") or ""
        if src != f.read_text(encoding="utf-8"):
            errors.append(f"source mismatch {f.name}")
        else:
            print(f"ok   {cls:12s} {f.name}")

    for label, n in [
        ("Workspace/Hara/Interactables", node("Workspace", "Hara", "Interactables")),
        ("Workspace/Hara/Joud", node("Workspace", "Hara", "Joud")),
        ("Workspace/Hara/Markers/Patrol", node("Workspace", "Hara", "Markers", "Patrol")),
        ("RestHouse/Patrol", node("Workspace", "Hara", "Architecture", "RestHouse", "Patrol")),
        ("JoudEmbeddedAssets", node("ReplicatedStorage", "HaraShared", "JoudEmbeddedAssets")),
        ("RestHouseEmbeddedAssets", node("ReplicatedStorage", "HaraShared", "RestHouseEmbeddedAssets")),
    ]:
        if n is None:
            errors.append("missing " + label)
        else:
            print("ok   " + label)

    if errors:
        print("\nFAILED:\n  - " + "\n  - ".join(errors))
        sys.exit(1)
    print("\nPlace file structure OK")


if __name__ == "__main__":
    main(sys.argv[1])
