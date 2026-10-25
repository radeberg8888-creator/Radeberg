"""Minimaler Leser für .blend-Dateien (Blender 4/5) ohne Blender.
Liest SDNA, Datenblöcke und kann Strukturen als dict auflösen."""
import struct, subprocess, os, sys

def decompress(path):
    raw = open(path, 'rb').read()
    if raw[:4] != b'\x28\xb5\x2f\xfd':
        return raw
    # zstd mit mehreren Frames: über Node entpacken (Frame für Frame)
    js = r"""
const z=require('zlib'),fs=require('fs');const b=fs.readFileSync(process.argv[1]);
const M=Buffer.from([0x28,0xb5,0x2f,0xfd]);let pos=[];let i=0;while((i=b.indexOf(M,i))>=0){pos.push(i);i+=4;}pos.push(b.length);
let out=[];let s=0;let k=1;
while(s<b.length&&k<pos.length){let ok=false;for(let e=k;e<pos.length;e++){try{const o=z.zstdDecompressSync(b.subarray(s,pos[e]));out.push(o);s=pos[e];k=e+1;ok=true;break;}catch(err){}}
 if(!ok){ // überspringbare Frames (Seek-Tabelle) am Ende
  break;}}
fs.writeFileSync(process.argv[2],Buffer.concat(out));
"""
    tmp = path + '.raw'
    subprocess.run(['node', '-e', js, path, tmp], check=True)
    d = open(tmp, 'rb').read(); os.remove(tmp); return d

class Blend:
    def __init__(self, path):
        self.d = d = decompress(path)
        if d[:9] == b'BLENDER17':      # Blender 5: großes BHead
            self.hlen = 17; self.large = True; self.ptr = 8; self.le = True
        else:
            self.hlen = 12; self.large = False; self.ptr = 8 if d[7:8] == b'-' else 4; self.le = d[8:9] == b'v'
        self.blocks = []; self.by_old = {}
        p = self.hlen
        while p < len(d):
            if self.large:
                code, sdna, old, ln, nr = struct.unpack_from('<4siQqq', d, p); p += 32
            else:
                code, ln, old, sdna, nr = struct.unpack_from('<4siQii', d, p); p += 24
            blk = dict(code=code.rstrip(b'\0').decode('latin1'), len=ln, old=old, sdna=sdna, nr=nr, off=p)
            self.blocks.append(blk)
            if old: self.by_old[old] = blk
            if blk['code'] == 'DNA1': self._dna(p)
            if blk['code'] == 'ENDB': break
            p += ln

    def _dna(self, p):
        d = self.d; base = p
        assert d[p:p+4] == b'SDNA'; p += 4
        def names(tag):
            nonlocal p
            assert d[p:p+4] == tag, (d[p:p+4], tag); p += 4
            n, = struct.unpack_from('<i', d, p); p += 4
            out = []
            for _ in range(n):
                e = d.index(b'\0', p); out.append(d[p:e].decode('latin1')); p = e + 1
            p = base + ((p - base + 3) & ~3)
            return out
        self.names = names(b'NAME'); self.types = names(b'TYPE')
        assert d[p:p+4] == b'TLEN'; p += 4
        self.tlen = list(struct.unpack_from('<%dh' % len(self.types), d, p)); p += 2 * len(self.types); p = base + ((p - base + 3) & ~3)
        assert d[p:p+4] == b'STRC'; p += 4
        n, = struct.unpack_from('<i', d, p); p += 4
        self.structs = []; self.struct_by_type = {}
        for i in range(n):
            t, nf = struct.unpack_from('<hh', d, p); p += 4
            fields = []
            off = 0
            for _ in range(nf):
                ft, fn = struct.unpack_from('<hh', d, p); p += 4
                name = self.names[fn]; tname = self.types[ft]
                size = self._fsize(tname, name)
                fields.append((tname, name, off, size)); off += size
            self.structs.append((self.types[t], fields))
            self.struct_by_type[self.types[t]] = i

    def _fsize(self, tname, name):
        mult = 1
        import re
        for a in re.findall(r'\[(\d+)\]', name): mult *= int(a)
        if name.startswith('*') or name.startswith('(*'): return self.ptr * mult
        return self.tlen[self.types.index(tname)] * mult

    def fields(self, sname):
        return self.structs[self.struct_by_type[sname]][1]

    def read_struct(self, sname, off, depth=1):
        out = {}
        for tname, name, foff, size in self.fields(sname):
            o = off + foff; base = name.split('[')[0].lstrip('*').strip('()*')
            if name.startswith('*') or name.startswith('(*'):
                if '[' in name:
                    import re
                    cnt = size // self.ptr; out[base] = list(struct.unpack_from('<%dQ' % cnt, self.d, o))
                else:
                    out[base], = struct.unpack_from('<Q', self.d, o)
                continue
            arr = '[' in name
            prim = {'char': 'b', 'uchar': 'B', 'short': 'h', 'ushort': 'H', 'int': 'i', 'uint': 'I', 'float': 'f', 'double': 'd', 'int64_t': 'q', 'uint64_t': 'Q', 'int8_t': 'b', 'uint8_t': 'B', 'int16_t': 'h', 'uint16_t': 'H', 'int32_t': 'i', 'uint32_t': 'I', 'bool': '?'}
            if tname in prim:
                fmt = prim[tname]; cnt = size // struct.calcsize(fmt)
                if tname == 'char' and arr:
                    s = self.d[o:o+size]; out[base] = s.split(b'\0')[0].decode('utf8', 'replace')
                else:
                    v = struct.unpack_from('<%d%s' % (cnt, fmt), self.d, o); out[base] = list(v) if cnt > 1 else v[0]
            elif tname in self.struct_by_type and depth > 0 and not arr:
                out[base] = self.read_struct(tname, o, depth - 1)
            else:
                out[base] = ('@', tname, o)
        return out

    def block_of(self, ptr):
        return self.by_old.get(ptr)

    def struct_name(self, blk):
        return self.structs[blk['sdna']][0]

    def items(self, ptr, sname=None):
        b = self.block_of(ptr)
        if not b: return []
        sname = sname or self.struct_name(b)
        sz = self.tlen[self.types.index(sname)]
        return [self.read_struct(sname, b['off'] + i * sz, 2) for i in range(b['nr'])]

    def raw(self, ptr):
        b = self.block_of(ptr)
        return None if not b else self.d[b['off']:b['off'] + b['len']]

if __name__ == '__main__':
    B = Blend(sys.argv[1])
    from collections import Counter
    print(Counter(B.struct_name(b) for b in B.blocks if b['code'] not in ('DNA1',)).most_common(30))
    for tn, name, off, size in B.fields('Mesh'): print('Mesh.', tn, name, off, size)

def owner_maps(B):
    """Ordnet DATA-Blöcke dem vorangehenden ID-Block zu (Blender 5: Zeiger sind je ID eindeutig)."""
    maps = []; cur = {}; owners = []
    for i, b in enumerate(B.blocks):
        if len(b['code']) == 2 or b['code'] in ('DNA1', 'ENDB', 'GLOB', 'REND', 'TEST'):
            cur = {}; maps.append(cur)
        cur.setdefault(b['old'], b); owners.append(cur)
    return owners
