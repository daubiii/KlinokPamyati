"""Комплекты брони этажей 2–5 (06.11.2026) — тот же стиль, что броня мага (mage_sets):
рампы 4 тона, свет сверху-слева-спереди, кант, заклёпки, светящиеся акценты только у редких+.
Воин — латы по частям тела R15; маг — шляпа, пелерина, плащ (mage_parts).
id совпадают с Config/ArmorFloors.lua."""
import math
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'mage-armor'))
import magekit as K
from magekit import Piece, V, H, cen
import mage_parts as M
import mage_sets as MS
import plate_parts as P

MEMORY = '!#6FE3FF'
HEAD_IN = 0.6
TX, TY, TZ = P.TX, P.TY, P.TZ
COMMON = MS.COMMON
BODY = {'cloth': '#5A5048', 'leather': '#4A3426', 'skin': '#B8A58E'}


MAIL = ['#2A2E34', '#444A52', '#646C76', '#8A929C']


def ramps(**kw):
    r = dict(COMMON)
    r['mail'] = MAIL
    r.update(kw)
    return r


def piece(name, part, slot):
    return Piece(name, part, slot)


def finish(pieces, R, contrast=1.0):
    for p in pieces:
        p.shade(R, contrast=contrast)
    return pieces


rim, runes, stars = MS.rim, MS.runes, MS.stars


# =====================================================================
# Воин: сборка комплекта по описанию
# =====================================================================
def warrior(sid, rarity, R, helm, chest, arms, legs, belt, cape=None, body=None, eye=MEMORY, extra=None):
    """helm/chest/arms/legs/belt — словари параметров деталей + 'deco': fn(piece, R) после shade.
    extra(pieces, R) — уникальные штрихи комплекта после всего."""
    pieces = []
    # --- шлем
    h = piece('Helm', 'Head', 'helm')
    hp = dict(helm)
    deco = hp.pop('deco', None)
    pre = hp.pop('pre', None)
    P.helm(h, eye=eye, **hp)
    if pre:
        pre(h)
    finish([h], R)
    if deco:
        deco(h, R)
    pieces.append(h)
    # --- корпус
    c = piece('Chest', 'UpperTorso', 'armor')
    cp = dict(chest)
    deco = cp.pop('deco', None)
    pre = cp.pop('pre', None)
    gor = cp.pop('gorget', None)
    P.cuirass(c, **cp)
    if gor:
        P.gorget(c, **gor)
    if pre:
        pre(c)
    finish([c], R)
    if deco:
        deco(c, R)
    pieces.append(c)
    # --- руки
    ap = dict(arms)
    pdeco = ap.pop('deco', None)
    pa = ap.pop('pauldron', {})
    br = ap.pop('bracer', {})
    ga = ap.pop('gauntlet', {})
    arm_pieces = []
    for side in ('Right', 'Left'):
        pd = piece('Pauldron' + side[0], side + 'UpperArm', 'armor')
        P.pauldron(pd, side, **pa)
        b = piece('Bracer' + side[0], side + 'LowerArm', 'armor')
        P.bracer(b, **br)
        g = piece('Gauntlet' + side[0], side + 'Hand', 'armor')
        P.gauntlet(g, **ga)
        arm_pieces += [pd, b, g]
    finish(arm_pieces, R)
    if pdeco:
        for ap_ in arm_pieces:
            pdeco(ap_, R)
    pieces += arm_pieces
    # --- пояс
    bt = piece('Belt', 'LowerTorso', 'armor')
    bp = dict(belt)
    deco = bp.pop('deco', None)
    pre = bp.pop('pre', None)
    P.faulds(bt, **bp)
    if pre:
        pre(bt)
    finish([bt], R)
    if deco:
        deco(bt, R)
    pieces.append(bt)
    # --- ноги
    lp = dict(legs)
    ldeco = lp.pop('deco', None)
    cu = lp.pop('cuisse', {})
    gr = lp.pop('greave', {})
    bo = lp.pop('boot', {})
    leg_pieces = []
    for side in ('Right', 'Left'):
        a = piece('Cuisse' + side[0], side + 'UpperLeg', 'armor')
        P.cuisse(a, **cu)
        g = piece('Greave' + side[0], side + 'LowerLeg', 'armor')
        P.greave(g, **gr)
        f = piece('Boot' + side[0], side + 'Foot', 'armor')
        P.boot(f, **bo)
        leg_pieces += [a, g, f]
    finish(leg_pieces, R)
    if ldeco:
        for lp_ in leg_pieces:
            ldeco(lp_, R)
    pieces += leg_pieces
    # --- плащ
    if cape:
        cpp = dict(cape)
        deco = cpp.pop('deco', None)
        trim = cpp.pop('trim', None)
        cl = M.cape(sid, **cpp)
        if trim:
            M.outline_bottom(cl, trim, cpp.get('mat', 'cape'))
        finish([cl], R)
        if deco:
            deco(cl, R)
        pieces += M.split_cape(cl)
    if extra:
        extra(pieces, R)
    for p in pieces:
        if p.slot == 'helm':
            p.lift(0)
    return dict(id=sid, rarity=rarity, body=body or BODY, pieces=pieces)


def bypart(pieces, prefix):
    return [p for p in pieces if p.name.startswith(prefix)]


# =====================================================================
# ЭТАЖ 2 «ЗАТОПЛЕННЫЕ САДЫ»: зелень, мох, тростник, мрамор, розы, вода
# =====================================================================
WATER = '!#5FD0C0'
ROSE = '!#FF7A9A'


def gardener():
    R = ramps(steel=['#3E3A2E', '#5C5640', '#7C7556', '#9C946E'], straw=['#6E5A2A', '#9A8038', '#C2A44C', '#E0C66C'],
              leather=['#2E2216', '#46321E', '#62472C', '#7E5E3C'], apron=['#2A3A2C', '#3C5240', '#4E6A52', '#648466'],
              moss=['#1E3A22', '#2C5430', '#3E6E40', '#5A8C52'], sole=['#1A1410', '#261E16', '#32281E', '#3E3226'],
              trim=COMMON['rope'])
    def straw_hat(h):
        M.brim(h, 1.22, 0.46, th=0.13, droop=0.12, wave=0.05, waves=7, phase=0.4, rough=0.06, seed=12, mat='straw')
        M.crown(h, 0.46, 0.4, 0.66, 0.52, bend=(0.0, 0.04), w0=3.0, mat='straw')
        h.carve(lambda x, y, z: abs(x) < HEAD_IN and abs(z) < HEAD_IN and y < 0.58)
        M.band(h, 0.46, 0.6, 'apron')

    def helm_deco(h, R):
        # перевязь соломы и пучок тростника за лентой
        rim(h, R['straw'][3], lambda x, y, z: math.hypot(x, z) > 1.0)
        MS.stars  # noqa
    def leaves(p, R):
        P.vines(p, R['moss'][2], lambda x, y, z: True, seed=21, density=0.2, leaf=R['moss'][3])
    return warrior(
        'gardener', 'common', R,
        helm=dict(kind='cap', R=0.7, top=0.6, bottom=-0.5, w=2.6, mat='leather', neck=0.0, pre=straw_hat, deco=helm_deco),
        chest=dict(out=0.1, top=0.06, bottom=-0.78, bulge=0.04, mat='apron', lames=0, back=True, deco=leaves,
                   gorget=dict(h=0.16, ri=0.38, ro=0.6, mat='leather'),
                   pre=lambda c: c.recolor(lambda x, y, z, m: 'leather' if (abs(abs(x) - 0.55) < 0.07 and z < 0) else None)),
        arms=dict(pauldron=dict(R=0.7, top=0.8, lames=2, drop=0.7, mat='leather', trim='trim', sleeve='apron', sleeve_y=-0.2),
                  bracer=dict(y0=-0.48, y1=0.1, r=0.62, flare=0.0, mat='leather', trim='trim'),
                  gauntlet=dict(mat='leather', cuff='leather', r=0.58, knuckles=False)),
        legs=dict(cuisse=dict(mat='apron', y0=-0.1, y1=0.5, out=0.08, wrap=0.2),
                  greave=dict(mat='leather', y0=-0.5, y1=0.1, out=0.1, knee=0.0),
                  boot=dict(mat='leather', sole='sole', toe=0.24, cuff=0.0)),
        belt=dict(mat='apron', drop=0.62, plates=1, front=True, back=False, belt_mat='trim', buckle='steel', out=0.12, rounded=True),
    )


def sluice_guard():
    R = ramps(steel=['#2E3A3C', '#4A5C5E', '#6E8486', '#9AB0B0'], trim=['#4A3A1C', '#7A5E2A', '#A88438', '#D2AE54'],
              tabard=['#163430', '#22504A', '#2E6A62', '#3E8A80'], leather=COMMON['leather'],
              sole=['#1A1410', '#261E16', '#32281E', '#3E3226'], visor=['#202A2C', '#34444A', '#4A5E64', '#647C82'])
    def chest_pre(c):
        # табард поверх кирасы спереди: полоса ткани
        c.recolor(lambda x, y, z, m: 'tabard' if abs(x) < 0.46 and y < 0.55 and (z < 0 or y < 0.2) else None)
    def chest_deco(c, R):
        P.rivets(c, R['trim'][3], lambda x, y, z: abs(x) > 0.6 and y > 0.3, step=3)
        rim(c, R['trim'][2], lambda x, y, z: abs(abs(x) - 0.46) < 0.07 and y < 0.55)
        # знак шлюза на табарде — ворота
        for (i, j, k), col in list(c.c.items()):
            x, y, z = cen(i), cen(j), cen(k)
            if z < -0.6 and -0.15 < y < 0.35 and abs(x) < 0.3 and (i, j, k - 1) not in c.c:
                if abs(x) > 0.22 or y > 0.27 or abs(x) < 0.04:
                    c.c[(i, j, k)] = R['trim'][2]
    def arm_deco(p, R):
        if p.name.startswith('Pauldron'):
            P.rivets(p, R['trim'][3], lambda x, y, z: y > 0.5, step=5)
    return warrior(
        'sluice_guard', 'rare', R,
        helm=dict(kind='kettle', R=0.74, top=0.78, bottom=-0.5, w=2.6, mat='steel', face_mat='visor', brim=0.3, brim_y=0.26, slit=0.04, prow=0.1,
                  neck=0.18, deco=lambda h, R: rim(h, R['trim'][2], lambda x, y, z: math.hypot(x, z) > 0.98)),
        chest=dict(out=0.14, top=0.1, bottom=-0.78, bulge=0.1, mat='steel', lames=2, pre=chest_pre, deco=chest_deco,
                   gorget=dict(h=0.22, ri=0.38, ro=0.66, mat='steel')),
        arms=dict(pauldron=dict(R=0.78, top=0.86, lames=3, drop=0.9, mat='steel', trim='trim', sleeve='mail'),
                  bracer=dict(y0=-0.48, y1=0.22, r=0.6, flare=0.06, mat='steel', trim='trim'),
                  gauntlet=dict(mat='steel', cuff='leather', r=0.6), deco=arm_deco),
        legs=dict(cuisse=dict(mat='steel', y0=-0.35, y1=0.5, out=0.11, wrap=0.4),
                  greave=dict(mat='steel', y0=-0.52, y1=0.42, out=0.12, knee=0.2),
                  boot=dict(mat='leather', sole='sole', toe=0.26, cuff=0.06, cuff_mat='steel')),
        belt=dict(mat='steel', drop=0.56, plates=2, front=True, back=True, belt_mat='leather', buckle='trim', tasset_mat='tabard'),
        cape=dict(y_top=0.74, y_bot=-1.2, segs=3, w_top=0.86, w_bot=0.96, z0=0.7, fold=0.05, folds=6, hem='round', mat='tabard', trim='trim'),
    )


