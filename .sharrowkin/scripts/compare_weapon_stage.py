"""Validate export contracts and compose all 16 paired rendered previews."""
from pathlib import Path
import json, re
from PIL import Image, ImageDraw, ImageFont
root = Path(__file__).resolve().parents[2]
base = root / '.sharrowkin/weapon-step1'
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 17)
for floor in (1, 2):
    prefix = f'weapons_floor{floor}'
    before = base / 'before' / f'floor{floor}'
    after = base / 'after' / f'floor{floor}'
    cfg = 'WeaponMeshData' + ('Floor2' if floor == 2 else '') + '.lua'
    assert before.joinpath(cfg).read_bytes() == after.joinpath(cfg).read_bytes(), 'model contract changed'
    def geometry(path):
        blocks = re.split(r'^o ', path.read_text(), flags=re.M)[1:]
        # OBJ indices and glow quads must remain identical in this palette-only pass.
        return {b.splitlines()[0]: [line for line in b.splitlines() if not line.startswith('vt ')] for b in blocks}
    assert geometry(before/(prefix+'.obj')) == geometry(after/(prefix+'.obj')), 'geometry changed'
    assert before.joinpath(prefix+'_glow.json').read_bytes() == after.joinpath(prefix+'_glow.json').read_bytes(), 'glow color changed'
    old = json.loads((base/'before'/f'floor{floor}.png.json').read_text())['frames']
    new = dict(json.loads((base/'after'/f'floor{floor}.png.json').read_text())['frames'])
    sheet = Image.new('RGB', (1520, 2640), '#1F2525')
    draw = ImageDraw.Draw(sheet)
    for i, (wid, old_path) in enumerate(old):
        x, y = (i%2)*760, (i//2)*660
        for dx, path, label in ((0, old_path, 'ДО'), (380, new[wid], 'ПОСЛЕ')):
            sheet.paste(Image.open(path).convert('RGB'), (x+dx,y+20))
            draw.text((x+dx+8,y+5), f'{label}: {wid}', font=font, fill='#E8E8DD')
    output = base / f'floor{floor}-before-after.png'
    sheet.save(output)
    print('CONTRACT_GEOMETRY_GLOW_OK', floor, len(old), str(output))
