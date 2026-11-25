# Генератор Anim/*Moves.lua: фирменные атаки боссов и сцены появления.
import os
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "src", "ReplicatedStorage", "Shared", "Anim")
ORDER = ["UT","HD","RUA","RLA","RH","LUA","LLA","LH","RUL","RLL","RF","LUL","LLL","LF","LT","LTp"]

def V(x=0, y=0, z=0):
    return (x, y, z)

def norm(v):
    if isinstance(v, (int, float)):
        return (v, 0, 0)
    v = tuple(v) + (0,) * (3 - len(v))
    return v

def P(base, **kw):
    pose = {k: norm(v) for k, v in base.items()}
    for k, v in kw.items():
        pose[k] = norm(v)
    return pose

def mix(a, b, f):
    out = {}
    for k in set(a) | set(b):
        va = a.get(k, (0, 0, 0)); vb = b.get(k, (0, 0, 0))
        out[k] = tuple(va[i] + (vb[i] - va[i]) * f for i in range(3))
    return out

def fmt(x):
    x = round(x, 3)
    if abs(x - round(x)) < 1e-9:
        return str(int(round(x)))
    return ("%.3f" % x).rstrip("0").rstrip(".")

def key(t, e, pose=None, from_pose=False):
    return {"t": t, "e": e, "pose": pose, "from": from_pose}

def anim(keys, markers=(), loop=False, priority="Action", note=None):
    return {"keys": keys, "markers": list(markers), "loop": loop, "priority": priority, "note": note}

def emit_key(k):
    parts = ["t = %s" % fmt(k["t"]), 'e = "%s"' % k["e"]]
    if k["from"]:
        parts.append('from = "pose"')
    pose = k["pose"] or {}
    for code in ORDER:
        v = pose.get(code)
        v = norm(v) if v is not None else None
        if v and any(abs(c) > 1e-9 for c in v):
            parts.append("%s = {%s}" % (code, ",".join(fmt(c) for c in v)))
    return "\t\t{ " + ", ".join(parts) + " },"

def emit(name, header, anims):
    lines = ["--!nonstrict", "-- Anim/%s — СГЕНЕРИРОВАНО tools/bosses/gen_anims.py, правьте генератор." % name]
    lines += ["-- " + h for h in header]
    lines.append("-- Конвенции как в ТЗ (раздел 3.1): клинок = RUA.x + RLA.x + RH.x; поля")
    lines.append("-- суставов, которых нет в ключе, — поза покоя (0).")
    lines.append("")
    lines.append("return {")
    for aname, a in anims:
        keys = a["keys"]
        length = keys[-1]["t"]
        for m in a["markers"]:
            assert 0 <= m[0] <= length + 1e-9, (name, aname, m)
        for i in range(1, len(keys)):
            assert keys[i]["t"] > keys[i-1]["t"], (name, aname, i)
        assert keys[0]["t"] == 0, (name, aname)
        if a["loop"]:
            assert not keys[0]["from"], (name, aname, "loop from pose")
        if a["note"]:
            lines.append("\t-- " + a["note"])
        lines.append("\t%s = { length = %s, loop = %s, priority = \"%s\", keys = {" % (aname, fmt(length), "true" if a["loop"] else "false", a["priority"]))
        for k in keys:
            lines.append(emit_key(k))
        if a["markers"]:
            ms = ", ".join('{ t = %s, name = "%s" }' % (fmt(t), n) for t, n in sorted(a["markers"]))
            lines.append("\t}, markers = { %s } }," % ms)
        else:
            lines.append("\t} },")
    lines.append("}")
    path = os.path.join(OUT, name + ".lua")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    return path, len(anims)

def loop_of(a, b, period, e="sine"):
    # Цикл: a → b → a.
    return [key(0, "linear", a), key(period / 2, e, b), key(period, e, a)]

def recover(rest, mid, length, midAt=0.45):
    return [key(0, "linear", None, True), key(length * midAt, "quadOut", mid), key(length, "sine", rest)]

results = []

# ============ Привратник (этаж 1: ворота, ключи, цепи) ============
G = {"UT": -6, "HD": -5, "RUA": (50,35,0), "RLA": 20, "RH": -160, "LUA": (50,-35,0), "LLA": 20, "LH": -160,
     "RUL": (0,0,6), "LUL": (0,0,-6)}
G_KNEEL = {"LTp": (0,-1.6,0), "UT": -50, "HD": -40, "RUL": 90, "LUL": 90, "RLL": -110, "LLL": -110,
           "RUA": (60,30,0), "RLA": 30, "RH": -180, "LUA": (60,-30,0), "LLA": 30, "LH": -180}
