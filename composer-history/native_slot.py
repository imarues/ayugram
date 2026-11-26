"""Version-gated native rich-editor inset patch.

Adds a 34pt trailing layout margin while the translator is present. The runtime
dylib controls a single byte in zero-filled writable alignment padding. No
existing section data or Swift metadata is overwritten; exact original
instruction and Mach-O layout checks reject another app version.
"""
import struct
CAVE=0x20000
FLAG=0x6b51c7f
SITES=((0x2f97b3c,0x1e659000,0,0x4048),
       (0x2f97cd8,0x1e759004,4,0xc048),
       (0x2f97ce4,0x1e659004,4,0x4048))
def branch(src,dst):
    offset=dst-src
    assert offset%4==0 and -(1<<27)<=offset<(1<<27)
    return 0x14000000|((offset//4)&0x3ffffff)
def adrp(pc,to,rd):
    n=((to&~0xfff)-(pc&~0xfff))//4096
    assert -(1<<20)<=n<(1<<20)
    n &= 0x1fffff
    return 0x90000000|((n&3)<<29)|((n>>2)<<5)|rd
def patch(data):
    b=bytearray(data)
    assert len(b)>FLAG and not any(b[CAVE:CAVE+96])
    assert b[FLAG-6:FLAG+1]==b'\0'*7
    segs={};p=32
    for _ in range(struct.unpack_from('<I',b,16)[0]):
        c,z=struct.unpack_from('<II',b,p)
        if c==0x19:
            nm,va,sz,off,fs,mp,ip,ns,_=struct.unpack_from('<16sQQQQIIII',b,p+8)
            segs[nm.rstrip(b'\0')]=(va,sz,off,fs,ip)
            if nm.startswith(b'__DATA\0'):
                sections=[]
                for j in range(ns):
                    q=p+72+j*80
                    name,sg,addr,size,fo=struct.unpack_from('<16s16sQQI',b,q)
                    sections.append((name.rstrip(b'\0'),addr,size,fo))
                assert (b'__data',0x6980630,0x1d1649,0x6980630) in sections
                assert (b'__objc_stublist',0x6b51c80,0x48,0x6b51c80) in sections
                assert not any(a<=FLAG<a+s for _,a,s,_ in sections)
        p+=z
    assert segs[b'__TEXT']==(0,0x6088000,0,0x6088000,5)
    assert segs[b'__DATA']==(0x6438000,0xae4000,0x6438000,0x71c000,3)
    for i,(site,orig,dreg,imm) in enumerate(SITES):
        assert struct.unpack_from('<I',b,site)[0]==orig
        pc=CAVE+i*32
        words=[adrp(pc,FLAG,16), 0x39400000|((FLAG&0xfff)<<10)|(16<<5)|16,
               0x34000000|(4<<5)|16, 0xd2e00000|(imm<<5)|16,
               0x9e670000|(16<<5)|dreg, branch(pc+20,site+4),
               orig, branch(pc+28,site+4)]
        struct.pack_into('<8I',b,pc,*words)
        struct.pack_into('<I',b,site,branch(site,pc))
        print(f'Native slot: 0x{site:x} -> 0x{pc:x} ({branch(site,pc):08x})')
    return bytes(b)
if __name__=='__main__':
    import pathlib
    b=pathlib.Path('inspect/TelegramUIFramework').read_bytes()
    out=patch(b)
    pathlib.Path('workvoid/slot-test.bin').write_bytes(out[CAVE:CAVE+96])
    for i,(site,_,_,_) in enumerate(SITES):
        print(hex(site),hex(branch(site,CAVE+i*32)))
