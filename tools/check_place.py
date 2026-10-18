"""Structural check of the built Jood.rbxlx: every script exists, has source, and sits where Roblox will run it."""

import sys
import xml.etree.ElementTree as ET

EXPECTED = {
    # name: (class, parent chain suffix)
    "Main": ("Script", ["ServerScriptService", "Server"]),
    "MapBuilder": ("ModuleScript", ["ServerScriptService", "Server"]),
    "Lamp": ("ModuleScript", ["ServerScriptService", "Server"]),
    "Jood": ("ModuleScript", ["ServerScriptService", "Server"]),
    "Config": ("ModuleScript", ["ReplicatedStorage", "Shared"]),
    "Hud": ("LocalScript", ["StarterPlayer", "StarterPlayerScripts", "Client"]),
}


def name_of(item):
    props = item.find("Properties")
    if props is None:
        return None
    for p in props:
        if p.get("name") == "Name":
            return p.text
    return None


def prop(item, key):
    props = item.find("Properties")
    if props is None:
        return None
    for p in props:
        if p.get("name") == key:
            return p
    return None


def walk(item, chain, found):
    cls = item.get("class")
    name = name_of(item) or cls
    path = chain + [name]
    if name in EXPECTED:
        found.setdefault(name, []).append((cls, chain, item))
    for child in item.findall("Item"):
        walk(child, path, found)


def main(path):
    root = ET.parse(path).getroot()
    found = {}
    services = {}
    for item in root.findall("Item"):
        services[item.get("class")] = item
        walk(item, [], found)

    errors = []
    for name, (cls, parents) in EXPECTED.items():
        hits = [h for h in found.get(name, []) if h[0] == cls]
        if len(hits) != 1:
            errors.append(f"{name}: expected one {cls}, found {len(hits)}")
            continue
        _, chain, item = hits[0]
        if chain[-len(parents):] != parents:
            errors.append(f"{name}: wrong place {'/'.join(chain)}")
        src = prop(item, "Source")
        if src is None or not (src.text or "").strip():
            errors.append(f"{name}: empty Source")
        else:
            print(f"ok   {'/'.join(chain + [name])} ({cls}, {len(src.text)} chars)")

    lighting = services.get("Lighting")
    clock = prop(lighting, "ClockTime") if lighting is not None else None
    if clock is None or float(clock.text) != 0:
        errors.append("Lighting.ClockTime is not 0 (night)")
    else:
        print("ok   Lighting is set to night")

    players = services.get("Players")
    auto = prop(players, "CharacterAutoLoads") if players is not None else None
    if auto is None or auto.text != "false":
        errors.append("Players.CharacterAutoLoads should be false")
    else:
        print("ok   CharacterAutoLoads = false")

    if errors:
        print("\nFAILED:")
        for e in errors:
            print("  -", e)
        sys.exit(1)
    print("\nPlace file structure OK")


if __name__ == "__main__":
    main(sys.argv[1])