G_ROAR = P(G, UT=15, HD=25, RUA=(120,0,60), RLA=20, RH=-60, LUA=(120,0,-60), LLA=20, LH=-60)
g_over = P(G, UT=12, HD=15, LTp=(0,0.15,0), RUA=(170,0,20), RLA=20, RH=-20, LUA=(170,0,-20), LLA=20, LH=-20,
           RUL=(-6,0,6), LUL=(-6,0,-6))
g_down = P(G, UT=-35, HD=-15, LTp=(0,-0.7,-0.2), RUA=(40,0,10), RLA=10, RH=-120, LUA=(40,0,-10), LLA=10, LH=-120,
           RUL=50, RLL=-70, LUL=50, LLL=-70)
g_press = P(g_down, UT=-30, HD=-10, LTp=(0,-0.6,-0.15), RUL=45, RLL=-65, LUL=45, LLL=-65)
g_press2 = P(g_press, UT=-26, HD=-4, LTp=(0,-0.55,-0.15), RUA=(43,0,12), LUA=(43,0,-12))
# Ключ: меч над головой остриём вниз (160 + 25 − 275 = −90).
g_key_hi = P(G, UT=10, HD=10, LTp=(0,0.2,0), RUA=(160,0,10), RLA=25, RH=-275, LUA=(160,0,-10), LLA=25, LH=-275,
             RUL=(10,0,6), LUL=(-10,0,-6))
g_key_mid = P(G, UT=-4, HD=0, RUA=(120,0,12), RLA=40, RH=-250, LUA=(120,0,-12), LLA=40, LH=-250)
# Вбитый ключ: 50 + 10 − 150 = −90.
g_stab = P(G, UT=-40, HD=-20, LTp=(0,-0.8,-0.1), RUA=(50,0,10), RLA=10, RH=-150, LUA=(50,0,-10), LLA=10, LH=-150,
           RUL=60, RLL=-80, LUL=40, LLL=-60)
g_turnA = P(g_stab, UT=(-35,-14,0), HD=(-15,8,0), RUA=(55,-12,10), LUA=(45,-12,-10))
g_turnB = P(g_stab, UT=(-35,14,0), HD=(-15,-8,0), RUA=(45,12,10), LUA=(55,12,-10))
g_pull = P(G, UT=-14, HD=-8, RUA=(95,0,10), RLA=25, RH=-205, LUA=(95,0,-10), LLA=25, LH=-205, LTp=(0,-0.2,0),
           RUL=20, RLL=-25, LUL=20, LLL=-25)
gate = [
    ("GridDrop_Windup", anim([key(0, "linear", None, True),
        key(0.45, "quadOut", P(G, UT=-12, HD=-8, LTp=(0,-0.3,0), RUA=(-30,0,30), RLA=30, RH=-150, LUA=(-30,0,-30), LLA=30, LH=-150, RUL=20, RLL=-25, LUL=20, LLL=-25)),
        key(1.1, "backOut", g_over)], [(0.5, "Clank")],
        note="Решётки: руки рвут невидимые цепи вверх — с потолка срываются решётки.")),
    ("GridDrop_Strike", anim([key(0, "linear", None, True), key(0.1, "snap", g_down), key(0.35, "linear", P(g_down, UT=-36))],
        [(0.1, "Hit"), (0.1, "Step")], note="Обе руки с мечом обрушиваются в пол: 40 + 10 − 120 = −70.")),
    ("GridDrop_Channel", anim(loop_of(g_press, g_press2, 1.2), [(0.3, "Clank")], loop=True,
        note="Держит рукоять в полу, пока падают волны решёток; цепи гремят.")),
    ("GridDrop_Recover", anim(recover(G, P(G, UT=-18, HD=-10, LTp=(0,-0.35,0), RUL=25, RLL=-35, LUL=25, LLL=-35), 1.3))),
    ("KeyTurn_Windup", anim([key(0, "linear", None, True), key(0.5, "quadOut", g_key_mid), key(1.25, "sine", g_key_hi)],
        [(0.3, "Clank")], note="Меч как ключ: над головой остриём вниз (160 + 25 − 275 = −90).")),
    ("KeyTurn_Strike", anim([key(0, "linear", None, True), key(0.1, "snap", g_stab), key(0.35, "linear", P(g_stab, HD=-22))],
        [(0.1, "Hit"), (0.1, "Step")], note="Ключ вбит в «скважину» в полу (звук — hitSound bmKeyStab).")),
    ("KeyTurn_Channel", anim(loop_of(g_turnA, g_turnB, 0.8), [(0.4, "Clank")], loop=True,
        note="Проворачивает ключ; сам разворот корпуса даёт сервер (faceDir).")),
    ("KeyTurn_Recover", anim(recover(G, g_pull, 1.5, 0.35))),
]
# Сцена: ворота захлопываются, ключи падают, страж на колене поднимается,
# вбивает меч и ревёт.
g_rise1 = P(G, LTp=(0,-0.8,0), UT=-25, HD=-15, RUL=45, RLL=-60, LUL=45, LLL=-60,
            RUA=(80,20,0), RLA=35, RH=-200, LUA=(80,-20,0), LLA=35, LH=-200)
