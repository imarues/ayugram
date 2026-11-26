#!/usr/bin/env python3
"""Verify the native renderer ranges against an extracted TelegramUIFramework.

Use when updating the target IPA. A mismatched UUID MUST fail closed; never
copy old addresses to a different binary. No third-party modules required.
"""
import argparse
import pathlib
import re
import struct
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[1]
args = argparse.ArgumentParser(description=__doc__)
args.add_argument("framework", type=pathlib.Path)
b = args.parse_args().framework.read_bytes()
assert struct.unpack_from("<I", b)[0] == 0xFEEDFACF, "Expected thin 64-bit Mach-O"
u32 = lambda p: struct.unpack_from("<I", b, p)[0]
assert u32(4) == 0x0100000C, "Expected ARM64"
src = (ROOT / "src" / "VoidGramArabic.m").read_text()
uuid_bytes = bytes(int(x, 16) for x in re.findall(
    r"0x([0-9a-f]{2})", re.search(r"AGVerifiedUUID\[\] = \{(.*?)\};", src, re.S)[1]))
ranges = [(int(lo, 16), int(hi, 16), name) for lo, hi, name in re.findall(
    r"\{(0x[0-9a-f]+), (0x[0-9a-f]+), (AGRenderer\w+)\}", src)]
p = 32
found_uuid, starts, text_vmaddr = None, None, None
for _ in range(u32(16)):
    cmd, size = struct.unpack_from("<II", b, p)
    if cmd == 0x1B:
        found_uuid = b[p + 8:p + 24]
    if cmd == 0x19 and b[p + 8:p + 24].rstrip(b"\x00") == b"__TEXT":
        text_vmaddr = struct.unpack_from("<Q", b, p + 24)[0]
    if cmd == 0x26:
        offset, length = struct.unpack_from("<II", b, p + 8)
        starts = set()
        acc = shift = address = 0
        for byte in b[offset:offset + length]:
            acc |= (byte & 127) << shift
            if byte & 128:
                shift += 7
            else:
                if not acc:
                    break
                address += acc
                starts.add(address)
                acc = shift = 0
    p += size
assert found_uuid == uuid_bytes, f"Wrong framework UUID: {uuid.UUID(bytes=found_uuid)}"
assert text_vmaddr == 0 and starts
for lo, hi, name in ranges:
    assert lo in starts and hi in starts and not any(lo < x < hi for x in starts), (name, hex(lo), hex(hi))
    print(f"{name}: {lo:#x}–{hi:#x} verified function boundary")

def branch(pc, destination):
    ins = u32(pc)
    imm = ins & 0x3FFFFFF
    imm -= (1 << 26) if imm & (1 << 25) else 0
    assert ins >> 26 in (0b100101, 0b000101) and pc + imm * 4 == destination, hex(pc)

# Action-row update, native context menus, then the menu list's compiler-outlined
# helper. Each reaches the same attributed-string creation routine.
for pc in (0x8ebfb4, 0x239e6d4, 0x23a00ec, 0x23a06fc, 0x906274):
    branch(pc, 0x37a4b24)
branch(0x23a87e0, 0x23b51e8)
branch(0x23b51f0, 0x37a4b24)
branch(0x37a4cf8, 0x51b5140)
# Resolve the final Objective-C stub's selector reference and prove it is
# initWithString:attributes:, not an unrelated Foundation call.
adrp, ldr = u32(0x51b5140), u32(0x51b5144)
assert adrp & 0x9f000000 == 0x90000000 and ldr & 0xffc00000 == 0xf9400000
imm = ((adrp >> 29) & 3) | (((adrp >> 5) & 0x7ffff) << 2)
imm -= (1 << 21) if imm & (1 << 20) else 0
selref = (0x51b5140 & ~4095) + (imm << 12) + (((ldr >> 10) & 4095) * 8)
seladdr = struct.unpack_from("<Q", b, selref)[0] & 0xfffffffff
assert b[seladdr:seladdr + 27] == b"initWithString:attributes:\x00"
print(f"PASS: {uuid.UUID(bytes=found_uuid)}; native action paths reach initWithString:attributes:")
