#!/usr/bin/env python3
"""Verify Android Bundle native ELF 16-KiB program-header alignment.

Checks PT_LOAD p_align of *every* shipped arm64 shared library, not just
bundle metadata. The separate bundletool dump-config check verifies the
package alignment requested by Android App Bundles.
"""
from __future__ import annotations

import argparse
import struct
import sys
import zipfile

ALIGN = 16 * 1024


def load_alignment(elf: bytes, name: str) -> list[int]:
    if len(elf) < 64 or elf[:4] != b"\x7fELF":
        raise ValueError(f"{name}: invalid ELF header")
    elf_class, endian = elf[4], elf[5]
    if endian != 1 or elf_class not in (1, 2):
        raise ValueError(f"{name}: unsupported ELF class/endian {elf_class}/{endian}")
    if elf_class == 2:
        header_offset, size_offset, count_offset = 32, 54, 56
        off_align, entry_min = 48, 56
        fmt = "<Q"
    else:
        header_offset, size_offset, count_offset = 28, 42, 44
        off_align, entry_min = 28, 32
        fmt = "<I"
    ph_offset = struct.unpack_from(fmt, elf, header_offset)[0]
    ph_entry_size = struct.unpack_from("<H", elf, size_offset)[0]
    ph_count = struct.unpack_from("<H", elf, count_offset)[0]
    if ph_count == 0 or ph_entry_size < entry_min:
        raise ValueError(f"{name}: missing/invalid program headers")
    if ph_offset + ph_entry_size * ph_count > len(elf):
        raise ValueError(f"{name}: truncated ELF program headers")
    alignments: list[int] = []
    for index in range(ph_count):
        entry = ph_offset + index * ph_entry_size
        segment_type = struct.unpack_from("<I", elf, entry)[0]
        if segment_type == 1:  # PT_LOAD
            alignments.append(struct.unpack_from(fmt, elf, entry + off_align)[0])
    if not alignments:
        raise ValueError(f"{name}: no PT_LOAD segments")
    return alignments


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundle", help="Android App Bundle (.aab)")
    args = parser.parse_args()
    failures: list[str] = []
    checked = 0
    with zipfile.ZipFile(args.bundle) as archive:
        libs = sorted(
            name for name in archive.namelist()
            if "/lib/" in name and name.endswith(".so")
        )
        if not libs:
            raise ValueError("No native .so libraries present in bundle")
        for name in libs:
            alignments = load_alignment(archive.read(name), name)
            minimum = min(alignments)
            checked += 1
            print(f"{name}: min PT_LOAD alignment {minimum} bytes")
            if minimum < ALIGN:
                failures.append(f"{name}: {minimum} < {ALIGN}")
    if failures:
        print("FAIL: 16 KiB ELF alignment:\n  " + "\n  ".join(failures), file=sys.stderr)
        return 1
    print(f"PASS: {checked} native libraries have all PT_LOAD alignments >= {ALIGN} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