g_raise = P(g_key_hi, UT=8, HD=12)
g_plant = P(G, UT=-20, HD=-10, LTp=(0,-0.3,0), RUA=(60,0,10), RLA=10, RH=-160, LUA=(60,0,-10), LLA=10, LH=-160,
            RUL=25, RLL=-30, LUL=25, LLL=-30)
gate.append(("IntroScene", anim([
    key(0, "linear", G_KNEEL),
    key(1.7, "linear", P(G_KNEEL, HD=-42)),
    key(1.8, "quadOut", P(G_KNEEL, HD=-38, UT=-48)),
    key(3.6, "sine", P(G_KNEEL, HD=-40)),
    key(3.9, "quadOut", P(G_KNEEL, HD=-18, UT=-44)),
    key(4.8, "quadInOut", g_rise1),
    key(5.45, "quadOut", g_raise),
    key(5.9, "snap", g_plant),
    key(6.3, "quadOut", P(g_plant, UT=-12, HD=0)),
    key(6.6, "backOut", G_ROAR),
    key(7.3, "sine", P(G_ROAR, UT=12, HD=20)),
    key(8.0, "sine", G)],
    [(1.7, "Clank"), (3.6, "EyesOn"), (3.9, "Rise"), (5.9, "Plant"), (5.9, "Step"), (6.3, "Roar")],
    priority="Action4", note="Сцена появления (BossIntros.gatekeeper): колено → подъём → меч в пол → рёв.")))
results.append(emit("GatekeeperMoves", ["Фирменные атаки Привратника: «Решётки Хранилища», «Поворот ключа»."], gate))

# ============ Хранительница роз (этаж 2: сад, вода, статуя) ============
R = {"UT": -3, "HD": -6, "RUA": (12,0,12), "RLA": 24, "RH": -10, "LUA": (12,0,-12), "LLA": 24, "LH": -10,
     "RUL": (2,0,3), "LUL": (-2,0,-3)}
R_STATUE = P(R, UT=-4, HD=-18, RUA=(55,0,-28), RLA=105, LUA=(55,0,28), LLA=105, RH=0, LH=0)
R_WAKE = P(R, UT=18, HD=28, RUA=(60,0,70), LUA=(60,0,-70), RLA=15, LLA=15)
R_BLOOM = P(R, UT=10, HD=20, LTp=(0,0.3,0), RUA=(170,0,28), RLA=10, LUA=(170,0,-28), LLA=10)
r_up = P(R, UT=15, HD=20, LTp=(0,0.25,0), RUA=(165,0,35), RLA=15, LUA=(165,0,-35), LLA=15)
r_cross = P(R, UT=-10, HD=-15, RUA=(80,0,-30), RLA=60, LUA=(80,0,30), LLA=60)
r_push = P(R, UT=-15, HD=-10, LTp=(0,-0.4,0), RUA=(30,0,75), RLA=10, RH=-20, LUA=(30,0,-75), LLA=10, LH=-20,
           RUL=30, RLL=-40, LUL=30, LLL=-40)
