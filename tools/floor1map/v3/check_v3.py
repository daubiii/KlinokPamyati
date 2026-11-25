"""Сверка этажа 1 v3: точки, ворота, насесты, имена мешей. python3 check_v3.py <out>"""
import sys, re, f1lib, collections
OUT = sys.argv[1]
cfg = open(OUT + '/Floor1v2.lua', encoding='utf-8').read()
pts = open(OUT + '/Floor1Points.lua', encoding='utf-8').read()
fmd = open(OUT + '/FloorMapData.lua', encoding='utf-8').read()
fails = 0
def check(label, ok, detail=''):
    global fails
    if not ok: fails += 1
    print(('  OK   ' if ok else '  FAIL ') + label + (' — ' + str(detail) if detail and not ok else ''))
P = set(); zone = None
for line in pts.splitlines():
    m = re.match(r'\t(\w+) = \{', line)
    if m: zone = m.group(1)
    m = re.search(r'\["(\w+)"\]', line)
    if m: P.add((zone, m.group(1)))
refs = set(re.findall(r'P\.(\w+)\.(\w+)', cfg))
check('все точки P.* из Floor1v2 есть в Floor1Points', refs <= P, sorted(refs - P)[:8])
tree, parts = f1lib.load_rbxmx(OUT + '/map/Floor1Map.rbxmx')
models = collections.Counter(p.path[3] for p in parts if len(p.path) > 3)
gates = set(re.findall(r'"(Gate_\w+)"', cfg))
check('все ворота из конфига есть в карте', gates <= set(models), sorted(gates - set(models)))
for g in gates:
    check(f'точка GATE_{g}', any(n == 'GATE_' + g for _, n in P))
for n in 'ABC':
    sup = [p for p in parts if len(p.path) > 3 and p.path[3] == 'Perch_' + n and p.name == 'Support']
    check(f'Perch_{n}: подпора', len(sup) == 1)
    check(f'Perch_{n}: доски', sum(1 for p in parts if len(p.path) > 3 and p.path[3] == 'Perch_' + n and p.name == 'Plank') == 7)
names = re.findall(r'name = "(\w+)"', fmd)
check('имена мешей уникальны', len(names) == len(set(names)))
objs = set()
for z in f1lib.ZONES:
    for line in open(f'{OUT}/map/{z}_vis.obj', encoding='utf-8'):
        if line.startswith('o '): objs.add(line[2:].strip())
check('FloorMapData = объекты OBJ', set(names) == objs, (len(names), len(objs)))
check('старой башни нет (Gate_RampTop, Barricade_*)', 'Gate_RampTop' not in models and not any(m.startswith('Barricade_') for m in models))
br = [m for m in models if m.startswith('Bridge_')]
check('мост: 20×5 плит (было 20×3)', len(br) == 100 and len(set(br)) == 100, len(br))
print('ПРОВАЛОВ:', fails)
sys.exit(1 if fails else 0)
