# Монохромные пиксельные маски древа v2 (мрачный стиль, одно цвет — тон задаёт игра).
# Буквы: x — основной материал (автотон: верх/лево светлее, низ/право темнее),
#        z — тёмный материал (тот же автотон, ниже на ступень), o — блик, m — средний,
#        d — тень, # — цвет контура внутри рисунка (прорези, трещины), . — пусто.
# Контур дорисовывается автоматически (mono.render).
#
# GLYPHS — малые узлы (рисунок ≤ 5×5, кусок 7×7), ICONS — новые иконки узлов
# (≤ 14×14, кусок 16×16), CLASS — предмет класса для корня древа (кусок 16×16).
# Остальные иконки узлов — силуэты v1 из icons.py (перекрашиваются в монохром).
GLYPHS, ICONS, CLASS = {}, {}, {}

def _add(table, name, art):
    rows = [r.strip() for r in art.strip('\n').split('\n')]
    w = max(len(r) for r in rows)
    table[name] = [r.ljust(w, '.') for r in rows]

def glyph(name, art): _add(GLYPHS, name, art)
def icon(name, art): _add(ICONS, name, art)
def cls(name, art): _add(CLASS, name, art)

# ===================== глифы малых узлов (5 × 5) =====================
glyph('g_heart', '''
xx.xx
xxxxx
xxxxx
.xxx.
..x..
''')
glyph('g_plate', '''
xxxxx
xxoxx
xxxxx
.xxx.
..x..
''')
glyph('g_cross', '''
.xxx.
xxxxx
xxxxx
.xxx.
''')
glyph('g_blade', '''
....x
...x.
x.x..
.x...
x.x..
''')
glyph('g_speed', '''
x.x..
.x.x.
..x.x
.x.x.
x.x..
''')
glyph('g_arc', '''
.xxx.
x...x
x....
.x...
''')
glyph('g_eye', '''
.xxx.
xx#xx
.xxx.
''')
glyph('g_counter', '''
.xxx.
x...x
x.x.x
..xx.
.xxx.
''')
glyph('g_boot', '''
.xx..
.xx..
.xx..
.xxxx
.xxxx
''')
glyph('g_drop', '''
..x..
.xxx.
xxxxx
xxxxx
.xxx.
''')
glyph('g_wave', '''
.x...
x.x.x
...x.
.x...
x.x.x
''')
glyph('g_spark', '''
..x..
.xxx.
xxoxx
.xxx.
..x..
''')
glyph('g_star', '''
x...x
.x.x.
..o..
.x.x.
x...x
''')
glyph('g_hourglass', '''
xxxxx
.xxx.
..x..
.xxx.
xxxxx
''')
glyph('g_rune', '''
x.x.x
.xxx.
..x..
..x..
..x..
''')
glyph('g_moon', '''
.xxx.
xx...
x....
xx...
.xxx.
''')

# ===================== новые иконки узлов (≤ 14 × 14) =====================
# «Насквозь»: стрела проходит сквозь двух врагов.
icon('i_pierce', '''
..zz....zz....
..zz....zz....
..zz....zz.x..
..zz....zz.xx.
xxxxxxxxxxxxxx
xxxxxxxxxxxxxx
..zz....zz.xx.
..zz....zz.x..
..zz....zz....
..zz....zz....
''')
# «Сила слова»: камень с горящей руной.
icon('i_rune', '''
...zzzzzz...
..zzzzzzzz..
.zzzozzozzz.
.zzzozozzzz.
.zzzoozzzzz.
.zzzozozzzz.
.zzzozzozzz.
.zzzozzzzzz.
.zzzozzzzzz.
..zzzzzzzz..
...zzzzzz...
''')
# «Расщепление»: снаряд раскалывается на три осколка.
icon('k_shatter', '''
...........x..
..........xxx.
.......z...x..
.....z........
.xxxx.........
xxoxxx..z..x..
xox#xxz...xxx.
xxx#xx..z..x..
.xxxx.........
.....z........
.......z...x..
..........xxx.
...........x..
''')

# ===================== предметы классов (корень древа) =====================
cls('cls_helm', '''
...xxxxxx...
..xxxxxxxx..
.xxxxooxxxx.
.xxxxooxxxx.
.x####o###x.
.xxxxooxxxx.
.xxzxooxzxx.
.xxxxooxxxx.
.xxxxxxxxxx.
..xxxxxxxx..
''')
cls('cls_hat', '''
.........xx.
........xxx.
.......xxx..
......xxxx..
.....xxxxx..
.....xxxxxx.
....xxxxxxx.
....zzzzzzz.
...xxxxxxxxx
xxxxxxxxxxxxx
.xxxxxxxxxxx.
''')
cls('cls_dagger', '''
.....x.....
....xox....
....xox....
....xox....
....xox....
....xox....
....xox....
.zzzzzzzzz.
.....z.....
.....z.....
....zzz....
''')
