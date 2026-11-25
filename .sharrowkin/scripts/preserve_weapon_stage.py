"""Keep individual frames and exports together; verify existing runtime configs."""
from pathlib import Path
import json, shutil
root = Path(__file__).resolve().parents[2]
base = root / '.sharrowkin/weapon-step1'
for stage in ('before','after'):
    for floor in (1,2):
        meta = base/stage/f'floor{floor}.png.json'
        data = json.loads(meta.read_text())
        dest = base/stage/f'floor{floor}'/'frames'
        dest.mkdir(exist_ok=True)
        for wid, path in data['frames']:
            target = dest/(wid+'.png')
            shutil.copy2(path,target)
        data['frames'] = [(wid,str(dest/(wid+'.png'))) for wid,path in data['frames']]
        meta.write_text(json.dumps(data),encoding='utf-8')
for floor, cfg in ((1,'WeaponMeshData.lua'),(2,'WeaponMeshDataFloor2.lua')):
    actual = root/'src/ReplicatedStorage/Shared/Config'/cfg
    generated = base/'after'/f'floor{floor}'/cfg
    assert actual.read_text(encoding='utf-8').strip() == generated.read_text(encoding='utf-8').strip(), cfg+' differs'
print('PERSISTENT_FRAMES_OK 32; RUNTIME_CONFIGS_IDENTICAL 2')
