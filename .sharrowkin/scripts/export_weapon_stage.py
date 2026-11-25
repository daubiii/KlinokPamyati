"""Blender entry point: -- <before|after> (independent export directories)."""
from pathlib import Path
import sys
import runpy
root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / '.sharrowkin/blender-deps'))
sys.path.insert(0, str(root / 'tools/weapons'))
stage = sys.argv[sys.argv.index('--') + 1]
assert stage in ('before', 'after')
for floor, script in ((1, 'export_weapons.py'), (2, 'export_weapons_floor2.py')):
    out = root / '.sharrowkin/weapon-step1' / stage / ('floor' + str(floor))
    out.mkdir(parents=True, exist_ok=True)
    sys.argv = [script, str(out)]
    namespace = runpy.run_path(str(root / 'tools/weapons' / script), run_name='__main__')
    import json
    wp = namespace['WP']
    glow = {}
    for wid, fn, rarity in wp.WEAPONS:
        _, groups = namespace['split'](fn())
        for i, color in enumerate(sorted(groups), 1):
            glow[f'G{i}_{wid}'] = color
    (out / f'weapons_floor{floor}_glow.json').write_text(json.dumps(glow), encoding='utf-8')
    print('EXPORT_STAGE_OK', stage, floor, len(wp.WEAPONS))
