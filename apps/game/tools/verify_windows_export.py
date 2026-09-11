#!/usr/bin/env python3
"""Check that the release EXE has an embedded Godot pack, with no sidecars."""
from pathlib import Path
import struct

output = Path(__file__).resolve().parents[1] / "build/windows"
executable = output / "DLUT-Online-Windows.exe"
if set(output.iterdir()) != {executable}:
    raise RuntimeError("Windows distribution must contain only the standalone EXE")
with executable.open("rb") as stream:
    if stream.read(2) != b"MZ":
        raise RuntimeError("Not a Windows executable")
    stream.seek(0x3C)
    pe_offset = struct.unpack("<I", stream.read(4))[0]
    stream.seek(pe_offset)
    if stream.read(6) != b"PE\0\0\x64\x86":
        raise RuntimeError("Expected an x86_64 PE executable")
    stream.seek(-12, 2)
    pack_size, magic = struct.unpack("<Q4s", stream.read(12))
    if magic != b"GDPC" or not 0 < pack_size < executable.stat().st_size - 12:
        raise RuntimeError("Missing embedded Godot resource pack")
    stream.seek(-12 - pack_size, 2)
    if stream.read(4) != b"GDPC":
        raise RuntimeError("Invalid embedded Godot resource pack offset")
print("PASS: standalone Windows x86_64 EXE contains an embedded Godot resource pack")