def thorn_knight():
    R = ramps(steel=['#141E18', '#22342A', '#34503E', '#4C6E56'], thorn=['#2A1E14', '#44301E', '#5E4428', '#7A5C36'],
              trim=['#3E2E1C', '#5E4A2C', '#8A7040', '#B49658'], vine=['#1C3A1E', '#2A5A2C', '#3E7A3A', '#5E9A4E'],
              cape=['#122216', '#1C3220', '#28462C', '#386040'], leather=COMMON['leather'],
              sole=['#140F0C', '#1E1712', '#2A2018', '#36291E'], red=['#4E1420', '#7A1E30', '#A42C42', '#CC4A5E'])
    thorn_pts = [(0.5, 0.4, 0.1), (0.75, 0.6, 0.12), (0.95, 0.9, 0.2), (1.02, 1.22, 0.32)]
    def helm_pre(h):
        P.horns(h, thorn_pts, 0.12, 0.03, mat='thorn')
        # шипы на гребне
        for n in range(4):
            z = -0.4 + n * 0.28
            M.tip(h, [(0, 0.7, z), (0, 0.82, z + 0.02), (0, 0.92, z + 0.06), (0, 1.02, z + 0.12)], 0.08, 0.03, mat='thorn')
    def vine_deco(p, R):
        P.vines(p, R['vine'][2], lambda x, y, z: True, seed=31, density=0.22, leaf=R['vine'][3])
    def buds(p, R):
        # бутоны роз: редкие красные точки (на эпике — с подсветкой)
        for (i, j, k), col in list(p.c.items()):
            if col == R['vine'][2] and H(77, i, j, k) < 0.08:
                p.c[(i, j, k)] = ROSE if H(78, i, j, k) < 0.4 else R['red'][2]
    def pd_pre(side):
        return None
    def arm_deco(p, R):
        vine_deco(p, R)
        buds(p, R)
    def thorns_on_pauldrons(pieces, R):
        for p in bypart(pieces, 'Pauldron'):
            sx = 1 if p.name.endswith('R') else -1
            extra = Piece('tmp', p.part, 'armor')
            for n, (zz, yy) in enumerate(((-0.3, 0.7), (0.0, 0.8), (0.3, 0.7))):
                M.tip(extra, [(sx * 0.3, yy, zz), (sx * 0.45, yy + 0.12, zz), (sx * 0.6, yy + 0.24, zz * 1.1), (sx * 0.72, yy + 0.34, zz * 1.2)], 0.09, 0.03, mat='thorn')
            extra.shade(R)
            for key, col in extra.c.items():
                p.c.setdefault(key, col)
    return warrior(
        'thorn_knight', 'epic', R,
        helm=dict(kind='great', R=0.74, top=0.74, bottom=-0.62, w=3.0, mat='steel', slit=0.04, neck=0.12, pre=helm_pre, prow=0.18, holes=True,
                  deco=lambda h, R: (vine_deco(h, R), buds(h, R))),
        chest=dict(out=0.16, top=0.12, bottom=-0.78, bulge=0.14, mat='steel', lames=3, deco=lambda c, R: (vine_deco(c, R), buds(c, R)),
                   gorget=dict(h=0.24, ri=0.38, ro=0.68, mat='steel')),
        arms=dict(pauldron=dict(R=0.82, top=0.9, lames=4, drop=1.0, mat='steel', trim='trim', sleeve='mail'),
                  bracer=dict(y0=-0.48, y1=0.24, r=0.6, flare=0.08, mat='steel', trim='trim'),
                  gauntlet=dict(mat='steel', cuff='steel', r=0.6), deco=arm_deco),
        legs=dict(cuisse=dict(mat='steel', y0=-0.45, y1=0.5, out=0.12, wrap=0.6),
                  greave=dict(mat='steel', y0=-0.55, y1=0.42, out=0.13, knee=0.22),
                  boot=dict(mat='steel', sole='sole', toe=0.3, cuff=0.0), deco=vine_deco),
        belt=dict(mat='steel', drop=0.66, plates=2, belt_mat='leather', buckle='trim'),
        cape=dict(y_top=0.76, y_bot=-1.9, segs=4, w_top=0.92, w_bot=1.12, z0=0.7, fold=0.07, folds=7, hem='tattered', hem_depth=0.45,
                  ragged=0.3, seed=33, mat='cape', deco=lambda cl, R: (vine_deco(cl, R), buds(cl, R))),
        extra=thorns_on_pauldrons,
    )


def rose_warden():
    R = ramps(steel=['#8E8A80', '#B4B0A4', '#D6D2C6', '#F2EFE6'], trim=COMMON['gold'],
              rose=['#5E1426', '#8C2038', '#B83050', '#E0526E'], leaf=['#1C3A26', '#2A5634', '#3C7444', '#56945A'],
              cape=['#16302A', '#22463E', '#305E54', '#42786C'], marble=['#7E7A72', '#A6A296', '#C8C4B8', '#E6E2D8'],
              leather=COMMON['leather'], sole=['#1A1410', '#261E16', '#32281E', '#3E3226'])
    def helm_pre(h):
        # корона из лепестков-зубцов и роза надо лбом
        P.spikes(h, 7, 0.62, 0.62, 0.36, r0=0.1, mat='trim', arc=math.pi * 1.6)
        h.fill((-0.22, 0.52, -0.92), (0.22, 0.92, -0.62), lambda x, y, z: x * x + (y - 0.72) ** 2 + (z + 0.78) ** 2 <= 0.17 ** 2, 'rose')
    def marble_veins(p, R):
        P.vines(p, R['marble'][1], lambda x, y, z: True, seed=51, density=0.25)
    def rose_deco(p, R, glow=True):
        marble_veins(p, R)
        rim(p, R['trim'][2], lambda x, y, z: True) if False else None
    def chest_deco(c, R):
        marble_veins(c, R)
        # роза на груди + стебли
        for (i, j, k), col in list(c.c.items()):
            x, y, z = cen(i), cen(j), cen(k)
            if (i, j, k - 1) in c.c or z > -0.4:
                continue
            d = math.hypot(x, y - 0.25)
            if d < 0.2:
                c.c[(i, j, k)] = R['rose'][2] if (i + j) % 3 else R['rose'][3]
            elif abs(x) < 0.05 and -0.6 < y < 0.08:
                c.c[(i, j, k)] = R['leaf'][2]
            elif 0.2 < d < 0.3 and y < 0.25 and abs(x) > 0.12:
                c.c[(i, j, k)] = R['leaf'][3]
        runes(c, WATER, lambda x, y, z: abs(y - 0.68) < 0.07 and z < 0, density=0.6, seed=52)
        rim(c, R['trim'][2], lambda x, y, z: y < -0.6)
    def arm_deco(p, R):
        marble_veins(p, R)
        if p.name.startswith('Pauldron'):
            runes(p, WATER, lambda x, y, z: y > 0.72, density=0.4, seed=53, normals=((0, 1, 0),))
    def cape_deco(cl, R):
        # розы по подолу и бегущая лоза
        P.vines(cl, R['leaf'][2], lambda x, y, z: y < -0.4, seed=55, density=0.6, leaf=R['leaf'][3])
        for (i, j, k), col in list(cl.c.items()):
            if col == R['leaf'][3] and H(56, i, j, k) < 0.3:
                cl.c[(i, j, k)] = R['rose'][2]
        runes(cl, WATER, lambda x, y, z: abs(x) < 0.08 and y > -1.4, density=0.6, seed=57, normals=((0, 0, 1),))
    return warrior(
        'rose_warden', 'legendary', R,
        helm=dict(kind='great', R=0.76, top=0.66, bottom=-0.62, w=3.2, mat='steel', slit=0.04, neck=0.14, face_mat='marble', pre=helm_pre, prow=0.12,
                  deco=lambda h, R: (marble_veins(h, R), rim(h, R['trim'][2], lambda x, y, z: y < -0.5 or (0.5 < y < 0.62)))),
        chest=dict(out=0.16, top=0.12, bottom=-0.78, bulge=0.16, mat='steel', lames=3, lame_mat='marble', deco=chest_deco,
                   gorget=dict(h=0.26, ri=0.38, ro=0.7, mat='trim')),
        arms=dict(pauldron=dict(R=0.86, top=0.92, lames=4, drop=1.0, mat='steel', trim='trim', sleeve='mail', step=0.06),
                  bracer=dict(y0=-0.48, y1=0.26, r=0.61, flare=0.1, mat='steel', trim='trim'),
                  gauntlet=dict(mat='steel', cuff='trim', r=0.6), deco=arm_deco),
        legs=dict(cuisse=dict(mat='steel', y0=-0.45, y1=0.5, out=0.12, wrap=0.6),
                  greave=dict(mat='steel', y0=-0.55, y1=0.42, out=0.13, knee=0.22, knee_mat='trim'),
                  boot=dict(mat='steel', sole='sole', toe=0.3, cuff=0.06, cuff_mat='trim'), deco=lambda p, R: marble_veins(p, R)),
        belt=dict(mat='steel', drop=0.7, plates=2, belt_mat='rose', buckle='trim', tasset_mat='marble'),
        cape=dict(y_top=0.78, y_bot=-2.2, segs=4, w_top=0.96, w_bot=1.2, z0=0.7, fold=0.07, folds=7, hem='point', hem_depth=0.38,
                  mat='cape', trim='trim', deco=cape_deco),
        eye=WATER,
    )




# =====================================================================
# ЭТАЖ 3 «ПСАРНИ ОХОТЫ»: кожа, мех, кость, рога, красное сукно, золото рога
# =====================================================================
AMBER = '!#FFB04A'
FUR = ['#2E2016', '#4A3424', '#6A4C34', '#8E6C4C']
FUR_W = ['#8C8070', '#B0A490', '#D2C8B4', '#EEE6D4']
BONE = ['#7E7260', '#A89A82', '#CCC0A6', '#ECE2CA']
HUNT_RED = ['#3B1E1E', '#5E2A24', '#8C3B2E', '#B05440']
HUNT_GOLD = ['#6E4E18', '#A07424', '#D9A441', '#F2CC70']


def fur_ring(p, y0, y1, r0, r1, mat='fur', seed=3):
    """Меховая опушка: рваное кольцо (шея, сапоги)."""
    def ins(x, y, z):
        if y < y0 or y > y1:
            return False
        r = math.hypot(x, z)
        return r0 <= r <= r1 + 0.08 * (H(seed, round(math.atan2(z, x) * 8), round(y / V)) - 0.5)
    p.fill((-r1 - 0.2, y0, -r1 - 0.2), (r1 + 0.2, y1, r1 + 0.2), ins, mat)


def kennelman():
    R = ramps(leather=['#2A1A12', '#422A1C', '#5E3E28', '#7C5638'], fur=FUR, steel=['#3A3634', '#585250', '#7A7470', '#9E9894'],
              trim=COMMON['brass'], sole=['#161010', '#221816', '#2E201C', '#3A2A24'], hood=['#2E1814', '#48261E', '#66382C', '#86503E'])
    def neck_fur(c):
        fur_ring(c, TY - 0.05, TY + 0.22, 0.4, 0.78, seed=4)
    def studs(p, R):
        P.rivets(p, R['trim'][2], lambda x, y, z: z < -0.5 and abs(x) > 0.3, step=11)
    def collars(pieces, R):
        # ошейники с шипами на наручах — трофеи псаря
        for b in bypart(pieces, 'Bracer'):
            for (i, j, k), col in list(b.c.items()):
                if abs(cen(j) - 0.05) < V and (i + k) % 3 == 0:
                    b.c[(i, j, k)] = R['steel'][3]
    return warrior(
        'kennelman', 'common', R,
        helm=dict(kind='hood', R=0.7, top=0.7, bottom=-0.62, w=2.4, mat='hood', neck=0.0,
                  pre=lambda h: fur_ring(h, -0.62, -0.38, 0.6, 0.82, seed=5)),
        chest=dict(out=0.1, top=0.08, bottom=-0.78, bulge=0.05, mat='leather', lames=2, pre=neck_fur, deco=studs),
        arms=dict(pauldron=dict(R=0.72, top=0.82, lames=2, drop=0.62, mat='leather', trim='fur', sleeve='leather', sleeve_y=-0.3),
                  bracer=dict(y0=-0.48, y1=0.18, r=0.6, flare=0.04, mat='leather', trim='trim'),
                  gauntlet=dict(mat='leather', cuff='fur', r=0.58, knuckles=False)),
        legs=dict(cuisse=dict(mat='leather', y0=-0.2, y1=0.5, out=0.08, wrap=0.3),
                  greave=dict(mat='leather', y0=-0.52, y1=0.3, out=0.1, knee=0.16),
                  boot=dict(mat='leather', sole='sole', toe=0.26, cuff=0.12, cuff_mat='fur')),
        belt=dict(mat='leather', drop=0.5, plates=1, back=False, belt_mat='hood', buckle='trim', out=0.12),
        extra=collars,
    )


def huntsman():
    R = ramps(steel=['#34302E', '#545050', '#7A7676', '#A6A2A0'], brig=HUNT_RED, trim=HUNT_GOLD, leather=COMMON['leather'],
              fur=FUR, sole=['#161010', '#221816', '#2E201C', '#3A2A24'], cape=['#2A1414', '#42201C', '#5E2E26', '#7E4034'])
    def brig_deco(c, R):
        # бригантина: сетка латунных заклёпок по сукну
        for (i, j, k), col in list(c.c.items()):
            if col in R['brig'] and (i % 3 == 0) and (j % 3 == 0):
                c.c[(i, j, k)] = R['trim'][2]
        # рог на перевязи через грудь
        for (i, j, k), col in list(c.c.items()):
            x, y, z = cen(i), cen(j), cen(k)
            if abs((y - 0.7) + (x - 0.8) * 0.8) < 0.08 and (z < -0.55 or z > 0.55):
                c.c[(i, j, k)] = R['leather'][2]
    def horn(c):
        M.tip(c, [(-0.95, -0.2, -0.7), (-0.8, -0.35, -0.82), (-0.55, -0.42, -0.82), (-0.35, -0.38, -0.78)], 0.06, 0.16, mat='trim', curl=1.0)
    return warrior(
        'huntsman', 'rare', R,
        helm=dict(kind='kettle', R=0.72, top=0.76, bottom=-0.4, w=2.4, mat='steel', brim=0.36, brim_y=0.24, open_face=True,
                  deco=lambda h, R: rim(h, R['trim'][2], lambda x, y, z: math.hypot(x, z) > 1.0)),
        chest=dict(out=0.14, top=0.1, bottom=-0.78, bulge=0.1, mat='brig', lames=2, pre=horn, deco=brig_deco,
                   gorget=dict(h=0.2, ri=0.38, ro=0.64, mat='steel')),
        arms=dict(pauldron=dict(R=0.76, top=0.84, lames=3, drop=0.8, mat='steel', trim='trim', sleeve='brig'),
                  bracer=dict(y0=-0.48, y1=0.22, r=0.6, flare=0.06, mat='steel', trim='trim'),
                  gauntlet=dict(mat='leather', cuff='steel', r=0.58)),
        legs=dict(cuisse=dict(mat='brig', y0=-0.35, y1=0.5, out=0.1, wrap=0.4),
                  greave=dict(mat='steel', y0=-0.52, y1=0.4, out=0.12, knee=0.2),
                  boot=dict(mat='leather', sole='sole', toe=0.26, cuff=0.1, cuff_mat='fur')),
        belt=dict(mat='steel', drop=0.56, plates=2, belt_mat='leather', buckle='trim', tasset_mat='brig'),
        cape=dict(y_top=0.74, y_bot=-1.1, segs=3, w_top=0.86, w_bot=0.98, z0=0.7, fold=0.05, folds=6, hem='swallow', hem_depth=0.3, mat='cape', trim='trim'),
    )


