"""Preserve two-slot accessory width when the app recalculates normal widths.
Only the exact selected object is affected; original native behavior is used
on all others. The runtime controls a single pointer in verified RW padding.
"""
import struct
CAVE=0x20000
SELECTED=0x6980628
SITE=0x29b0b14
def branch(src,dst):
    d=dst-src;assert d%4==0 and -(1<<27)<=d<(1<<27)
    return 0x14000000|((d//4)&0x3ffffff)
def adrp(pc,to,rd):
    n=((to&~0xfff)-(pc&~0xfff))//4096
    assert -(1<<20)<=n<(1<<20)
    n&=0x1fffff
    return 0x90000000|((n&3)<<29)|((n>>2)<<5)|rd
def patch(data):
    b=bytearray(data)
    assert len(b)>SELECTED+8 and not any(b[CAVE:CAVE+64]) and not any(b[SELECTED:SELECTED+8])
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
                assert (b'__objc_data',0x677b830,0x204df8,0x677b830) in sections
                assert (b'__data',0x6980630,0x1d1649,0x6980630) in sections
                assert not any(a<=SELECTED<a+s for _,a,s,_ in sections)
        p+=z
    assert segs[b'__TEXT']==(0,0x6088000,0,0x6088000,5)
    assert segs[b'__DATA']==(0x6438000,0xae4000,0x6438000,0x71c000,3)
    assert struct.unpack_from('<III',b,SITE-8)==(0xd0020648,0xf9426108,0xfc286a60)
    # adrp x16; ldr x16,[x16,#slot]; cmp x19,x16; b.ne original
    # fmov x17,d0; movz x16,#0x4040,lsl48; cmp x17,x16; b.ne original
    # movz x17,#0x4050,lsl48; movk x17,#0x8000,lsl32; str x17,[x19,x8];
    # b return; original: str d0,[x19,x8]; b return.
    words=[adrp(CAVE,SELECTED,16),0xf9400000|(((SELECTED&0xfff)//8)<<10)|(16<<5)|16,
      0xeb10027f,0x54000121,0x9e660011,0xd2e80810,0xeb10023f,0x540000a1,
      0xd2e80a11,0xf2d00011,0xf8286a71,branch(CAVE+44,SITE+4),
      0xfc286a60,branch(CAVE+52,SITE+4)]
    struct.pack_into('<14I',b,CAVE,*words)
    struct.pack_into('<I',b,SITE,branch(SITE,CAVE))
    print('Native width trampoline',hex(words[0]),hex(branch(SITE,CAVE)))
    return bytes(b)
if __name__=='__main__':
    from pathlib import Path
    b=patch(Path('inspect/TelegramUIFramework').read_bytes())
    Path('workvoid/width-test.bin').write_bytes(b[CAVE:CAVE+56])