r_pushB = P(r_push, UT=-8, LTp=(0,-0.3,0), RUA=(35,0,62), RLA=20, LUA=(35,0,-62), LLA=20)
r_veil = P(R, UT=-10, HD=-15, RUA=(120,0,-40), RLA=110, LUA=(120,0,40), LLA=110)
r_stare = P(R, UT=14, HD=5, RUA=(70,0,80), RLA=15, LUA=(70,0,-80), LLA=15, RH=-30, LH=-30)
r_stareB = P(r_stare, UT=10, HD=8, LTp=(0,0.15,0), RUA=(66,0,84), LUA=(66,0,-84))
rose = [
    ("Flood_Windup", anim([key(0, "linear", None, True), key(0.5, "quadOut", r_cross), key(1.15, "backOut", r_up)],
        note="Половодье: руки скрещены, затем вскинуты — вода собирается над ней.")),
    ("Flood_Strike", anim([key(0, "linear", None, True), key(0.12, "snap", r_push), key(0.35, "linear", P(r_push, UT=-16))],
        [(0.12, "Hit")], note="Руки вниз и в стороны — кольцевая волна уходит от неё.")),
    ("Flood_Channel", anim(loop_of(r_push, r_pushB, 1.0), loop=True, note="Ладони давят воду вниз, пока идут волны.")),
    ("Flood_Recover", anim(recover(R, P(R, UT=-8, HD=-10, RUA=(20,0,30), LUA=(20,0,-30)), 1.1))),
    ("Gaze_Windup", anim([key(0, "linear", None, True), key(0.4, "quadOut", r_veil), key(1.0, "sine", P(r_veil, HD=-18, UT=-12)),
        key(1.5, "sine", P(r_veil, HD=-22, UT=-14, LTp=(0,-0.15,0)))],
        note="Мраморный взгляд: ладони закрывают лицо (подсказка — отвернись).")),
    ("Gaze_Strike", anim([key(0, "linear", None, True), key(0.1, "snap", r_stare), key(0.35, "linear", P(r_stare, UT=15))],
        [(0.1, "Hit")], note="Руки распахнуты — глаза вспыхивают (звук — hitSound bmGazeFlash).")),
    ("Gaze_Channel", anim(loop_of(r_stare, r_stareB, 1.2), loop=True, note="Держит взгляд; лёгкое парение.")),
    ("Gaze_Pulse", anim([key(0, "linear", None, True), key(0.1, "snap", P(r_stare, UT=22, HD=12, RUA=(80,0,90), LUA=(80,0,-90))),
        key(0.5, "sine", r_stare)], [(0.1, "EyeOpen")], note="Повторная вспышка (играет BossMovesFx).")),
    ("Gaze_Recover", anim([key(0, "linear", None, True), key(0.5, "quadOut", P(R, HD=(-10,-20,0), UT=-8, RUA=(30,0,40), LUA=(30,0,-40))),
        key(1.3, "sine", R)])),
]
rose.append(("IntroScene", anim([
    key(0, "linear", R_STATUE),
    key(1.9, "linear", R_STATUE),
    key(3.7, "linear", P(R_STATUE, HD=-17)),
    key(3.75, "snap", P(R_STATUE, UT=-2, HD=-15, LTp=(0,0.05,0))),
    key(4.0, "sine", P(R_STATUE, HD=-12)),
    key(4.2, "linear", P(R_STATUE, HD=-8, UT=0)),
    key(4.3, "snap", P(R_STATUE, UT=6, HD=4, RUA=(58,0,-10), LUA=(58,0,10), RLA=80, LLA=80)),
    key(5.0, "quadOut", R_WAKE),
    key(5.8, "backOut", R_BLOOM),
    key(6.2, "quadOut", P(R, UT=20, HD=30, RUA=(110,0,60), LUA=(110,0,-60), RLA=15, LLA=15)),
    key(7.2, "sine", P(R, UT=16, HD=24, RUA=(100,0,56), LUA=(100,0,-56), RLA=18, LLA=18)),
    key(8.0, "sine", R)],
    [(1.9, "Vines"), (3.7, "StoneCrack"), (4.0, "EyesOn"), (4.2, "Wake"), (5.8, "Bloom"), (6.2, "Roar")],
    priority="Action4", note="Сцена появления: статуя в лозах трескается, оживает, сад расцветает.")))
results.append(emit("RosewardenMoves", ["Фирменные атаки Хранительницы роз: «Половодье», «Мраморный взгляд»."], rose))

# ============ Королевский ловчий (этаж 3: охота) ============
H = {"UT": -2, "HD": -3.7, "RUA": (8,0,8), "RLA": 36.3, "RH": 30, "LUA": (4,0,-10), "LLA": 14,
     "RUL": (4,0,4), "RLL": -6, "LUL": (-6,0,-4), "LLL": -4}
H_PERCH = {"UT": -16, "HD": 18, "RUA": (30,0,14), "RLA": 50, "RH": -40, "LUA": (30,0,-20), "LLA": 50,
           "RUL": (80,0,4), "RLL": -80, "LUL": (-6,0,-4), "LLL": -90, "LF": 40, "LTp": (0,-1.1,0)}
H_HORN = P(H, UT=14, HD=(-26,30,16), RUA=(30,0,20), RLA=40, RH=20, LUA=(60,50,-10), LLA=110, LTp=(0,0.05,0))
h_inhale = P(H_HORN, UT=(-8,10,0), HD=(-20,25,10), LTp=(0,-0.2,0), RUL=(15,0,4), RLL=-20)
h_point = P(H, UT=-10, HD=(2,0,0), RUA=(85,0,5), RLA=5, RH=20, LUA=(20,0,-25), LLA=40,
            RUL=(20,0,4), RLL=-25, LUL=(-14,0,-4), LLL=-8, LTp=(0,-0.15,0))
h_pointB = P(h_point, UT=-6, RUA=(80,0,10), LTp=(0,-0.1,0))
h_cock = P(H, UT=(0,30,0), HD=(0,-25,0), LUA=(170,30,-20), LLA=40, RUA=(40,0,30), RLA=30, RH=20,
           RUL=(10,0,6), LUL=(-20,0,-4), LLL=-10, LTp=(0,-0.1,0.1))