def bear_hunter():
    R = ramps(steel=['#2A2624', '#46403C', '#665E58', '#8A827A'], fur=FUR, bone=BONE, trim=HUNT_GOLD, leather=COMMON['leather'],
              sole=['#161010', '#221816', '#2E201C', '#3A2A24'], red=HUNT_RED)
    def bear_head(h):
        # медвежья голова поверх шлема: меховой купол, уши, морда над визором, клыки
        h.fill((-0.95, 0.2, -1.1), (0.95, 1.05, 0.95),
               lambda x, y, z: (x / 0.86) ** 2 + ((y - 0.5) / 0.48) ** 2 + ((z - 0.02) / 0.88) ** 2 <= 1 and y > 0.32, 'fur')
        for sx in (1, -1):
            h.fill((sx * 0.4 - 0.18, 0.8, -0.2), (sx * 0.4 + 0.18, 1.12, 0.12),
                   lambda x, y, z, sx=sx: ((x - sx * 0.5) / 0.15) ** 2 + ((y - 0.92) / 0.16) ** 2 + ((z + 0.05) / 0.12) ** 2 <= 1, 'fur')
        h.fill((-0.38, 0.22, -1.16), (0.38, 0.62, -0.62), lambda x, y, z: (x / 0.34) ** 2 + ((y - 0.42) / 0.2) ** 2 <= 1 and z < -0.66, 'fur')
        for x0 in (-0.26, -0.1, 0.1, 0.26):
            h.fill((x0 - 0.05, 0.12, -1.0), (x0 + 0.05, 0.26, -0.86), lambda x, y, z: True, 'bone')
    def fur_mantle(c):
        fur_ring(c, TY - 0.1, TY + 0.28, 0.4, 1.12, seed=8)
    def claws(pieces, R):
        for g in bypart(pieces, 'Gauntlet'):
            for i in (-2, 0, 2):
                g.c[(i, -2, -6)] = R['bone'][3]
                g.c[(i, -3, -6)] = R['bone'][2]
    return warrior(
        'bear_hunter', 'epic', R,
        helm=dict(kind='great', R=0.72, top=0.58, bottom=-0.62, w=2.8, mat='steel', slit=0.0, neck=0.14, prow=0.1, pre=bear_head),
        chest=dict(out=0.16, top=0.12, bottom=-0.78, bulge=0.14, mat='steel', lames=3, lame_mat='leather', pre=fur_mantle,
                   deco=lambda c, R: rim(c, R['trim'][2], lambda x, y, z: y < -0.72)),
        arms=dict(pauldron=dict(R=0.86, top=0.92, lames=2, drop=0.85, mat='fur', trim=None, sleeve='mail', layered=False),
                  bracer=dict(y0=-0.48, y1=0.24, r=0.61, flare=0.08, mat='steel', trim='bone'),
                  gauntlet=dict(mat='steel', cuff='fur', r=0.6)),
        legs=dict(cuisse=dict(mat='steel', y0=-0.45, y1=0.5, out=0.12, wrap=0.6),
                  greave=dict(mat='steel', y0=-0.55, y1=0.42, out=0.13, knee=0.22, knee_mat='bone'),
                  boot=dict(mat='steel', sole='sole', toe=0.3, cuff=0.12, cuff_mat='fur')),
        belt=dict(mat='steel', drop=0.66, plates=2, belt_mat='red', buckle='bone', tasset_mat='leather'),
        cape=dict(y_top=0.8, y_bot=-1.8, segs=4, w_top=0.98, w_bot=1.14, z0=0.7, fold=0.08, folds=7, hem='tattered', hem_depth=0.4,
                  ragged=0.3, seed=37, mat='fur'),
        extra=claws,
    )


def royal_hunt():
    R = ramps(steel=['#3A2C24', '#5E4A3A', '#86705A', '#B09A80'], trim=HUNT_GOLD, red=HUNT_RED, bone=BONE, fur=FUR_W,
              leather=COMMON['leather'], sole=['#161010', '#221816', '#2E201C', '#3A2A24'], cape=['#3B1414', '#5E1E1C', '#862C26', '#A84236'])
    antler = [(0.42, 0.55, 0.0), (0.7, 0.9, 0.05), (0.85, 1.25, 0.1), (0.78, 1.6, 0.2)]
    def crown_antlers(h):
        P.spikes(h, 5, 0.56, 0.66, 0.26, r0=0.09, mat='trim', arc=math.pi * 1.4)
        P.horns(h, antler, 0.1, 0.04, mat='bone')
        for sx in (1, -1):
            M.tip(h, [(sx * 0.74, 0.95, 0.06), (sx * 0.95, 1.05, 0.0), (sx * 1.08, 1.2, -0.05), (sx * 1.12, 1.36, -0.08)], 0.06, 0.03, mat='bone')
            M.tip(h, [(sx * 0.84, 1.3, 0.12), (sx * 0.62, 1.42, 0.14), (sx * 0.52, 1.56, 0.12), (sx * 0.46, 1.7, 0.1)], 0.05, 0.03, mat='bone')
    def tabard(c):
        c.recolor(lambda x, y, z, m: 'red' if abs(x) < 0.5 and y < 0.6 and m.startswith('steel') else None)
        fur_ring(c, TY - 0.08, TY + 0.26, 0.4, 1.0, seed=9)
    def hound_sigil(c, R):
        # золотая гончая на табарде (силуэт 7×5)
        pat = ['0011000', '0111100', '1111111', '0111110', '0100010']
        for (i, j, k), col in list(c.c.items()):
            x, y, z = cen(i), cen(j), cen(k)
            if z > -0.55 or (i, j, k - 1) in c.c:
                continue
            ii, jj = i + 3, 4 - (j - 0)
            if 0 <= ii < 7 and 0 <= jj < 5 and pat[jj][ii] == '1':
                c.c[(i, j, k)] = R['trim'][2] if (ii + jj) % 3 else R['trim'][3]
        rim(c, R['trim'][2], lambda x, y, z: abs(abs(x) - 0.5) < 0.07 and y < 0.6)
        runes(c, AMBER, lambda x, y, z: y < -0.65 and abs(x) < 0.45, density=0.5, seed=61)
    def cape_deco(cl, R):
        rim(cl, R['trim'][2], lambda x, y, z: y < -1.6)
        runes(cl, AMBER, lambda x, y, z: abs(x) < 0.08 and y > -1.4, density=0.55, seed=62, normals=((0, 0, 1),))
    return warrior(
        'royal_hunt', 'legendary', R,
        helm=dict(kind='great', R=0.74, top=0.62, bottom=-0.62, w=3.0, mat='steel', slit=0.04, neck=0.14, prow=0.14, pre=crown_antlers,
                  deco=lambda h, R: rim(h, R['trim'][2], lambda x, y, z: y < -0.5)),
        chest=dict(out=0.16, top=0.12, bottom=-0.78, bulge=0.16, mat='steel', lames=3, pre=tabard, deco=hound_sigil,
                   gorget=dict(h=0.22, ri=0.38, ro=0.66, mat='trim')),
        arms=dict(pauldron=dict(R=0.86, top=0.92, lames=4, drop=1.0, mat='steel', trim='trim', sleeve='red', step=0.06),
                  bracer=dict(y0=-0.48, y1=0.26, r=0.61, flare=0.1, mat='steel', trim='trim'),
                  gauntlet=dict(mat='steel', cuff='trim', r=0.6)),
        legs=dict(cuisse=dict(mat='steel', y0=-0.45, y1=0.5, out=0.12, wrap=0.6),
                  greave=dict(mat='steel', y0=-0.55, y1=0.42, out=0.13, knee=0.22, knee_mat='trim'),
                  boot=dict(mat='steel', sole='sole', toe=0.3, cuff=0.12, cuff_mat='fur')),
        belt=dict(mat='steel', drop=0.7, plates=2, belt_mat='red', buckle='trim', tasset_mat='red'),
        cape=dict(y_top=0.8, y_bot=-2.2, segs=4, w_top=0.98, w_bot=1.22, z0=0.72, fold=0.07, folds=7, hem='point', hem_depth=0.36,
                  mat='cape', trim='trim', deco=cape_deco),
        eye=AMBER,
    )


# =====================================================================
# ЭТАЖ 4 «ЛИТЕЙНЫЕ»: чугун, бронза, сажа, раскалённые трещины
# =====================================================================
EMBER = '!#FF8A2A'
MOLTEN = '!#FFC857'
IRON = ['#141216', '#25222A', '#3A3640', '#55505C']
BRONZE = ['#4A2A12', '#7A4A1E', '#A8702E', '#D49A48']
SOOT = ['#1A1818', '#2A2626', '#3C3636', '#524A48']


def apprentice_smith():
    R = ramps(leather=['#2A1C14', '#42301E', '#5C442C', '#7A5C3C'], apron=['#241C18', '#382A22', '#4E3C30', '#6A5242'],
              steel=IRON, trim=COMMON['brass'], soot=SOOT, sole=['#121010', '#1C1818', '#262020', '#302828'],
              lens=['#1E3A3A', '#2E5A5A', '#3E7A7A', '#5EA0A0'])
    def goggles(h):
        # очки на лбу: латунный обод и две линзы
        for sx in (1, -1):
            h.fill((sx * 0.25 - 0.17, 0.26, -0.86), (sx * 0.25 + 0.17, 0.52, -0.66),
                   lambda x, y, z, sx=sx: ((x - sx * 0.25) / 0.16) ** 2 + ((y - 0.39) / 0.12) ** 2 <= 1, 'trim')
            h.fill((sx * 0.25 - 0.1, 0.32, -0.9), (sx * 0.25 + 0.1, 0.46, -0.82),
                   lambda x, y, z, sx=sx: ((x - sx * 0.25) / 0.09) ** 2 + ((y - 0.39) / 0.07) ** 2 <= 1, 'lens')
        h.recolor(lambda x, y, z, m: 'leather' if m.startswith('apron') and abs(y - 0.39) < 0.08 else None)
    def soot_deco(p, R):
        for (i, j, k), col in list(p.c.items()):
            if cen(j) < -0.2 and H(91, i, j, k) < 0.25:
                p.c[(i, j, k)] = R['soot'][1]
    return warrior(
        'apprentice_smith', 'common', R,
        helm=dict(kind='cap', R=0.68, top=0.66, bottom=-0.3, w=2.6, mat='apron', pre=goggles),
        chest=dict(out=0.1, top=0.06, bottom=-0.78, bulge=0.04, mat='apron', lames=0, deco=soot_deco,
                   pre=lambda c: c.recolor(lambda x, y, z, m: 'leather' if abs(abs(x) - 0.55) < 0.07 else None)),
        arms=dict(pauldron=dict(R=0.68, top=0.78, lames=1, drop=0.5, mat='leather', trim='trim', sleeve='apron', sleeve_y=-0.1, layered=False),
                  bracer=dict(y0=-0.48, y1=0.3, r=0.62, flare=0.14, mat='leather', trim=None),
                  gauntlet=dict(mat='leather', cuff='leather', r=0.62, knuckles=False)),
        legs=dict(cuisse=dict(mat='apron', y0=-0.1, y1=0.5, out=0.08, wrap=0.2),
                  greave=dict(mat='leather', y0=-0.5, y1=0.1, out=0.1, knee=0.0),
                  boot=dict(mat='steel', sole='sole', toe=0.3, cuff=0.0)),
        belt=dict(mat='apron', drop=0.72, plates=1, back=False, belt_mat='leather', buckle='trim', out=0.12),
    )


def caster():
    R = ramps(steel=IRON, bronze=BRONZE, trim=BRONZE, leather=COMMON['leather'], sole=['#121010', '#1C1818', '#262020', '#302828'],
              cape=['#1A1618', '#2A2428', '#3C343A', '#52484E'])
    def rivet_deco(p, R):
        P.rivets(p, R['bronze'][3], lambda x, y, z: y > 0.5 or y < -0.6, step=11)
    return warrior(
        'caster', 'rare', R,
        helm=dict(kind='great', R=0.72, top=0.7, bottom=-0.62, w=4.0, mat='steel', face_mat='bronze', slit=0.04, neck=0.14, holes=True,
                  deco=rivet_deco),
        chest=dict(out=0.16, top=0.1, bottom=-0.78, bulge=0.12, mat='bronze', lames=3, lame_mat='steel', deco=rivet_deco,
                   gorget=dict(h=0.22, ri=0.38, ro=0.66, mat='steel')),
        arms=dict(pauldron=dict(R=0.8, top=0.88, lames=3, drop=0.85, mat='steel', trim='bronze', sleeve='mail'),
                  bracer=dict(y0=-0.48, y1=0.24, r=0.61, flare=0.08, mat='bronze', trim='steel'),
                  gauntlet=dict(mat='steel', cuff='bronze', r=0.6), deco=rivet_deco),
        legs=dict(cuisse=dict(mat='steel', y0=-0.45, y1=0.5, out=0.12, wrap=0.5),
                  greave=dict(mat='bronze', y0=-0.55, y1=0.42, out=0.13, knee=0.22, knee_mat='steel'),
                  boot=dict(mat='steel', sole='sole', toe=0.3)),
        belt=dict(mat='steel', drop=0.62, plates=2, belt_mat='leather', buckle='bronze', tasset_mat='bronze'),
        cape=dict(y_top=0.74, y_bot=-1.0, segs=2, w_top=0.84, w_bot=0.94, z0=0.7, fold=0.04, folds=5, hem='round', mat='cape', trim='bronze'),
    )


