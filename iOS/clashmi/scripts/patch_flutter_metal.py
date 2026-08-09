#!/usr/bin/env python3
"""Patch Flutter.framework to force Metal rendering.

On jailbroken (rootless) devices the Flutter engine's Metal availability
probe fails, hitting FML_CHECK(false) in rendering_api_selection.mm and
aborting at startup. This patches ShouldUseMetalRenderer() to unconditionally
return true (mov w0,#1; ret) so the engine initializes Metal normally.

Usage: patch_flutter_metal.py <path-to-Flutter-mach-o>
"""

import re
import struct
import sys

# ShouldUseMetalRenderer() body (arm64, Flutter 3.44.8 engine 0cd6107):
#   stp x20,x19,[sp,#-0x20]!
#   stp x29,x30,[sp,#0x10]
#   add x29,sp,#0x10
#   bl <MTLCreateSystemDefaultDevice stub>
#   mov x19,x0
#   adrp x8,... ; ldr x1,[x8,...]
#   mov w2,#5                       ; MTLFeatureSet_iOS_GPUFamily1_v3
#   bl <objc_msgSend stub>
#   mov x20,x0
#   mov x0,x19
#   bl <objc_release stub>
#   mov x0,x20
#   ldp x29,x30,[sp,#0x10]
#   ldp x20,x19,[sp],#0x20
#   ret
PAT = re.compile(
    b"\xf4\x4f\xbe\xa9\xfd\x7b\x01\xa9\xfd\x43\x00\x91"  # prologue
    b"....\xf3\x03\x00\xaa........\xa2\x00\x80\x52"      # bl; mov x19,x0; adrp; ldr; mov w2,#5
    b"....\xf4\x03\x00\xaa\xe0\x03\x13\xaa....\xe0\x03\x14\xaa"  # bl; mov x20,x0; mov x0,x19; bl; mov x0,x20
    b"\xfd\x7b\x41\xa9\xf4\x4f\xc2\xa8\xc0\x03\x5f\xd6"  # epilogue + ret
)

MOV_W0_1 = b"\x20\x00\x80\x52"  # mov w0, #1
RET = b"\xc0\x03\x5f\xd6"       # ret


def slices(buf):
    if buf[:4] == b"\xcf\xfa\xed\xfe":
        return [(0, len(buf))]
    if buf[:4] in (b"\xca\xfe\xba\xbe", b"\xca\xfe\xba\xbf"):
        n = struct.unpack(">I", buf[4:8])[0]
        off = 8
        out = []
        for _ in range(n):
            ct, cst, fo, fs, al = struct.unpack(">IIIII", buf[off:off + 20])
            if ct == 0x0100000C:
                out.append((fo, fs))
            off += 20
        return out
    return []


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: patch_flutter_metal.py <Flutter binary path>")
    path = sys.argv[1]
    data = bytearray(open(path, "rb").read())
    found = 0
    for off, size in slices(data):
        blk = data[off:off + size]
        m = PAT.search(blk)
        if not m:
            print("warning: ShouldUseMetalRenderer pattern not found in slice at 0x%x; skipped" % off)
            continue
        p = off + m.start()
        data[p:p + 4] = MOV_W0_1
        data[p + 4:p + 8] = RET
        print("patched ShouldUseMetalRenderer at 0x%x -> mov w0,#1; ret" % p)
        found += 1
    if found == 0:
        sys.exit("error: could not locate ShouldUseMetalRenderer; refusing to patch")
    open(path, "wb").write(bytes(data))
    print("done: %s" % path)


if __name__ == "__main__":
    main()