h_cockB = P(h_cock, UT=(-3,28,0), HD=(-2,-24,0), LTp=(0,-0.15,0.1))
h_throw = P(H, UT=(-15,-30,0), HD=(-5,20,0), LUA=(110,-20,-10), LLA=10, RUA=(20,0,30), RLA=30, RH=20,
            LUL=(20,0,-4), LLL=-10, RUL=(-15,0,4), RLL=-10, LTp=(0,-0.25,-0.25))
hunt = [
    ("HoundDrive_Windup", anim([key(0, "linear", None, True), key(0.5, "quadOut", P(H_HORN, UT=(5,10,0), HD=(-10,20,10))),
        key(1.2, "sine", h_inhale)], note="Травля: рог к губам, глубокий вдох.")),
    ("HoundDrive_Strike", anim([key(0, "linear", None, True), key(0.12, "backOut", P(H_HORN, UT=18)), key(0.4, "sine", P(H_HORN, UT=16))],
        [(0.12, "Hit")], note="Трубит в рог (звук — hitSound): свора срывается.")),
    ("HoundDrive_Channel", anim(loop_of(h_point, h_pointB, 1.5), loop=True, note="Указывает своре направление гона.")),
    ("HoundDrive_Recover", anim(recover(H, P(H, UT=-6, RUA=(40,0,10), RLA=20), 1.2))),
    ("HuntMark_Windup", anim([key(0, "linear", None, True),
        key(0.45, "quadOut", P(H, UT=(-5,-20,0), HD=(0,-10,0), LUA=(150,30,-30), LLA=120)),
        key(0.9, "backOut", h_cock)], note="Метка: выхватывает дротик из-за плеча и заносит его.")),
    ("HuntMark_Strike", anim([key(0, "linear", None, True), key(0.12, "quadOut", P(h_cock, RUA=(70,0,15), RLA=10, UT=(-5,32,0))),
        key(0.3, "sine", h_cock)], [(0.12, "Mark")], note="Указывает свободной рукой на жертву — появляется прицел.")),
    ("HuntMark_Channel", anim(loop_of(h_cock, h_cockB, 1.0), loop=True, note="Дротик занесён, ждёт момента броска.")),
    ("HuntMark_Throw", anim([key(0, "linear", None, True), key(0.12, "snap", h_throw), key(0.28, "linear", P(h_throw, UT=(-14,-28,0))),
        key(0.55, "quadOut", h_cock)], [(0.12, "Throw")], note="Бросок дротика (BossMovesFx играет на каждый захват метки).")),
    ("HuntMark_Recover", anim(recover(H, P(H, UT=-6, LUA=(30,0,-20), LLA=30), 1.0))),
]
h_crouch = P(H_PERCH, UT=-28, HD=10, LTp=(0,-1.4,0), RUL=(95,0,4), LUL=(10,0,-4), LLL=-100)
h_air = P(H, UT=10, HD=12, RUA=(140,0,30), RLA=30, RH=-10, LUA=(120,0,-30), LLA=30,
          RUL=(60,0,4), RLL=-90, LUL=(40,0,-4), LLL=-70)
h_land = P(H, UT=-30, HD=-34, RUA=(10,0,16), RLA=30, RH=30, LUA=(10,0,-16), LLA=30,
           RUL=(80,0,4), RLL=-80, LUL=(-6,0,-4), LLL=-90, LF=40, LTp=(0,-1.512,0))
h_rise = P(H, UT=-10, HD=-10, RUA=(8,0,8), RLA=36, RH=30, RUL=(24,0,0), RLL=-30, LTp=(0,-0.362,0))
H_ROAR = P(H, UT=12, HD=22, RUA=(84,24,40), RLA=10, RH=-94, LUA=(60,0,-60), LLA=20, LTp=(0,0.05,0))
hunt.append(("IntroScene", anim([
    key(0, "linear", H_PERCH),
    key(0.25, "quadOut", P(H_PERCH, UT=-6, HD=(-20,26,14), LUA=(60,50,-10), LLA=110)),
    key(1.6, "sine", P(H_PERCH, UT=4, HD=(-24,28,16), LUA=(60,50,-10), LLA=110)),
    key(1.8, "quadOut", P(H_PERCH, HD=12)),
    key(2.6, "sine", P(H_PERCH, UT=(-16,8,0), HD=(18,26,0))),
    key(3.4, "sine", P(H_PERCH, UT=(-16,-8,0), HD=(18,-20,0))),
    key(4.3, "sine", H_PERCH),
    key(4.6, "quadIn", h_crouch),
    key(4.75, "quadOut", h_air),
    key(5.3, "sine", P(h_air, UT=-6, RUL=(30,0,4), RLL=-40, LUL=(25,0,-4), LLL=-35)),
    key(5.38, "snap", h_land),
    key(5.6, "sine", P(h_land, UT=-34, LTp=(0,-1.55,0))),
    key(6.2, "quadOut", h_rise),
    key(6.6, "backOut", H_ROAR),
    key(7.6, "sine", P(H_ROAR, UT=8, HD=16)),
    key(8.5, "sine", H)],
    [(0.4, "Horn"), (1.8, "EyesOn"), (3.4, "Torches"), (4.6, "Leap"), (5.3, "Land"), (5.38, "Step"), (5.6, "Gather"), (6.6, "Roar")],
    priority="Action4", note="Сцена появления: на насесте трубит в рог, глаза своры, прыжок вниз, приземление, рёв.")))