def scale_knight():
    R = ramps(steel=['#121012', '#1E1A1E', '#2E282E', '#443C42'], scale=['#2A1A12', '#3E2618', '#5A3820', '#7A4E2C'],
              trim=BRONZE, leather=COMMON['leather'], sole=['#0E0C0C', '#181414', '#221C1C', '#2C2424'],
              cape=['#141012', '#201A1C', '#2E2628', '#3E3436'], horn=['#1A1414', '#2C2222', '#403232', '#584646'])
    def helm_pre(h):
        P.horns(h, [(0.5, 0.35, 0.05), (0.85, 0.5, 0.1), (1.0, 0.85, 0.2), (0.92, 1.18, 0.3)], 0.14, 0.04, mat='horn')
    def scales(p, R):
        # чешуя окалины: ряды полукружий, кромка ряда темнее
        for (i, j, k), col in list(p.c.items()):
            if col.startswith('!'):
                continue
            if (j % 3 == 0) and ((i + (j // 3)) % 2 == 0):
                p.c[(i, j, k)] = R['scale'][0]
        P.cracks(p, EMBER, lambda x, y, z: True, seed=71, density=0.16)
    def pspikes(pieces, R):
        for p in bypart(pieces, 'Pauldron'):
            sx = 1 if p.name.endswith('R') else -1
            extra = Piece('tmp', p.part, 'armor')
            for zz in (-0.3, 0.05, 0.38):
                M.tip(extra, [(sx * 0.2, 0.8, zz), (sx * 0.3, 1.0, zz), (sx * 0.38, 1.2, zz), (sx * 0.42, 1.36, zz)], 0.11, 0.03, mat='horn')
            extra.shade(R)
            for key, col in extra.c.items():
                p.c.setdefault(key, col)
    return warrior(
        'scale_knight', 'epic', R,
        helm=dict(kind='sallet', R=0.74, top=0.72, bottom=-0.62, w=2.8, mat='steel', slit=0.04, neck=0.12, prow=0.22, pre=helm_pre,
                  deco=scales),
        chest=dict(out=0.16, top=0.12, bottom=-0.78, bulge=0.14, mat='steel', lames=3, deco=scales,
                   gorget=dict(h=0.24, ri=0.38, ro=0.68, mat='steel')),
        arms=dict(pauldron=dict(R=0.84, top=0.9, lames=4, drop=1.0, mat='steel', trim='scale', sleeve='mail'),
                  bracer=dict(y0=-0.48, y1=0.24, r=0.61, flare=0.1, mat='steel', trim='scale'),
                  gauntlet=dict(mat='steel', cuff='steel', r=0.6), deco=scales),
        legs=dict(cuisse=dict(mat='steel', y0=-0.45, y1=0.5, out=0.12, wrap=0.6),
                  greave=dict(mat='steel', y0=-0.55, y1=0.42, out=0.13, knee=0.22),
                  boot=dict(mat='steel', sole='sole', toe=0.32), deco=scales),
        belt=dict(mat='steel', drop=0.66, plates=2, belt_mat='leather', buckle='trim', deco=scales),
        cape=dict(y_top=0.76, y_bot=-1.9, segs=4, w_top=0.92, w_bot=1.12, z0=0.7, fold=0.07, folds=7, hem='tattered', hem_depth=0.5,
                  ragged=0.35, seed=73, mat='cape', deco=lambda cl, R: runes(cl, EMBER, lambda x, y, z: y < -1.3, density=0.35, seed=74, normals=((0, 0, 1),))),
        extra=pspikes,
        eye=EMBER,
    )


def elder_founder():
    R = ramps(steel=IRON, bronze=BRONZE, trim=['#7A5418', '#B07C24', '#E0A83C', '#FFD27A'], leather=COMMON['leather'],
              sole=['#0E0C0C', '#181414', '#221C1C', '#2C2424'], cape=['#161214', '#241E20', '#342C2E', '#483E40'])
    def crucible_crown(h):
        # венец-изложница: литейная чаша над шлемом, внутри — расплав
        h.fill((-0.66, 0.6, -0.66), (0.66, 0.98, 0.66), lambda x, y, z: 0.44 <= math.hypot(x, z) <= 0.62 + 0.2 * (y - 0.6), 'bronze')
        h.fill((-0.5, 0.78, -0.5), (0.5, 0.9, 0.5), lambda x, y, z: math.hypot(x, z) < 0.46, MOLTEN)
        for a in range(8):
            th = a / 8 * 2 * math.pi
            M.tip(h, [(0.66 * math.cos(th), 0.95, 0.66 * math.sin(th)), (0.7 * math.cos(th), 1.05, 0.7 * math.sin(th)),
                      (0.72 * math.cos(th), 1.12, 0.72 * math.sin(th)), (0.74 * math.cos(th), 1.2, 0.74 * math.sin(th))], 0.07, 0.03, mat='trim')
    def channels(p, R):
        # каналы расплава: вертикальные светящиеся жилы по бронзе
        for (i, j, k), col in list(p.c.items()):
            if col in R['bronze'] and i % 8 == 0 and cen(k) < -0.4 and H(81, i, j // 3, k) < 0.6:
                p.c[(i, j, k)] = EMBER
        rim(p, R['trim'][2], lambda x, y, z: y < -0.7 or y > 0.85)
    def anvil_sigil(c, R):
        pat = ['1111111', '0111110', '0011100', '0011100', '0111110']
        for (i, j, k), col in list(c.c.items()):
            if cen(k) > -0.55 or (i, j, k - 1) in c.c:
                continue
            ii, jj = i + 3, 6 - j
            if 0 <= ii < 7 and 0 <= jj < 5 and pat[jj][ii] == '1':
                c.c[(i, j, k)] = MOLTEN if jj == 0 else R['trim'][2]
        channels(c, R)
    def cape_deco(cl, R):
        runes(cl, EMBER, lambda x, y, z: y < -1.5, density=0.5, seed=84, normals=((0, 0, 1),))
        rim(cl, R['trim'][2], lambda x, y, z: y < -1.9)
    return warrior(
        'elder_founder', 'legendary', R,
        helm=dict(kind='great', R=0.74, top=0.66, bottom=-0.62, w=3.2, mat='bronze', face_mat='steel', slit=0.04, neck=0.14, prow=0.1,
                  pre=crucible_crown, deco=lambda h, R: rim(h, R['trim'][2], lambda x, y, z: y < -0.5)),
        chest=dict(out=0.18, top=0.12, bottom=-0.78, bulge=0.18, mat='bronze', lames=3, lame_mat='steel', deco=anvil_sigil,
                   gorget=dict(h=0.26, ri=0.38, ro=0.7, mat='trim')),
        arms=dict(pauldron=dict(R=0.9, top=0.94, lames=4, drop=1.0, mat='bronze', trim='trim', sleeve='mail', step=0.06),
                  bracer=dict(y0=-0.48, y1=0.26, r=0.62, flare=0.12, mat='bronze', trim='trim'),
                  gauntlet=dict(mat='steel', cuff='trim', r=0.62), deco=channels),
        legs=dict(cuisse=dict(mat='bronze', y0=-0.45, y1=0.5, out=0.12, wrap=0.6),
                  greave=dict(mat='bronze', y0=-0.55, y1=0.42, out=0.13, knee=0.24, knee_mat='trim'),
                  boot=dict(mat='steel', sole='sole', toe=0.32, cuff=0.06, cuff_mat='trim'), deco=channels),
        belt=dict(mat='steel', drop=0.72, plates=2, belt_mat='leather', buckle='trim', tasset_mat='bronze'),
        cape=dict(y_top=0.8, y_bot=-2.2, segs=4, w_top=0.98, w_bot=1.22, z0=0.72, fold=0.07, folds=7, hem='point', hem_depth=0.36,
                  mat='cape', trim='trim', deco=cape_deco),
        eye=MOLTEN,
    )


# =====================================================================
# ЭТАЖ 5 «ЗАЛ ХРОНИК»: индиго, фиолет, пергамент, чернила, сургуч, руны
# =====================================================================
INK_GLOW = '!#8EC8FF'
INDIGO = ['#141230', '#221E48', '#342E6A', '#4A4290']
VIOLET_ST = ['#2A2450', '#423A7A', '#5E54A6', '#8478CE']
PAPER = ['#9C8E6E', '#C8B990', '#E6DAB4', '#FBF3D8']
WAX = ['#4E1218', '#7A1C24', '#A42A32', '#CC4048']


def scribe():
    R = ramps(cloth=INDIGO, paper=PAPER, leather=COMMON['leather'], steel=['#2E2C3A', '#46445A', '#646280', '#8A88A8'],
              trim=COMMON['silver'], ink=['#0C0C18', '#16162A', '#22223E', '#30305A'], sole=['#100E16', '#1A1822', '#24222E', '#2E2C3A'])
    def quill(h):
        M.tip(h, [(0.62, 0.0, 0.2), (0.75, 0.35, 0.3), (0.82, 0.7, 0.42), (0.86, 1.0, 0.56)], 0.08, 0.03, mat='paper')
    def strips(c, R):
        # пергаментные полоски-записки, приколотые к стёганке
        for (i, j, k), col in list(c.c.items()):
            x, y, z = cen(i), cen(j), cen(k)
            if z < -0.55 and (i, j, k - 1) not in c.c and ((0.25 < x < 0.5 and -0.1 < y < 0.45) or (-0.6 < x < -0.35 and -0.5 < y < 0.0)):
                c.c[(i, j, k)] = R['paper'][2] if j % 2 else R['ink'][2]
            elif H(93, i, j, k) < 0.05 and col in R['cloth']:
                c.c[(i, j, k)] = R['ink'][1]
        P.stripes(c, R['cloth'][0], lambda x, y, z: col_in(c, x, y, z, R['cloth']), period=3, axis=1)
    return warrior(
        'scribe', 'common', R,
        helm=dict(kind='hood', R=0.7, top=0.72, bottom=-0.62, w=2.4, mat='cloth', pre=quill),
        chest=dict(out=0.12, top=0.08, bottom=-0.78, bulge=0.05, mat='cloth', lames=0, deco=strips,
                   gorget=dict(h=0.16, ri=0.38, ro=0.6, mat='cloth')),
        arms=dict(pauldron=dict(R=0.7, top=0.8, lames=2, drop=0.6, mat='cloth', trim='paper', sleeve='cloth', sleeve_y=-0.3),
                  bracer=dict(y0=-0.48, y1=0.14, r=0.6, flare=0.04, mat='leather', trim='paper'),
                  gauntlet=dict(mat='leather', cuff='leather', r=0.58, knuckles=False)),
        legs=dict(cuisse=dict(mat='cloth', y0=-0.2, y1=0.5, out=0.08, wrap=0.3),
                  greave=dict(mat='leather', y0=-0.52, y1=0.2, out=0.1, knee=0.0),
                  boot=dict(mat='leather', sole='sole', toe=0.26)),
        belt=dict(mat='cloth', drop=0.5, plates=1, back=False, belt_mat='leather', buckle='trim', out=0.12,
                  pre=lambda b: b.fill((0.7, -0.2, -0.8), (1.0, 0.12, -0.5), lambda x, y, z: (x - 0.85) ** 2 + (z + 0.65) ** 2 <= 0.11 ** 2, 'ink')),
    )


def col_in(p, x, y, z, ramp):
    return p.c.get((math.floor(x / V), math.floor(y / V), math.floor(z / V))) in ramp


def binder():
    R = ramps(steel=VIOLET_ST, leather=['#2A1418', '#421E24', '#5E2C34', '#7C3E48'], trim=COMMON['silver'], paper=PAPER,
              sole=['#100E16', '#1A1822', '#24222E', '#2E2C3A'], cape=INDIGO)
    def straps(p, R):
        # застёжки переплёта: кожаные ремни с серебряными пряжками крест-накрест
        for (i, j, k), col in list(p.c.items()):
            x, y, z = cen(i), cen(j), cen(k)
            if abs(abs(x) - 0.45) < 0.08 and (z < -0.5 or z > 0.5):
                p.c[(i, j, k)] = R['leather'][2] if abs(y - 0.0) > 0.1 else R['trim'][3]
    def page_edges(p, R):
        rim(p, R['paper'][2], lambda x, y, z: y < -0.7)
    def helm_straps(h, R):
        for (i, j, k), col in list(h.c.items()):
            x, y, z = cen(i), cen(j), cen(k)
            if abs(x) < 0.07 and y > 0.2:
                h.c[(i, j, k)] = R['leather'][2]
            if abs(y - 0.45) < 0.06 and abs(x) < 0.12 and z < -0.5:
                h.c[(i, j, k)] = R['trim'][3]
    return warrior(
        'binder', 'rare', R,
        helm=dict(kind='sallet', R=0.74, top=0.74, bottom=-0.6, w=2.6, mat='steel', slit=0.04, neck=0.14, prow=0.12, deco=helm_straps),
        chest=dict(out=0.16, top=0.1, bottom=-0.78, bulge=0.1, mat='leather', lames=3, lame_mat='steel', deco=lambda c, R: (straps(c, R), page_edges(c, R)),
                   gorget=dict(h=0.22, ri=0.38, ro=0.66, mat='steel')),
        arms=dict(pauldron=dict(R=0.8, top=0.88, lames=3, drop=0.85, mat='steel', trim='paper', sleeve='leather'),
                  bracer=dict(y0=-0.48, y1=0.24, r=0.61, flare=0.08, mat='leather', trim='trim'),
                  gauntlet=dict(mat='steel', cuff='leather', r=0.6)),
        legs=dict(cuisse=dict(mat='steel', y0=-0.45, y1=0.5, out=0.12, wrap=0.5),
                  greave=dict(mat='steel', y0=-0.55, y1=0.42, out=0.13, knee=0.22, knee_mat='trim'),
                  boot=dict(mat='leather', sole='sole', toe=0.28, cuff=0.06, cuff_mat='steel')),
        belt=dict(mat='steel', drop=0.62, plates=2, belt_mat='leather', buckle='trim', tasset_mat='leather'),
        cape=dict(y_top=0.76, y_bot=-1.5, segs=3, w_top=0.9, w_bot=1.02, z0=0.7, fold=0.05, folds=6, hem='round', mat='cape', trim='paper'),
    )


def seal_keeper():
    R = ramps(steel=['#1C1838', '#2C265A', '#40387E', '#5A50A6'], wax=WAX, trim=COMMON['silver'], paper=PAPER,
              leather=COMMON['leather'], sole=['#0E0C16', '#18162A', '#22203A', '#2C2A4A'], cape=['#18142E', '#241E46', '#342C64', '#463C84'])
    def seal_brow(h):
        h.fill((-0.24, 0.3, -0.96), (0.24, 0.72, -0.7), lambda x, y, z: x * x + (y - 0.5) ** 2 <= 0.2 ** 2 and z < -0.72, 'wax')
        P.horns(h, [(0.45, 0.4, 0.1), (0.7, 0.6, 0.15), (0.82, 0.9, 0.25), (0.78, 1.15, 0.38)], 0.12, 0.04, mat='steel')
    def seals(p, R):
        for (i, j, k), col in list(p.c.items()):
            x, y, z = cen(i), cen(j), cen(k)
            if (i, j, k - 1) in p.c:
                continue
            for (sx, sy) in ((-0.45, 0.35), (0.45, 0.35), (0.0, -0.3)):
                if math.hypot(x - sx, y - sy) < 0.16 and z < -0.5:
                    p.c[(i, j, k)] = R['wax'][2] if math.hypot(x - sx, y - sy) > 0.06 else R['wax'][3]
        runes(p, INK_GLOW, lambda x, y, z: abs(y - 0.68) < 0.06, density=0.55, seed=95)
    def ribbons(c):
        for x0 in (-0.45, 0.45):
            c.fill((x0 - 0.06, -0.75, -0.8), (x0 + 0.06, 0.25, -0.6), lambda x, y, z, x0=x0: y < 0.2 and -0.78 < z < -0.66, 'paper')
    def arm_deco(p, R):
        if p.name.startswith('Pauldron'):
            for (i, j, k), col in list(p.c.items()):
                if abs(cen(j) - 0.78) < 0.08 and abs(cen(k)) < 0.12:
                    p.c[(i, j, k)] = R['wax'][2]
    return warrior(
        'seal_keeper', 'epic', R,
        helm=dict(kind='great', R=0.74, top=0.7, bottom=-0.62, w=3.0, mat='steel', slit=0.0, neck=0.14, prow=0.12, pre=seal_brow,
                  deco=lambda h, R: runes(h, INK_GLOW, lambda x, y, z: -0.45 < y < -0.3, density=0.5, seed=96)),
        chest=dict(out=0.16, top=0.12, bottom=-0.78, bulge=0.14, mat='steel', lames=3, pre=ribbons, deco=seals,
                   gorget=dict(h=0.24, ri=0.38, ro=0.68, mat='steel')),
        arms=dict(pauldron=dict(R=0.84, top=0.9, lames=3, drop=0.95, mat='steel', trim='trim', sleeve='mail'),
                  bracer=dict(y0=-0.48, y1=0.24, r=0.61, flare=0.1, mat='steel', trim='wax'),
                  gauntlet=dict(mat='steel', cuff='steel', r=0.6), deco=arm_deco),
        legs=dict(cuisse=dict(mat='steel', y0=-0.45, y1=0.5, out=0.12, wrap=0.6),
                  greave=dict(mat='steel', y0=-0.55, y1=0.42, out=0.13, knee=0.22, knee_mat='trim'),
                  boot=dict(mat='steel', sole='sole', toe=0.3)),
        belt=dict(mat='steel', drop=0.66, plates=2, belt_mat='wax', buckle='trim'),
        cape=dict(y_top=0.76, y_bot=-1.9, segs=4, w_top=0.92, w_bot=1.12, z0=0.7, fold=0.06, folds=7, hem='tattered', hem_depth=0.35,
                  ragged=0.2, seed=97, mat='cape', deco=lambda cl, R: runes(cl, INK_GLOW, lambda x, y, z: y < -1.2, density=0.35, seed=98, normals=((0, 0, 1),))),
        eye=INK_GLOW,
    )


def chief_chronicler():
    R = ramps(steel=['#5A5288', '#7C74AE', '#A49CD0', '#CCC6EC'], trim=COMMON['gold'], paper=PAPER, ink=INDIGO,
              leather=COMMON['leather'], sole=['#0E0C16', '#18162A', '#22203A', '#2C2A4A'], cape=['#141030', '#201A4A', '#302868', '#443A8C'])
    def rune_crown(h):
        P.spikes(h, 9, 0.58, 0.64, 0.4, r0=0.08, mat='trim', arc=2 * math.pi, phase=0.0)
        h.fill((-0.2, 0.9, -0.2), (0.2, 1.3, 0.2), lambda x, y, z: x * x + (y - 1.08) ** 2 + z * z <= 0.14 ** 2, INK_GLOW)
    def pages(pieces, R):
        # страницы, вылетающие из наплечников
        for p in bypart(pieces, 'Pauldron'):
            sx = 1 if p.name.endswith('R') else -1
            for n, (zz, yy) in enumerate(((-0.35, 0.95), (0.1, 1.02), (0.45, 0.92))):
                for a in range(3):
                    for b in range(2):
                        p.c[(math.floor((sx * (0.3 + 0.08 * n) + a * sx * V) / V), math.floor((yy + b * V) / V), math.floor(zz / V))] = R['paper'][2 + (a + b) % 2]
    def script(p, R):
        runes(p, INK_GLOW, lambda x, y, z: abs(x) < 0.5 and z < 0, density=0.08, seed=99)
        rim(p, R['trim'][2], lambda x, y, z: y < -0.7)
    def cape_deco(cl, R):
        # строки текста: светящиеся горизонтальные штрихи
        for (i, j, k), col in list(cl.c.items()):
            if (i, j, k + 1) in cl.c:
                continue
            if j % 3 == 0 and -1.8 < cen(j) < 0.3 and abs(cen(i)) < 0.85 and H(100, i // 2, j) < 0.6:
                cl.c[(i, j, k)] = INK_GLOW
        rim(cl, R['trim'][2], lambda x, y, z: y < -1.95)
    return warrior(
        'chief_chronicler', 'legendary', R,
        helm=dict(kind='great', R=0.74, top=0.66, bottom=-0.62, w=3.0, mat='steel', slit=0.04, neck=0.14, prow=0.14, pre=rune_crown,
                  deco=lambda h, R: (rim(h, R['trim'][2], lambda x, y, z: y < -0.5), runes(h, INK_GLOW, lambda x, y, z: y > 0.3 and y < 0.5, density=0.6, seed=101))),
        chest=dict(out=0.18, top=0.12, bottom=-0.78, bulge=0.18, mat='steel', lames=3, lame_mat='ink', deco=script,
                   gorget=dict(h=0.26, ri=0.38, ro=0.7, mat='trim')),
        arms=dict(pauldron=dict(R=0.9, top=0.94, lames=4, drop=1.0, mat='steel', trim='trim', sleeve='ink', step=0.06),
                  bracer=dict(y0=-0.48, y1=0.26, r=0.62, flare=0.12, mat='steel', trim='trim'),
                  gauntlet=dict(mat='steel', cuff='trim', r=0.62), deco=lambda p, R: runes(p, INK_GLOW, lambda x, y, z: p.name.startswith('Bracer') and abs(y) < 0.1, density=0.4, seed=102)),
        legs=dict(cuisse=dict(mat='steel', y0=-0.45, y1=0.5, out=0.12, wrap=0.6),
                  greave=dict(mat='steel', y0=-0.55, y1=0.42, out=0.13, knee=0.24, knee_mat='trim'),
                  boot=dict(mat='steel', sole='sole', toe=0.32, cuff=0.06, cuff_mat='trim')),
        belt=dict(mat='steel', drop=0.72, plates=2, belt_mat='ink', buckle='trim', tasset_mat='ink'),
        cape=dict(y_top=0.8, y_bot=-2.2, segs=4, w_top=0.98, w_bot=1.22, z0=0.72, fold=0.07, folds=7, hem='point', hem_depth=0.36,
                  mat='cape', trim='trim', deco=cape_deco),
        extra=pages,
        eye=INK_GLOW,
    )


# =====================================================================
# Маг: шляпа + пелерина + наплечные драпировки + обшлаги + пояс + плащ
# (те же детали, что у Хронистов этажа 1 — mage_parts)
# =====================================================================
def mage(sid, rarity, R, hat, mantle, cape, belt=None, shoulders=None, cuffs=None, eyes=MEMORY, extra=None):
    """hat: brim(R, y0, …), crown(y0, h, r0, r1, …), tip([4 точки], r0, r1) | None, band(y0, y1), pre/deco.
    mantle: параметры M.mantle + collar/clasp/trim/deco. cape: параметры M.cape + trim/deco."""
    pieces = []
    h = piece('Hat', 'Head', 'helm')
    hp = dict(hat)
    M.brim(h, **hp['brim'])
    M.crown(h, **hp['crown'])
    if hp.get('tip'):
        pts, r0, r1 = hp['tip'][:3]
        M.tip(h, pts, r0, r1, mat=hp['crown'].get('mat', 'crown'), curl=hp['tip'][3] if len(hp['tip']) > 3 else 1.0)
    if hp.get('band'):
        M.band(h, *hp['band'])
    if hp.get('pre'):
        hp['pre'](h)
    M.face(h, eyes=eyes)
    finish([h], R)
    if hp.get('deco'):
        hp['deco'](h, R)
    pieces.append(h)

    m = piece('Mantle', 'UpperTorso', 'armor')
    mp = dict(mantle)
    collar, clasp, trim, deco, pre = mp.pop('collar', None), mp.pop('clasp', None), mp.pop('trim', None), mp.pop('deco', None), mp.pop('pre', None)
    M.mantle(m, **mp)
    if collar:
        M.collar(m, **collar)
    if trim:
        M.outline_bottom(m, trim, mp.get('mat', 'mantle'))
    if clasp:
        M.clasp(m, **clasp)
    if pre:
        pre(m)
    finish([m], R)
    if deco:
        deco(m, R)
    pieces.append(m)

    sp = dict(shoulders or dict(L=0.4, mat=mp.get('mat', 'mantle'), trim=trim))
    cf = dict(cuffs or dict(y0=-0.52, y1=-0.16, r0=0.6, r1=0.7, mat=mp.get('mat', 'mantle'), trim=trim))
    sdeco = sp.pop('deco', None)
    arms = []
    for side in ('Right', 'Left'):
        d = piece('Shoulder' + side[0], side + 'UpperArm', 'armor')
        M.drape(d, side, **sp)
        c = piece('Cuff' + side[0], side + 'LowerArm', 'armor')
        M.cuff(c, **cf)
        arms += [d, c]
    finish(arms, R)
    if sdeco:
        for a in arms:
            sdeco(a, R)
    pieces += arms

    b = piece('Belt', 'LowerTorso', 'armor')
    bp = dict(belt or dict(mat='leather'))
    bdeco, bpre = bp.pop('deco', None), bp.pop('pre', None)
    M.sash(b, **bp)
    if bpre:
        bpre(b)
    finish([b], R)
    if bdeco:
        bdeco(b, R)
    pieces.append(b)

    cpp = dict(cape)
    ctrim, cdeco = cpp.pop('trim', None), cpp.pop('deco', None)
    cl = M.cape(sid, **cpp)
    if ctrim:
        M.outline_bottom(cl, ctrim, cpp.get('mat', 'cape'))
    finish([cl], R)
    if cdeco:
        cdeco(cl, R)
    pieces += M.split_cape(cl)
    if extra:
        extra(pieces, R)
    for p in pieces:
        if p.slot == 'helm' and p.face:
            p.lift(MS.HAT_LIFT)
    return dict(id=sid, rarity=rarity, body=BODY, pieces=pieces, **{'class': 'mage'})


def sprigs(h, color_mat, seed=1, n=4, y=0.5, r=0.7):
    """Веточки за лентой шляпы."""
    for a in range(n):
        th = -0.6 + a * 0.35 + seed * 0.1
        x, z = r * math.sin(th) + 0.1, -r * math.cos(th) * 0.3 + 0.4
        M.tip(h, [(x, y, z), (x * 1.1, y + 0.2, z + 0.05), (x * 1.2, y + 0.38, z + 0.1), (x * 1.25, y + 0.5, z + 0.18)], 0.06, 0.03, mat=color_mat)


# ---------- этаж 2
def herbalist():
    R = ramps(crown=['#3E3A22', '#5A5430', '#787040', '#968C56'], brim=['#3A3620', '#56502E', '#746C3E', '#908652'],
              band=['#1E3A22', '#2C5430', '#3E6E40', '#5A8C52'], mantle=['#2E2A1C', '#46402A', '#605838', '#7C724A'],
              leaf=['#1E3A22', '#2C5430', '#3E6E40', '#5A8C52'], cape=['#2A3A22', '#3C5230', '#506C40', '#688852'])
    return mage('herbalist', 'common', R,
                hat=dict(brim=dict(R=1.12, y0=0.3, droop=0.12, wave=0.05, waves=5, phase=0.3, mat='brim'),
                         crown=dict(y0=0.3, h=0.5, r0=0.72, r1=0.52, bend=(0.0, 0.08), mat='crown'),
                         tip=([(0.0, 0.78, 0.08), (0.05, 1.05, 0.14), (0.2, 1.2, 0.36), (0.36, 1.08, 0.6)], 0.5, 0.1),
                         band=(0.28, 0.42, 'band'), pre=lambda h: sprigs(h, 'leaf', seed=1)),
                mantle=dict(front=0.56, back=0.6, side=0.3, vpoint=0.08, mat='mantle', trim='band', clasp=dict(y=0.5, mat='band', w=2)),
                cape=dict(y_top=0.7, y_bot=-0.6, segs=2, w_top=0.84, w_bot=0.94, z0=0.68, fold=0.05, folds=6, hem='round', mat='cape', trim='band'),
                belt=dict(y0=-0.08, y1=0.1, mat='rope', knot=(-0.42, 'rope@0.3'), tails=[(-0.5, 0.3, 0.11, 'rope')],
                          pre=lambda b: M.pouch(b, 1.12, -0.12, 0.05, mat='leather', button='brass')))


def dew():
    R = ramps(crown=['#14302E', '#1E4844', '#2A625C', '#3A807A'], brim=['#122A28', '#1C403C', '#285A54', '#367670'],
              band=COMMON['silver'], mantle=['#163432', '#204C48', '#2C6660', '#3C847C'], cape=['#12302C', '#1C4640', '#285E58', '#367A72'])
    def drops(h, R):
        stars(h, R, R['band'][3], n=10, seed=21, region=lambda x, y, z: y > 0.45, glow=WATER, glow_share=0.5)
    return mage('dew', 'rare', R,
                hat=dict(brim=dict(R=1.06, y0=0.32, droop=0.05, wave=0.02, waves=3, mat='brim'),
                         crown=dict(y0=0.32, h=0.9, r0=0.7, r1=0.18, bend=(0.0, 0.06), w0=4.5, mat='crown'),
                         tip=([(0.0, 1.2, 0.06), (0.0, 1.42, 0.1), (0.05, 1.58, 0.2), (0.12, 1.66, 0.34)], 0.18, 0.05),
                         band=(0.3, 0.44, 'band'), deco=drops),
                mantle=dict(front=0.5, back=0.56, side=0.28, scallop=0.06, scallops=6, mat='mantle', trim='band',
                            collar=dict(h=0.24, ri=0.38, ro=0.62, open_front=0.0, flare=0.06, mat='band'),
                            deco=lambda m, R: stars(m, R, R['band'][3], n=6, seed=22, region=lambda x, y, z: z > 0, glow=WATER, glow_share=0.4)),
                cape=dict(y_top=0.74, y_bot=-1.2, segs=3, w_top=0.84, w_bot=0.96, z0=0.66, fold=0.05, folds=6, hem='swallow', hem_depth=0.3, mat='cape', trim='band',
                          deco=lambda cl, R: stars(cl, R, R['band'][3], n=12, seed=23, glow=WATER, glow_share=0.5)),
                belt=dict(y0=-0.12, y1=0.08, mat='band'))


def lotus():
    R = ramps(crown=['#5E2A3C', '#8A3E56', '#B85A74', '#E08AA0'], brim=['#E0D6CC', '#ECE4DA', '#F6F0E8', '#FFFFFF'],
              band=['#1E3A22', '#2C5430', '#3E6E40', '#5A8C52'], mantle=['#163432', '#204C48', '#2C6660', '#3C847C'],
              petal=['#7A3A4E', '#A85068', '#D07490', '#F0A8BC'], cape=['#12302C', '#1C4640', '#285E58', '#367A72'])
    def petals(h):
        # поля-лепестки: волна из 8 лепестков
        M.brim(h, 1.22, 0.3, th=0.13, droop=-0.08, wave=0.12, waves=8, phase=0.2, mat='petal')
    def glow_center(h, R):
        runes(h, WATER, lambda x, y, z: 0.3 < y < 0.45, density=0.6, seed=31)
        stars(h, R, R['petal'][3], n=8, seed=32, region=lambda x, y, z: y > 0.6, glow=ROSE, glow_share=0.4)
    return mage('lotus', 'epic', R,
                hat=dict(brim=dict(R=1.0, y0=0.24, droop=0.0, wave=0.04, waves=8, mat='band'),
                         crown=dict(y0=0.3, h=0.7, r0=0.7, r1=0.3, bend=(0.0, 0.06), pinch=0.03, mat='crown'),
                         tip=([(0.0, 0.98, 0.06), (0.04, 1.26, 0.12), (0.16, 1.5, 0.26), (0.32, 1.58, 0.48)], 0.3, 0.05, 0.8),
                         band=(0.28, 0.4, 'band'), pre=petals, deco=glow_center),
                mantle=dict(front=0.64, back=0.68, side=0.34, scallop=0.08, scallops=8, mat='mantle', trim='petal',
                            collar=dict(h=0.32, ri=0.38, ro=0.6, open_front=0.22, flare=0.14, mat='petal'),
                            clasp=dict(y=0.48, mat='band', w=3, glow=WATER)),
                cape=dict(y_top=0.76, y_bot=-1.9, segs=4, w_top=0.94, w_bot=1.14, z0=0.68, fold=0.07, folds=8, hem='point', hem_depth=0.34, mat='cape', trim='petal',
                          deco=lambda cl, R: runes(cl, WATER, lambda x, y, z: abs((x * 2.5) % 0.9 - 0.45) < 0.06 and y < -0.4, density=0.6, seed=33, normals=((0, 0, 1),))),
                belt=dict(y0=-0.12, y1=0.1, mat='band', tails=[(0.4, 0.42, 0.14, 'petal'), (0.58, 0.32, 0.12, 'mantle')]),
                eyes=WATER)


def gardener_mage():
    R = ramps(crown=['#8E8A80', '#B4B0A4', '#D6D2C6', '#F2EFE6'], brim=['#86827A', '#ACA89C', '#CECAC0', '#EEEAE0'],
              band=COMMON['gold'], rose=['#5E1426', '#8C2038', '#B83050', '#E0526E'], leaf=['#1C3A26', '#2A5634', '#3C7444', '#56945A'],
              mantle=['#86827A', '#ACA89C', '#CECAC0', '#EEEAE0'], cape=['#16302A', '#22463E', '#305E54', '#42786C'])
    def wreath(h):
        for a in range(10):
            th = a / 10 * 2 * math.pi
            x, z = 0.78 * math.cos(th), 0.78 * math.sin(th)
            h.fill((x - 0.14, 0.36, z - 0.14), (x + 0.14, 0.62, z + 0.14), lambda xx, y, zz, x=x, z=z: (xx - x) ** 2 + (y - 0.48) ** 2 + (zz - z) ** 2 <= 0.12 ** 2,
                   'rose' if a % 2 == 0 else 'leaf')
        h.fill((-0.2, 1.3, -0.2), (0.2, 1.6, 0.2), lambda x, y, z: x * x + (y - 1.44) ** 2 + z * z <= 0.13 ** 2, ROSE)
    return mage('gardener_mage', 'legendary', R,
                hat=dict(brim=dict(R=1.16, y0=0.32, droop=0.06, wave=0.02, waves=6, mat='brim'),
                         crown=dict(y0=0.32, h=1.0, r0=0.72, r1=0.24, bend=(0.0, -0.02), w0=5, pinch=0.02, mat='crown'),
                         tip=None, band=(0.3, 0.46, 'band'), pre=wreath,
                         deco=lambda h, R: (runes(h, WATER, lambda x, y, z: 0.8 < y < 1.0, density=0.5, seed=41),
                                           rim(h, R['band'][2], lambda x, y, z: math.hypot(x, z) > 1.02 and y < 0.42))),
                mantle=dict(front=0.72, back=0.72, side=0.36, vpoint=0.14, scallop=0.04, scallops=8, mat='mantle', trim='band',
                            collar=dict(h=0.42, ri=0.38, ro=0.6, open_front=0.24, flare=0.2, mat='leaf'),
                            clasp=dict(y=0.46, mat='band', w=3, glow=ROSE),
                            deco=lambda m, R: P.vines(m, R['leaf'][2], lambda x, y, z: y < 0.6, seed=42, density=0.35, leaf=R['rose'][2])),
                cape=dict(y_top=0.78, y_bot=-2.25, segs=4, w_top=0.96, w_bot=1.22, z0=0.7, fold=0.07, folds=7, hem='point', hem_depth=0.4, mat='cape', trim='band',
                          deco=lambda cl, R: (P.vines(cl, R['leaf'][3], lambda x, y, z: y < -0.3, seed=43, density=0.5, leaf=R['rose'][2]),
                                              runes(cl, WATER, lambda x, y, z: abs(x) < 0.1 and -1.6 < y < 0.4, density=0.7, seed=44, normals=((0, 0, 1),)))),
                belt=dict(y0=-0.14, y1=0.1, mat='rose', tails=[(-0.42, 0.44, 0.16, 'leaf'), (-0.24, 0.36, 0.12, 'band')]),
                eyes=WATER)


# ---------- этаж 3
def tracker():
    R = ramps(crown=['#3E2418', '#5A3624', '#784A32', '#966244'], brim=['#3A2216', '#563220', '#74462E', '#905C40'],
              band=FUR, mantle=['#2E2016', '#4A3424', '#6A4C34', '#8E6C4C'], feather=['#5E5246', '#867868', '#AEA08C', '#D2C6B0'],
              cape=['#3A1E18', '#562C22', '#743E30', '#925444'])
    return mage('tracker', 'common', R,
                hat=dict(brim=dict(R=1.08, y0=0.3, droop=0.16, wave=0.06, waves=4, phase=1.0, mat='brim'),
                         crown=dict(y0=0.3, h=0.46, r0=0.7, r1=0.5, bend=(0.04, 0.06), mat='crown'),
                         tip=([(0.04, 0.72, 0.06), (0.06, 0.9, 0.1), (0.14, 1.0, 0.2), (0.24, 0.98, 0.32)], 0.5, 0.2),
                         band=(0.28, 0.4, 'band'),
                         pre=lambda h: M.tip(h, [(-0.7, 0.36, 0.1), (-0.82, 0.66, 0.22), (-0.9, 0.96, 0.38), (-0.94, 1.2, 0.56)], 0.08, 0.03, mat='feather')),
                mantle=dict(front=0.56, back=0.6, side=0.3, mat='mantle', trim='band', collar=dict(h=0.2, ri=0.38, ro=0.7, open_front=0.0, flare=0.08, mat='band')),
                cape=dict(y_top=0.7, y_bot=-0.7, segs=2, w_top=0.84, w_bot=0.94, z0=0.68, fold=0.05, folds=6, hem='round', mat='cape', trim='band'),
                belt=dict(y0=-0.1, y1=0.08, mat='leather', pre=lambda b: M.pouch(b, -1.12, -0.12, 0.05, mat='leather', button='brass')))


def moon_call():
    R = ramps(crown=HUNT_RED, brim=['#36181A', '#56261E', '#7E3428', '#A04838'], band=COMMON['silver'],
              mantle=['#2A1416', '#42201E', '#5E2C28', '#7E3C34'], cape=['#2A1416', '#42201E', '#5E2C28', '#7E3C34'])
    def crescent(h):
        h.fill((-0.3, 0.5, -0.86), (0.3, 0.98, -0.66),
               lambda x, y, z: 0.12 <= math.hypot(x, y - 0.74) <= 0.22 and x < 0.08 and z < -0.68, 'band')
    return mage('moon_call', 'rare', R,
                hat=dict(brim=dict(R=1.06, y0=0.32, droop=0.04, wave=0.02, waves=3, mat='brim'),
                         crown=dict(y0=0.32, h=0.9, r0=0.7, r1=0.17, bend=(0.0, 0.08), mat='crown'),
                         tip=([(0.0, 1.2, 0.08), (0.0, 1.42, 0.14), (0.06, 1.56, 0.26), (0.14, 1.62, 0.42)], 0.17, 0.05),
                         band=(0.3, 0.44, 'band'), pre=crescent,
                         deco=lambda h, R: stars(h, R, R['band'][3], n=8, seed=51, region=lambda x, y, z: y > 0.5, glow=AMBER, glow_share=0.3)),
                mantle=dict(front=0.5, back=0.56, side=0.28, scallop=0.05, scallops=5, mat='mantle', trim='band',
                            collar=dict(h=0.26, ri=0.38, ro=0.66, open_front=0.0, flare=0.08, mat='band')),
                cape=dict(y_top=0.74, y_bot=-1.1, segs=3, w_top=0.84, w_bot=0.96, z0=0.66, fold=0.05, folds=6, hem='swallow', hem_depth=0.3, mat='cape', trim='band',
                          deco=lambda cl, R: stars(cl, R, R['band'][3], n=12, seed=52, glow=AMBER, glow_share=0.3)),
                belt=dict(y0=-0.12, y1=0.08, mat='leather'))


def ghost_pack():
    R = ramps(crown=['#22262E', '#343A46', '#4A5262', '#646E82'], brim=['#1E2228', '#2E343E', '#424A58', '#5A6474'],
              band=['#16181E', '#22262E', '#343A46', '#4A5262'], mantle=['#1A1C22', '#2A2E36', '#3C424E', '#545C6A'],
              fur=['#3A3E48', '#545A66', '#727A88', '#949CAA'], cape=['#16181E', '#22262E', '#343A46', '#4A5262'],
              bone=BONE)
    def wolf(h):
        # волчья голова-капюшон: уши и морда над полями, клыки
        for sx in (1, -1):
            M.tip(h, [(sx * 0.42, 0.7, 0.0), (sx * 0.46, 0.88, 0.0), (sx * 0.5, 1.02, -0.02), (sx * 0.52, 1.14, -0.04)], 0.14, 0.04, mat='fur')
        h.fill((-0.3, 0.42, -1.1), (0.3, 0.74, -0.6), lambda x, y, z: (x / 0.26) ** 2 + ((y - 0.58) / 0.15) ** 2 <= 1 and z < -0.64, 'fur')
        for x0 in (-0.18, 0.18):
            h.fill((x0 - 0.05, 0.3, -1.0), (x0 + 0.05, 0.44, -0.88), lambda x, y, z: True, 'bone')
    return mage('ghost_pack', 'epic', R,
                hat=dict(brim=dict(R=1.2, y0=0.28, droop=0.2, wave=0.06, waves=6, phase=0.3, ragged=0.14, rough=0.08, seed=61, mat='brim'),
                         crown=dict(y0=0.28, h=0.5, r0=0.72, r1=0.5, bend=(0.0, 0.1), mat='crown'), tip=None,
                         band=(0.26, 0.38, 'band'), pre=wolf,
                         deco=lambda h, R: runes(h, MEMORY, lambda x, y, z: y > 0.4 and (x * 3 + y * 5) % 1.0 < 0.18, density=0.6, seed=62)),
                mantle=dict(front=0.72, back=0.74, side=0.38, ragged=0.26, seed=63, vpoint=0.1, mat='mantle',
                            collar=dict(h=0.34, ri=0.38, ro=0.7, open_front=0.2, flare=0.16, mat='fur'),
                            clasp=dict(y=0.48, mat='bone', w=2, glow=MEMORY)),
                cape=dict(y_top=0.78, y_bot=-2.2, segs=4, w_top=0.96, w_bot=1.2, z0=0.7, fold=0.08, folds=8, hem='tattered', hem_depth=0.5,
                          ragged=0.35, seed=64, mat='cape',
                          deco=lambda cl, R: runes(cl, MEMORY, lambda x, y, z: y < -1.2 and abs((x * 2.3) % 0.9 - 0.45) < 0.07, density=0.6, seed=65, normals=((0, 0, 1),))),
                belt=dict(y0=-0.1, y1=0.08, mat='band', tails=[(0.36, 0.5, 0.16, 'fur'), (0.56, 0.38, 0.12, 'mantle')]))


def huntmaster():
    R = ramps(crown=HUNT_RED, brim=['#36181A', '#56261E', '#7E3428', '#A04838'], band=HUNT_GOLD, bone=BONE,
              mantle=FUR_W, cape=['#3B1414', '#5E1E1C', '#862C26', '#A84236'])
    def antlers(h):
        for sx in (1, -1):
            M.tip(h, [(sx * 0.5, 0.7, 0.05), (sx * 0.8, 1.0, 0.1), (sx * 0.95, 1.35, 0.15), (sx * 0.9, 1.7, 0.2)], 0.09, 0.04, mat='bone')
            M.tip(h, [(sx * 0.82, 1.08, 0.12), (sx * 1.05, 1.15, 0.05), (sx * 1.18, 1.3, 0.0), (sx * 1.22, 1.45, -0.02)], 0.05, 0.03, mat='bone')
        h.fill((-0.16, 1.3, -0.16), (0.16, 1.58, 0.16), lambda x, y, z: x * x + (y - 1.44) ** 2 + z * z <= 0.12 ** 2, AMBER)
    return mage('huntmaster', 'legendary', R,
                hat=dict(brim=dict(R=1.16, y0=0.32, droop=0.06, wave=0.02, waves=6, mat='brim'),
                         crown=dict(y0=0.32, h=0.96, r0=0.72, r1=0.24, w0=5, pinch=0.02, mat='crown'), tip=None,
                         band=(0.3, 0.48, 'band'), pre=antlers,
                         deco=lambda h, R: (runes(h, AMBER, lambda x, y, z: 0.33 < y < 0.45, density=0.5, seed=71),
                                           rim(h, R['band'][2], lambda x, y, z: math.hypot(x, z) > 1.02 and y < 0.42))),
                mantle=dict(front=0.72, back=0.72, side=0.36, vpoint=0.14, scallop=0.04, scallops=8, mat='mantle', trim='band',
                            collar=dict(h=0.44, ri=0.38, ro=0.66, open_front=0.24, flare=0.2, mat='mantle'),
                            clasp=dict(y=0.46, mat='band', w=3, glow=AMBER)),
                cape=dict(y_top=0.78, y_bot=-2.25, segs=4, w_top=0.96, w_bot=1.22, z0=0.7, fold=0.07, folds=7, hem='point', hem_depth=0.4, mat='cape', trim='band',
                          deco=lambda cl, R: runes(cl, AMBER, lambda x, y, z: abs(x) < 0.1 and -1.6 < y < 0.4, density=0.7, seed=72, normals=((0, 0, 1),))),
                belt=dict(y0=-0.14, y1=0.1, mat='crimson' if False else 'band', tails=[(-0.42, 0.44, 0.16, 'crown'), (-0.24, 0.36, 0.12, 'band')]),
                eyes=AMBER)


# ---------- этаж 4
def stoker():
    R = ramps(crown=SOOT, brim=['#161414', '#242020', '#363030', '#4A4242'], band=COMMON['brass'],
              mantle=['#241C18', '#382A22', '#4E3C30', '#6A5242'], cape=['#1E1A1A', '#2E2828', '#423A3A', '#584E4E'],
              lens=['#1E3A3A', '#2E5A5A', '#3E7A7A', '#5EA0A0'])
    def goggles(h):
        for sx in (1, -1):
            h.fill((sx * 0.3 - 0.16, 0.34, -0.9), (sx * 0.3 + 0.16, 0.6, -0.7),
                   lambda x, y, z, sx=sx: ((x - sx * 0.3) / 0.15) ** 2 + ((y - 0.47) / 0.12) ** 2 <= 1, 'band')
            h.fill((sx * 0.3 - 0.09, 0.4, -0.94), (sx * 0.3 + 0.09, 0.54, -0.86),
                   lambda x, y, z, sx=sx: ((x - sx * 0.3) / 0.08) ** 2 + ((y - 0.47) / 0.06) ** 2 <= 1, 'lens')
    return mage('stoker', 'common', R,
                hat=dict(brim=dict(R=1.04, y0=0.3, droop=0.1, wave=0.04, waves=5, mat='brim'),
                         crown=dict(y0=0.3, h=0.5, r0=0.72, r1=0.5, bend=(0.0, 0.06), mat='crown'),
                         tip=([(0.0, 0.78, 0.06), (0.04, 1.0, 0.1), (0.14, 1.12, 0.24), (0.26, 1.06, 0.42)], 0.5, 0.12),
                         pre=goggles,
                         deco=lambda h, R: P.cracks(h, EMBER, lambda x, y, z: y > 0.6, seed=81, density=0.25)),
                mantle=dict(front=0.56, back=0.6, side=0.3, mat='mantle', trim='band', clasp=dict(y=0.5, mat='band', w=2)),
                cape=dict(y_top=0.7, y_bot=-0.6, segs=2, w_top=0.84, w_bot=0.94, z0=0.68, fold=0.05, folds=6, hem='round', mat='cape', trim='band'),
                belt=dict(y0=-0.08, y1=0.1, mat='leather', pre=lambda b: M.pouch(b, 1.12, -0.12, 0.05, mat='leather', button='brass')))


def bellows():
    R = ramps(crown=['#2A2228', '#3E333C', '#584A56', '#766674'], brim=['#261E24', '#3A2E38', '#524450', '#6E5E6C'],
              band=BRONZE, mantle=['#2A2228', '#3E333C', '#584A56', '#766674'], cape=['#221C20', '#342A30', '#4A3E46', '#62545E'])
    def pleats(h):
        h.recolor(lambda x, y, z, m: 'crown@-0.6' if m == 'crown' and round(y / V) % 3 == 0 else None)
    return mage('bellows', 'rare', R,
                hat=dict(brim=dict(R=1.06, y0=0.32, droop=0.04, wave=0.02, waves=3, mat='brim'),
                         crown=dict(y0=0.32, h=0.9, r0=0.7, r1=0.2, w0=4.0, mat='crown'),
                         tip=([(0.0, 1.2, 0.0), (0.0, 1.36, 0.0), (0.0, 1.46, 0.02), (0.0, 1.54, 0.04)], 0.2, 0.08),
                         band=(0.3, 0.44, 'band'), pre=pleats,
                         deco=lambda h, R: runes(h, EMBER, lambda x, y, z: 0.32 < y < 0.42, density=0.5, seed=91)),
                mantle=dict(front=0.5, back=0.56, side=0.28, scallop=0.05, scallops=5, mat='mantle', trim='band',
                            collar=dict(h=0.24, ri=0.38, ro=0.64, open_front=0.0, flare=0.06, mat='band')),
                cape=dict(y_top=0.74, y_bot=-1.1, segs=3, w_top=0.84, w_bot=0.96, z0=0.66, fold=0.05, folds=6, hem='swallow', hem_depth=0.3, mat='cape', trim='band',
                          deco=lambda cl, R: runes(cl, EMBER, lambda x, y, z: y < -0.7, density=0.3, seed=92, normals=((0, 0, 1),))),
                belt=dict(y0=-0.12, y1=0.08, mat='band'))


def crucible():
    R = ramps(crown=IRON, brim=['#121014', '#201C24', '#322C38', '#4A4252'], band=BRONZE, mantle=['#1E1A20', '#2E2830', '#423A46', '#5A5060'],
              cape=['#161216', '#241E24', '#342C34', '#483E48'])
    def molten(h):
        # тулья-тигель: открытый верх, внутри расплав
        h.carve(lambda x, y, z: y > 0.88 and math.hypot(x, z) < 0.3)
        h.fill((-0.32, 0.8, -0.32), (0.32, 0.9, 0.32), lambda x, y, z: math.hypot(x, z) < 0.3, MOLTEN)
    return mage('crucible', 'epic', R,
                hat=dict(brim=dict(R=1.2, y0=0.3, droop=0.1, wave=0.035, waves=4, phase=1.2, mat='brim'),
                         crown=dict(y0=0.3, h=0.62, r0=0.72, r1=0.42, w0=5.0, w1=4.0, mat='crown'), tip=None,
                         band=(0.28, 0.42, 'band'), pre=molten,
                         deco=lambda h, R: P.cracks(h, EMBER, lambda x, y, z: y > 0.4, seed=101, density=0.6)),
                mantle=dict(front=0.66, back=0.7, side=0.34, scallop=0.07, scallops=6, mat='mantle', trim='band',
                            collar=dict(h=0.36, ri=0.38, ro=0.6, open_front=0.22, flare=0.14, mat='band'),
                            clasp=dict(y=0.5, mat='band', w=3, glow=MOLTEN),
                            deco=lambda m, R: P.cracks(m, EMBER, lambda x, y, z: True, seed=102, density=0.4)),
                cape=dict(y_top=0.76, y_bot=-2.1, segs=4, w_top=0.94, w_bot=1.16, z0=0.68, fold=0.07, folds=7, hem='point', hem_depth=0.34, mat='cape', trim='band',
                          deco=lambda cl, R: runes(cl, EMBER, lambda x, y, z: y < -1.1, density=0.45, seed=103, normals=((0, 0, 1),))),
                belt=dict(y0=-0.12, y1=0.1, mat='band'),
                eyes=MOLTEN)


def founder():
    R = ramps(crown=BRONZE, brim=['#4A2A12', '#7A4A1E', '#A8702E', '#D49A48'], band=['#7A5418', '#B07C24', '#E0A83C', '#FFD27A'],
              mantle=IRON, cape=['#161214', '#241E20', '#342C2E', '#483E40'])
    def core(h):
        h.fill((-0.22, 1.24, -0.22), (0.22, 1.6, 0.22), lambda x, y, z: x * x + (y - 1.42) ** 2 + z * z <= 0.15 ** 2 * 1.3, MOLTEN)
        h.fill((-0.3, 1.18, -0.3), (0.3, 1.3, 0.3), lambda x, y, z: abs(x) + abs(z) < 0.26, 'band')
    return mage('founder', 'legendary', R,
                hat=dict(brim=dict(R=1.16, y0=0.32, droop=0.06, wave=0.02, waves=6, mat='brim'),
                         crown=dict(y0=0.32, h=0.9, r0=0.72, r1=0.26, w0=5, pinch=0.02, mat='crown'), tip=None,
                         band=(0.3, 0.48, 'band'), pre=core,
                         deco=lambda h, R: (runes(h, EMBER, lambda x, y, z: 0.5 < y < 1.1, density=0.35, seed=111),
                                           rim(h, R['band'][2], lambda x, y, z: math.hypot(x, z) > 1.02 and y < 0.42))),
                mantle=dict(front=0.72, back=0.72, side=0.36, vpoint=0.14, scallop=0.04, scallops=8, mat='mantle', trim='band',
                            collar=dict(h=0.44, ri=0.38, ro=0.6, open_front=0.24, flare=0.2, mat='crown'),
                            clasp=dict(y=0.46, mat='band', w=3, glow=MOLTEN),
                            deco=lambda m, R: P.cracks(m, EMBER, lambda x, y, z: True, seed=112, density=0.45)),
                cape=dict(y_top=0.78, y_bot=-2.25, segs=4, w_top=0.96, w_bot=1.22, z0=0.7, fold=0.07, folds=7, hem='point', hem_depth=0.4, mat='cape', trim='band',
                          deco=lambda cl, R: (runes(cl, EMBER, lambda x, y, z: abs(x) < 0.1 and -1.6 < y < 0.4, density=0.7, seed=113, normals=((0, 0, 1),)),
                                              runes(cl, MOLTEN, lambda x, y, z: y < -1.8, density=0.5, seed=114, normals=((0, 0, 1),)))),
                belt=dict(y0=-0.14, y1=0.1, mat='band'),
                eyes=MOLTEN)


# ---------- этаж 5
def copyist():
    R = ramps(crown=INDIGO, brim=['#121028', '#1E1A40', '#2E285E', '#423A80'], band=PAPER, mantle=['#1E1A3A', '#2C2658', '#3E3678', '#544A9A'],
              cape=['#18142E', '#241E46', '#342C64', '#463C84'], ink=['#0C0C18', '#16162A', '#22223E', '#30305A'])
    return mage('copyist', 'common', R,
                hat=dict(brim=dict(R=1.08, y0=0.3, droop=0.12, wave=0.04, waves=5, mat='brim'),
                         crown=dict(y0=0.3, h=0.5, r0=0.72, r1=0.5, bend=(0.02, 0.1), mat='crown'),
                         tip=([(0.02, 0.78, 0.1), (0.06, 1.1, 0.16), (0.26, 1.28, 0.44), (0.44, 1.08, 0.74)], 0.5, 0.08),
                         band=(0.28, 0.42, 'band'),
                         pre=lambda h: M.tip(h, [(0.68, 0.36, 0.1), (0.8, 0.66, 0.2), (0.88, 0.96, 0.34), (0.92, 1.2, 0.5)], 0.07, 0.03, mat='band')),
                mantle=dict(front=0.56, back=0.6, side=0.3, mat='mantle', trim='band', clasp=dict(y=0.5, mat='band', w=2),
                            deco=lambda m, R: [m.c.__setitem__(k, R['ink'][1]) for k in list(m.c) if H(121, *k) < 0.04 and not m.c[k].startswith('!')]),
                cape=dict(y_top=0.7, y_bot=-0.6, segs=2, w_top=0.84, w_bot=0.94, z0=0.68, fold=0.05, folds=6, hem='round', mat='cape', trim='band'),
                belt=dict(y0=-0.08, y1=0.1, mat='leather',
                          pre=lambda b: b.fill((0.8, -0.2, -0.75), (1.1, 0.14, -0.45), lambda x, y, z: (x - 0.95) ** 2 + (z + 0.6) ** 2 <= 0.11 ** 2, 'ink')))


def pages():
    R = ramps(crown=PAPER, brim=['#8E8062', '#B8AA84', '#D8CCA8', '#F4ECCE'], band=INDIGO, mantle=['#2C2658', '#3E3678', '#544A9A', '#6E64BA'],
              cape=['#241E46', '#342C64', '#463C84', '#5C52A4'], ink=['#0C0C18', '#16162A', '#22223E', '#30305A'])
    def lines(h, R):
        for (i, j, k), col in list(h.c.items()):
            if col in R['crown'] and j % 2 == 0 and H(131, i, j, k) < 0.5:
                h.c[(i, j, k)] = R['ink'][2]
    return mage('pages', 'rare', R,
                hat=dict(brim=dict(R=1.06, y0=0.32, droop=0.04, wave=0.06, waves=9, mat='brim'),
                         crown=dict(y0=0.32, h=0.9, r0=0.7, r1=0.18, bend=(0.0, 0.06), mat='crown'),
                         tip=([(0.0, 1.2, 0.06), (0.0, 1.42, 0.1), (0.04, 1.56, 0.2), (0.1, 1.64, 0.34)], 0.18, 0.05),
                         band=(0.3, 0.44, 'band'), deco=lines),
                mantle=dict(front=0.5, back=0.56, side=0.28, scallop=0.06, scallops=9, mat='mantle', trim='crown',
                            collar=dict(h=0.26, ri=0.38, ro=0.64, open_front=0.0, flare=0.06, mat='crown')),
                cape=dict(y_top=0.74, y_bot=-1.2, segs=3, w_top=0.84, w_bot=0.96, z0=0.66, fold=0.05, folds=6, hem='swallow', hem_depth=0.3, mat='cape', trim='crown',
                          deco=lambda cl, R: stars(cl, R, R['crown'][3], n=10, seed=132, glow=INK_GLOW, glow_share=0.3)),
                belt=dict(y0=-0.12, y1=0.08, mat='band', pre=lambda b: M.book(b, -1.14, -0.26, 0.05, w=0.48, h=0.48, d=0.2, cover='band', pages='paper', corner='brass')))


def clockkeeper():
    R = ramps(crown=['#1C1838', '#2C265A', '#40387E', '#5A50A6'], brim=['#7A5418', '#B07C24', '#E0A83C', '#FFD27A'], band=COMMON['brass'],
              mantle=['#1C1838', '#2C265A', '#40387E', '#5A50A6'], cape=['#141030', '#201A4A', '#302868', '#443A8C'], glass=PAPER)
    def clock(h):
        h.fill((-0.3, 0.46, -0.92), (0.3, 1.0, -0.66), lambda x, y, z: math.hypot(x, y - 0.72) <= 0.24 and z < -0.68, 'glass')
        h.recolor(lambda x, y, z, m: 'band' if m == 'glass' and (math.hypot(x, y - 0.72) > 0.18 or (abs(x) < 0.04 and y > 0.72) or (abs(y - 0.72) < 0.04 and x > 0)) else None)
    return mage('clockkeeper', 'epic', R,
                hat=dict(brim=dict(R=1.2, y0=0.3, droop=0.1, wave=0.035, waves=12, phase=0.2, mat='brim'),
                         crown=dict(y0=0.3, h=0.68, r0=0.72, r1=0.32, bend=(0.04, 0.14), pinch=0.03, mat='crown'),
                         tip=([(0.04, 0.96, 0.14), (0.06, 1.3, 0.2), (0.22, 1.6, 0.4), (0.48, 1.66, 0.7)], 0.32, 0.05, 0.8),
                         band=(0.28, 0.42, 'band'), pre=clock,
                         deco=lambda h, R: stars(h, R, R['band'][3], n=8, seed=141, region=lambda x, y, z: y > 0.9, glow=INK_GLOW, glow_share=0.5)),
                mantle=dict(front=0.66, back=0.7, side=0.34, scallop=0.07, scallops=6, mat='mantle', trim='band',
                            collar=dict(h=0.38, ri=0.38, ro=0.6, open_front=0.22, flare=0.14, mat='brim'),
                            clasp=dict(y=0.5, mat='band', w=3, glow=INK_GLOW)),
                cape=dict(y_top=0.76, y_bot=-2.1, segs=4, w_top=0.94, w_bot=1.16, z0=0.68, fold=0.07, folds=7, hem='point', hem_depth=0.34, mat='cape', trim='band',
                          deco=lambda cl, R: stars(cl, R, R['band'][3], n=16, seed=142, region=lambda x, y, z: y < 0.3, glow=INK_GLOW, glow_share=0.4)),
                belt=dict(y0=-0.12, y1=0.1, mat='band',
                          pre=lambda b: b.fill((0.9, -0.6, -0.2), (1.3, -0.1, 0.2), lambda x, y, z: (abs(y + 0.35) < 0.22 - 0.5 * abs(x - 1.1) * 0) and abs(x - 1.1) < 0.14 - 0.4 * (0.22 - abs(y + 0.35)) * 0 and abs(z) < 0.14, 'glass')),
                eyes=INK_GLOW)


def memory_scribe():
    R = ramps(crown=['#8A84AE', '#ACA6CC', '#CEC8E6', '#ECE8FA'], brim=['#827CA6', '#A49EC4', '#C6C0E0', '#E6E2F6'], band=COMMON['gold'],
              mantle=['#8A84AE', '#ACA6CC', '#CEC8E6', '#ECE8FA'], ink=INDIGO, cape=['#141030', '#201A4A', '#302868', '#443A8C'])
    def gem(h):
        h.fill((-0.2, 1.62, -0.2), (0.2, 1.98, 0.2), lambda x, y, z: x * x + (y - 1.8) ** 2 + z * z <= 0.14 ** 2 * 1.3, MEMORY)
        h.fill((-0.3, 1.54, -0.3), (0.3, 1.66, 0.3), lambda x, y, z: abs(x) + abs(z) < 0.26, 'band')
    return mage('memory_scribe', 'legendary', R,
                hat=dict(brim=dict(R=1.16, y0=0.32, droop=0.06, wave=0.02, waves=6, mat='brim'),
                         crown=dict(y0=0.32, h=1.08, r0=0.72, r1=0.24, bend=(0.0, -0.02), w0=5, pinch=0.02, mat='crown'),
                         tip=([(0.0, 1.36, -0.02), (0.0, 1.46, -0.02), (0.0, 1.54, 0.0), (0.0, 1.6, 0.02)], 0.2, 0.12), band=(0.3, 0.48, 'band'), pre=gem,
                         deco=lambda h, R: (runes(h, INK_GLOW, lambda x, y, z: 0.6 < y < 1.3, density=0.45, seed=151),
                                           rim(h, R['band'][2], lambda x, y, z: math.hypot(x, z) > 1.02 and y < 0.42))),
                mantle=dict(front=0.72, back=0.72, side=0.36, vpoint=0.14, scallop=0.04, scallops=8, mat='mantle', trim='band',
                            collar=dict(h=0.44, ri=0.38, ro=0.6, open_front=0.24, flare=0.2, mat='ink'),
                            clasp=dict(y=0.46, mat='band', w=3, glow=MEMORY)),
                cape=dict(y_top=0.78, y_bot=-2.25, segs=4, w_top=0.96, w_bot=1.22, z0=0.7, fold=0.07, folds=7, hem='point', hem_depth=0.4, mat='cape', trim='band',
                          deco=lambda cl, R: [cl.c.__setitem__(k, INK_GLOW) for k in list(cl.c) if (k[0], k[1], k[2] + 1) not in cl.c
                                              and k[1] % 3 == 0 and -1.8 < cen(k[1]) < 0.3 and abs(cen(k[0])) < 0.85 and H(152, k[0] // 2, k[1]) < 0.6]),
                belt=dict(y0=-0.14, y1=0.1, mat='ink', tails=[(-0.42, 0.44, 0.16, 'ink'), (-0.24, 0.36, 0.12, 'band')],
                          pre=lambda b: M.book(b, 1.18, -0.36, 0.0, w=0.48, h=0.56, d=0.22, cover='ink', pages='paper', corner='band', gem=MEMORY)),
                eyes=MEMORY)


FLOORS = {
    2: [gardener, sluice_guard, thorn_knight, rose_warden, herbalist, dew, lotus, gardener_mage],
    3: [kennelman, huntsman, bear_hunter, royal_hunt, tracker, moon_call, ghost_pack, huntmaster],
    4: [apprentice_smith, caster, scale_knight, elder_founder, stoker, bellows, crucible, founder],
    5: [scribe, binder, seal_keeper, chief_chronicler, copyist, pages, clockkeeper, memory_scribe],
}


def build_floor(floor, only=None):
    out = []
    for fn in FLOORS.get(floor, []):
        if only and fn.__name__ not in only:
            continue
        out.append(fn())
    return out
