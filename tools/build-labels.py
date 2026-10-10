"""Derive readable labels from base-game record identifiers, without copying values."""
import argparse
import json
from pathlib import Path
import re
import struct

parser = argparse.ArgumentParser()
parser.add_argument('--esm', type=Path, default=Path(r'D:\Steam\steamapps\common\Morrowind\Data Files\Morrowind.esm'))
args = parser.parse_args()
labels = {}
with args.esm.open('rb') as stream:
    while header := stream.read(16):
        if len(header) != 16:
            raise ValueError('Truncated ESM header')
        tag, size, _, _ = struct.unpack('<4sIII', header)
        if tag != b'GMST':
            stream.seek(size, 1)
            continue
        data = stream.read(size)
        offset = 0
        while offset < size:
            field, length = struct.unpack_from('<4sI', data, offset)
            offset += 8
            if offset + length > size:
                raise ValueError('Truncated GMST field')
            if field == b'NAME':
                name = data[offset:offset + length].rstrip(b'\0').decode('ascii')
                title = name[1:] if name[:1] in ('f', 'i', 's') else name
                title = re.sub(r'([a-z0-9])([A-Z])', r'\1 \2', title)
                title = re.sub(r'([A-Z])([A-Z][a-z])', r'\1 \2', title).replace('_', ' ')
                labels[name.lower()] = title
            offset += length
target = Path(__file__).resolve().parents[1] / 'scripts/gmst_profiles/labels.lua'
target.write_text('-- Generated from GMST identifiers only; no game values or assets.\nreturn {\n' +
                  ''.join(f'    [{json.dumps(key)}] = {json.dumps(value)},\n' for key, value in sorted(labels.items())) +
                  '}\n', encoding='ascii')
print(f'Generated {len(labels)} GMST labels')