results.append(emit("HuntsmanMoves", ["Фирменные атаки Королевского ловчего: «Королевская травля», «Метка ловчего»."], hunt))

# ============ Старший литейщик (этаж 4: горн, металл) ============
F = {"UT": -4, "HD": -2.3, "RUA": (14,0,10), "RLA": 38, "LUA": (6,0,-12), "LLA": 16,
     "RUL": (3,0,6), "RLL": -5, "LUL": (3,0,-6), "LLL": -5}
f_scoop = P(F, UT=(-20,25,0), HD=(-10,-10,0), LTp=(0,-0.4,0), LUA=(-30,0,-20), LLA=30, RUL=30, RLL=-40, LUL=30, LLL=-40)
f_wind = P(F, UT=(-15,40,0), HD=(0,-30,0), LTp=(0,-0.5,0), LUA=(40,0,-80), LLA=30, RUA=(30,0,30), RLA=40,
           RUL=40, RLL=-50, LUL=20, LLL=-30)
f_fling = P(F, UT=(-20,-35,0), HD=(-5,25,0), LTp=(0,-0.45,-0.3), LUA=(80,0,10), LLA=5, RUA=(20,0,30), RLA=40,
            RUL=30, RLL=-40, LUL=35, LLL=-45)
f_watch = P(F, UT=(-12,-15,0), HD=(-4,12,0), LTp=(0,-0.3,-0.1), LUA=(60,0,-5), LLA=10, RUL=20, RLL=-28, LUL=24, LLL=-30)
f_watchB = P(f_watch, UT=(-9,-13,0), LTp=(0,-0.25,-0.1))
f_wide = P(F, UT=-8, HD=-6, LTp=(0,-0.35,0), RUA=(30,0,70), RLA=30, LUA=(30,0,-70), LLA=30,
           RUL=(25,0,14), RLL=-30, LUL=(25,0,-14), LLL=-30)
f_inhale = P(F, UT=22, HD=28, LTp=(0,-0.2,0), RUA=(50,0,95), RLA=20, LUA=(50,0,-95), LLA=20,
             RUL=(20,0,14), RLL=-24, LUL=(20,0,-14), LLL=-24)
f_inhaleB = P(f_inhale, UT=26, HD=32, RUA=(55,0,100), LUA=(55,0,-100))
f_nova = P(F, UT=-38, HD=-20, LTp=(0,-0.8,0), RUA=(60,0,20), RLA=10, LUA=(60,0,-20), LLA=10,
           RUL=(55,0,14), RLL=-75, LUL=(55,0,-14), LLL=-75)
found = [
    ("Ingot_Windup", anim([key(0, "linear", None, True), key(0.5, "quadOut", f_scoop), key(1.2, "sine", f_wind)],
        note="Заготовка: клещами из-под ног, замах сбоку для броска «блинчиком».")),
    ("Ingot_Strike", anim([key(0, "linear", None, True), key(0.1, "snap", f_fling), key(0.35, "linear", P(f_fling, UT=(-21,-37,0)))],
        [(0.1, "Hit")], note="Низкий бросок сбоку: слиток скачет по полу.")),
    ("Ingot_Channel", anim(loop_of(f_watch, f_watchB, 1.2), loop=True, note="Провожает слиток взглядом.")),
    ("Ingot_Recover", anim(recover(F, P(F, UT=-8, LUA=(20,0,-20), LLA=30), 1.2))),
    ("Bellows_Windup", anim([key(0, "linear", None, True), key(0.9, "quadOut", f_wide)], note="Дыхание горна: широкая стойка.")),
    ("Bellows_Strike", anim([key(0, "linear", None, True), key(0.15, "backOut", f_inhale), key(0.35, "sine", f_inhale)],
        [(0.15, "Inhale")], note="Грудь колесом, руки в стороны — начинается вдох.")),
    ("Bellows_Channel", anim([key(0, "linear", None, True), key(0.6, "sine", f_inhaleB), key(1.2, "sine", f_inhale),
        key(1.75, "sine", P(f_inhaleB, UT=30, HD=36, LTp=(0,-0.15,0))), key(1.9, "snap", f_nova),
        key(2.4, "sine", P(f_nova, UT=-34, LTp=(0,-0.7,0)))],
        [(1.9, "Nova"), (1.9, "Step")], note="Не цикл: 1,9 с вдоха (тяга к горну), затем выдох-нова. Длина = channelTime.")),
    ("Bellows_Recover", anim(recover(F, P(F, UT=-14, HD=-8, LTp=(0,-0.3,0), RUL=20, RLL=-26, LUL=20, LLL=-26), 1.4))),
]
F_MOLD = {"LTp": (0,-1.2,0), "UT": -45, "HD": -30, "RUA": (70,0,-30), "RLA": 100, "LUA": (70,0,30), "LLA": 100,
          "RUL": 95, "RLL": -120, "LUL": 95, "LLL": -120}
