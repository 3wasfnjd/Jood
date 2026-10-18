"""Shrink Joud's embedded texture inside a place file (one-time asset step).

Reads ReplicatedStorage/HaraShared/JoudEmbeddedAssets/Texture (base64 of zstd RGBA),
resizes it, writes it back and updates the Manifest. Mesh data is left untouched.

usage: python3 tools/lighten_joud.py IN.rbxlx OUT.rbxlx --size 512
"""

import argparse
import base64
import ctypes
import ctypes.util
import hashlib
import re
import xml.etree.ElementTree as ET

from PIL import Image

_z = ctypes.CDLL(ctypes.util.find_library("zstd") or "libzstd.so.1")
_z.ZSTD_getFrameContentSize.restype = ctypes.c_ulonglong
_z.ZSTD_decompress.restype = ctypes.c_size_t
_z.ZSTD_compress.restype = ctypes.c_size_t
_z.ZSTD_compressBound.restype = ctypes.c_size_t
_z.ZSTD_isError.restype = ctypes.c_uint


def zstd_decompress(data: bytes) -> bytes:
    size = _z.ZSTD_getFrameContentSize(data, len(data))
    if size >= 2**63:
        raise ValueError("unknown zstd content size")
    out = ctypes.create_string_buffer(size)
    n = _z.ZSTD_decompress(out, size, data, len(data))
    if _z.ZSTD_isError(n):
        raise ValueError("zstd decompress failed")
    return out.raw[:n]


def zstd_compress(data: bytes, level: int = 19) -> bytes:
    bound = _z.ZSTD_compressBound(len(data))
    out = ctypes.create_string_buffer(bound)
    n = _z.ZSTD_compress(out, bound, data, len(data), level)
    if _z.ZSTD_isError(n):
        raise ValueError("zstd compress failed")
    return out.raw[:n]


def name_of(item):
    return item.findtext("Properties/string[@name='Name']")


def child(item, name):
    for c in item.findall("Item"):
        if name_of(c) == name:
            return c
    raise KeyError(name)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("place")
    ap.add_argument("output")
    ap.add_argument("--size", type=int, default=512)
    a = ap.parse_args()

    tree = ET.parse(a.place)
    root = tree.getroot()
    rs = next(i for i in root.findall("Item") if i.get("class") == "ReplicatedStorage")
    assets = child(child(rs, "HaraShared"), "JoudEmbeddedAssets")
    tex = child(assets, "Texture")
    manifest = child(assets, "Manifest")
    msrc = manifest.find("Properties/ProtectedString[@name='Source']")

    chunks = sorted(tex.findall("Item"), key=name_of)
    chunk_len = max(len(c.findtext("Properties/string[@name='Value']") or "") for c in chunks)
    raw = zstd_decompress(base64.b64decode("".join(c.findtext("Properties/string[@name='Value']") for c in chunks)))
    old = int(round((len(raw) / 4) ** 0.5))
    assert old * old * 4 == len(raw), "texture is not square RGBA"
    print(f"old texture {old}x{old}, {len(raw)} bytes")

    img = Image.frombytes("RGBA", (old, old), raw).resize((a.size, a.size), Image.LANCZOS)
    new_raw = img.tobytes()
    b64 = base64.b64encode(zstd_compress(new_raw)).decode()
    pieces = [b64[i : i + chunk_len] for i in range(0, len(b64), chunk_len)]

    # replace chunk items, reusing the first as a template
    template = chunks[0]
    for c in chunks:
        tex.remove(c)
    import copy

    for i, piece in enumerate(pieces, 1):
        item = copy.deepcopy(template)
        item.set("referent", f"RBXJOUDTEX{i:04d}")
        item.find("Properties/string[@name='Name']").text = f"{i:04d}"
        item.find("Properties/string[@name='Value']").text = piece
        tex.append(item)

    src = msrc.text
    src = re.sub(r'\["textureSize"\]=\d+', f'["textureSize"]={a.size}', src)
    tex_entry = (
        f'["texture"]={{["chunks"]={len(pieces)},["bytes"]={len(new_raw)},'
        f'["sha256"]="{hashlib.sha256(new_raw).hexdigest()}"}}'
    )
    src, n = re.subn(r'\["texture"\]=\{[^}]*\}', tex_entry, src)
    assert n == 1, "manifest texture entry not found"
    msrc.text = src

    tree.write(a.output, encoding="utf-8", xml_declaration=True)
    print(f"new texture {a.size}x{a.size}: {len(pieces)} chunks (was {len(chunks)}), {len(new_raw)} raw bytes")
    img.convert("RGB").save(a.output + ".texture-preview.jpg", quality=85)


if __name__ == "__main__":
    main()