f_burst = P(F, UT=20, HD=22, LTp=(0,0.3,0), RUA=(120,0,70), RLA=10, LUA=(120,0,-70), LLA=10,
            RUL=(15,0,14), RLL=-10, LUL=(15,0,-14), LLL=-10)
f_steam = P(F, UT=4, HD=6, LTp=(0,-0.1,0), RUA=(40,0,40), RLA=40, LUA=(40,0,-40), LLA=40,
            RUL=(12,0,12), RLL=-14, LUL=(12,0,-12), LLL=-14)
f_slamUp = P(F, UT=(18,-18,0), HD=10, RUA=(165,0,-10), RLA=20, LUA=(60,0,-30), LLA=30)
f_slam = P(F, UT=(-39.9,16.3,0), HD=-10, RUA=(46.7,0,0), RLA=10, LUA=(30,0,-30), LLA=30,
           RUL=48, RLL=-64, LUL=(10,0,-6), LLL=-20, LTp=(0,-0.72,-0.55))
F_ROAR = P(F, UT=18, HD=25, RUA=(100,0,50), RLA=20, LUA=(100,0,-60), LLA=20)
found.append(("IntroScene", anim([
    key(0, "linear", F_MOLD),
    key(3.4, "linear", P(F_MOLD, UT=-44)),
    key(3.45, "snap", P(F_MOLD, UT=-40, HD=-26, LTp=(0,-1.1,0))),
    key(4.15, "quadIn", P(F_MOLD, UT=-50, HD=-34, LTp=(0,-1.3,0))),
    key(4.3, "snap", f_burst),
    key(4.9, "sine", P(f_burst, UT=14, HD=14)),
    key(5.6, "sine", f_steam),
    key(6.0, "quadOut", f_slamUp),
    key(6.4, "snap", f_slam),
    key(6.7, "quadOut", P(f_slam, UT=(-20,8,0), LTp=(0,-0.4,-0.3))),
    key(7.0, "backOut", F_ROAR),
    key(7.5, "sine", P(F_ROAR, UT=14, HD=20)),
    key(8.0, "sine", F)],
    [(3.4, "MoldCrack"), (4.2, "Burst"), (4.3, "Step"), (6.4, "Slam"), (6.4, "Step"), (6.7, "Roar")],
    priority="Action4", note="Сцена появления: отливка в форме, форма лопается, раскалённый литейщик остывает, удар молотом.")))
results.append(emit("FounderMoves", ["Фирменные атаки Старшего литейщика: «Раскалённая заготовка», «Дыхание горна»."], found))

# ============ Главный летописец (этаж 5: книги, перо, чернила) ============
C = {"UT": -2, "HD": -5.5, "RUA": (24,0,8), "RLA": 50, "RH": -30, "LUA": (44,0,-16), "LLA": 46}
c_book = P(C, HD=-15, LUA=(70,0,-10), LLA=70, RUA=(100,0,20), RLA=60, RH=-40)
c_quillUp = P(C, UT=8, HD=-10, LUA=(70,0,-10), LLA=70, RUA=(150,0,30), RLA=30, RH=-60)
c_flick = P(C, UT=-10, HD=-6, LUA=(65,0,-10), LLA=70, RUA=(80,0,-20), RLA=40, RH=-20, LTp=(0,0,-0.15))
c_write = P(C, HD=-20, UT=-6, LUA=(60,0,-10), LLA=75, RUA=(75,0,-30), RLA=80, RH=-50)
c_writeB = P(c_write, RUA=(70,0,-20), RLA=90, RH=-40, HD=-18)
c_hi = P(C, UT=15, HD=20, LTp=(0,0.2,0), RUA=(175,0,15), RLA=15, RH=-20, LUA=(175,0,-15), LLA=15)
c_chest = P(C, LUA=(80,0,-5), LLA=60, RUA=(80,0,5), RLA=60, RH=-30, HD=-10)
c_throw = P(C, UT=-25, HD=-10, RUA=(70,0,10), RLA=10, RH=-20, LUA=(70,0,-10), LLA=10, LTp=(0,-0.2,-0.2))
c_lift = P(C, UT=12, HD=15, LTp=(0,0.15,0), RUA=(170,0,20), RLA=12, RH=-20, LUA=(170,0,-20), LLA=12)
c_slam = P(C, UT=-30, HD=-15, LTp=(0,-0.4,0), RUA=(40,0,10), RLA=10, RH=-20, LUA=(40,0,-10), LLA=10,
           RUL=20, RLL=-26, LUL=20, LLL=-26)
c_between = P(c_slam, UT=-14, HD=-4, LTp=(0,-0.15,0), RUA=(70,0,12), LUA=(70,0,-12))
# Каналы книги: 2·(подъём 1,25 + удержание 0,25 + удар 0,35) + пауза 0,5 + 0,3.
bs = [key(0, "linear", None, True), key(1.25, "quadOut", c_lift), key(1.5, "sine", P(c_lift, UT=14, HD=18)),
      key(1.85, "quadIn", c_slam), key(2.35, "sine", c_between), key(3.6, "quadOut", c_lift),
      key(3.85, "sine", P(c_lift, UT=14, HD=18)), key(4.2, "quadIn", c_slam), key(4.5, "sine", P(c_slam, UT=-28))]
chron = [
    ("Rewind_Windup", anim([key(0, "linear", None, True), key(0.5, "quadOut", c_book), key(1.0, "backOut", c_quillUp)],
        note="Переписать прошлое: книга у груди, перо поднято.")),
    ("Rewind_Strike", anim([key(0, "linear", None, True), key(0.1, "snap", c_flick), key(0.35, "linear", P(c_flick, UT=-11))],
        [(0.1, "Hit"), (0.1, "Quill")], note="Росчерк пером в сторону цели — начинается запись её следов.")),
    ("Rewind_Channel", anim(loop_of(c_write, c_writeB, 0.6), [(0.15, "Scribble")], loop=True, note="Строчит в книге, пока пишутся следы.")),
    ("Rewind_Recover", anim(recover(C, P(C, HD=-12, LUA=(55,0,-12), LLA=55), 1.1))),
    ("BookSlam_Windup", anim([key(0, "linear", None, True), key(0.6, "quadOut", c_chest), key(1.3, "backOut", c_hi)],
        note="Глава закрыта: книга поднята над головой обеими руками.")),
    ("BookSlam_Strike", anim([key(0, "linear", None, True), key(0.1, "snap", c_throw), key(0.35, "linear", P(c_throw, UT=-26))],
        [(0.1, "Hit")], note="Бросает книгу вперёд — она вырастает посреди арены.")),
    ("BookSlam_Channel", anim(bs, [(1.85, "Press"), (4.2, "Press")],
        note="Не цикл: дирижирует обложкой — два подъёма и два захлопывания (длина фазы I, в III растягивается).")),
    ("BookSlam_Recover", anim(recover(C, P(C, UT=-10, HD=-8, RUA=(50,0,10), LUA=(55,0,-12)), 1.4))),
]
C_FLOAT = P(C, UT=-10, HD=-30, LTp=(0,0.4,0), RUA=(10,0,14), RLA=20, RH=-20, LUA=(14,0,-16), LLA=20)
C_FLOAT_B = P(C_FLOAT, UT=-8, LTp=(0,0.55,0), HD=-28)
c_spread = P(C, UT=15, HD=12, LTp=(0,0.2,0), RUA=(100,0,70), RLA=10, RH=-30, LUA=(100,0,-70), LLA=10)
c_clap = P(C, UT=-6, HD=-8, RUA=(70,0,10), RLA=60, RH=-30, LUA=(70,0,-10), LLA=60)
C_ROAR = P(C, UT=20, HD=25, RUA=(140,0,40), RLA=20, RH=-30, LUA=(80,0,-50), LLA=30)
chron.append(("IntroScene", anim([
    key(0, "linear", C_FLOAT),
    key(1.4, "sine", C_FLOAT_B),
    key(2.8, "sine", C_FLOAT),
    key(4.1, "sine", C_FLOAT_B),
    key(5.3, "sine", C_FLOAT),
    key(5.5, "quadOut", P(C_FLOAT, HD=0, UT=-4)),
    key(6.1, "backOut", c_spread),
    key(6.4, "snap", c_clap),
    key(6.8, "quadOut", P(c_clap, LTp=(0,-0.1,0))),
    key(7.1, "backOut", C_ROAR),
    key(7.8, "sine", P(C_ROAR, UT=16, HD=20)),
    key(8.5, "sine", C)],
    [(0.2, "Vortex"), (2.0, "BookOpen"), (3.2, "Scan"), (5.4, "EyesOn"), (5.7, "Spread"), (6.4, "Slam"), (6.8, "Roar")],
    priority="Action4", note="Сцена появления: вихрь страниц, книга, строка-скан проявляет летописца, хлопок книгой, рёв.")))
results.append(emit("ChroniclerMoves", ["Фирменные атаки Главного летописца: «Переписать прошлое», «Глава закрыта»."], chron))

for path, n in results:
    print(path, n)
