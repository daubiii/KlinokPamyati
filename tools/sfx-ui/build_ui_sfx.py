"""Звуки интерфейса «дерево и пергамент» — синтез без чужих сэмплов (07.11.2026).
python3 build_ui_sfx.py <out> [звук …]   — без списка собираются все
ВАЖНО: одобренные Артёмом файлы лежат в tools/sfx-ui/ogg и главнее генератора —
их не перегенерировать (с 07.11 у каждого звука своё зерно случайности, старые
файлы собраны с общим). Переделанные звуки собирать по имени: … <out> tab page_turn.
  <out>/ogg/<имя>.ogg — для загрузки в Roblox (Creator Hub → Audio), id вписать в UiAssets.Sounds;
  <out>/mp3/<имя>.mp3 — для прослушивания на странице-палитре;
  <out>/palette.json — что озвучивает каждый звук и какие ключи игры он заменяет.

Правила палитры (жалоба Артёма: «режут уши»):
  * ничего выше ~5 кГц по энергии — все звуки через мягкий срез верхов;
  * атака не резче 2–5 мс (нет щелчка-«дзынь»);
  * тембры — дерево, бумага, кожа, глухая бронза, мягкие маримба-ноты; никаких
    электронных «пингов» и победных фанфар движка;
  * пик −6 дБ, громкость в игре — 0,25–0,45, потом общий ползунок SoundGroup «Ui».
Боевые звуки (Config/Sfx: удары, рывок, парирование, враги) не трогаются."""
import os, sys, json, subprocess
import numpy as np
from scipy import signal

SR = 44100
RNG = np.random.default_rng(7)
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out')


# ------------------------------------------------------------------ кирпичики
def t_(dur):
    return np.arange(int(dur * SR)) / SR


def pad(x, dur):
    n = int(dur * SR)
    return np.pad(x, (0, max(0, n - len(x))))[:n] if len(x) < n else x[:n]


def M(*xs):
    """Сложить звуки разной длины (короткие дополняются тишиной)."""
    n = max(len(x) for x in xs)
    return sum(np.pad(x, (0, n - len(x))) for x in xs)


def place(buf, x, at):
    i = int(at * SR)
    end = min(len(buf), i + len(x))
    buf[i:end] += x[:end - i]
    return buf


def env(dur, attack=0.003, decay=0.2, hold=0.0):
    t = t_(dur)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    a = a * a * (3 - 2 * a)  # мягкая S-атака вместо ступеньки
    d = np.where(t < attack + hold, 1.0, np.exp(-(t - attack - hold) / decay))
    return a * d


def modal(freqs, amps, decays, dur, attack=0.002, jitter=0.0):
    """Сумма затухающих синусов — дерево, бронза, маримба."""
    t = t_(dur)
    x = np.zeros_like(t)
    for f, a, d in zip(freqs, amps, decays):
        f = f * (1 + RNG.uniform(-jitter, jitter))
        x += a * np.sin(2 * np.pi * f * t + RNG.uniform(0, 2 * np.pi)) * np.exp(-t / d)
    return x * env(dur, attack, 10)


def noise(dur):
    return RNG.standard_normal(int(dur * SR))


def bp(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], 'bandpass', fs=SR, output='sos')
    return signal.sosfilt(sos, x)


def lp(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f, 'lowpass', fs=SR, output='sos'), x)


def hp(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f, 'highpass', fs=SR, output='sos'), x)


def sweep_bp(x, f0, f1, q=1.2, curve=None):
    """Полосовой фильтр с плавающей частотой (свист, шорох) — посэмпловый биквад."""
    n = len(x)
    c = curve if curve is not None else np.linspace(0, 1, n)
    fc = f0 * (f1 / f0) ** c
    y = np.zeros(n)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(n):
        w = 2 * np.pi * fc[i] / SR
        al = np.sin(w) / (2 * q)
        b0, b2 = al, -al
        a0, a1, a2 = 1 + al, -2 * np.cos(w), 1 - al
        yi = (b0 * x[i] + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1 = x1, x[i]
        y2, y1 = y1, yi
        y[i] = yi
    return y


def room(x, size=0.25, mix=0.18, damp=3500):
    """Небольшая деревянная комната: свёртка с затухающим шумом."""
    ir = lp(noise(size), damp) * np.exp(-t_(size) / (size / 4))
    ir[0] = 0
    wet = signal.fftconvolve(x, ir)[:len(x)]
    wet *= np.max(np.abs(x)) / (np.max(np.abs(wet)) + 1e-9)
    return (1 - mix) * x + mix * wet


def finish(x, tail=0.04, peak=0.5, soft=5200):
    x = lp(x, soft, 2)
    x = x - np.mean(x)
    n = int(tail * SR)
    if n and len(x) > n:
        x[-n:] *= np.linspace(1, 0, n) ** 2
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


# ------------------------------------------------------------------ тембры
def wood_tap(f=620, dur=0.12, bright=1.0):
    body = modal([f, f * 2.57, f * 4.1], [1, 0.45 * bright, 0.18 * bright], [0.035, 0.018, 0.009], dur, 0.0015, 0.01)
    click = bp(noise(dur), 900, 3200) * env(dur, 0.0008, 0.004) * 0.25 * bright
    return body + click


def mallet(f, dur=0.6, decay=0.35, soft=1.0):
    """Маримба: основной тон + 4-й и 10-й обертоны (резонатор), мягкая колотушка."""
    x = modal([f, f * 3.93, f * 9.2], [1, 0.22 * soft, 0.05 * soft], [decay, decay * 0.22, decay * 0.07], dur, 0.004)
    return x


def paper(dur=0.25, lo=900, hi=4200, grain=0.006, attack=0.35):
    n = noise(dur)
    # хруст: случайные всплески громкости каждые grain с
    g = np.repeat(RNG.uniform(0.35, 1.0, int(dur / grain) + 1), int(grain * SR))[:len(n)]
    g = lp(g, 120)
    x = bp(n, lo, hi) * g
    e = env(dur, dur * attack, dur * 0.25)
    return x * e


def thud(f0=95, f1=48, dur=0.35, decay=0.09):
    t = t_(dur)
    f = f1 + (f0 - f1) * np.exp(-t / 0.04)
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * env(dur, 0.002, decay)
    dust = lp(noise(dur), 500) * env(dur, 0.001, 0.03) * 0.5
    return body + dust


def bronze(f=380, dur=0.9, decay=0.45, muffle=1.0):
    """Глухая бронза/наковальня: негармонические моды, верхние быстро гаснут."""
    return modal([f, f * 2.32, f * 3.86, f * 5.62], [1, 0.55 * muffle, 0.3 * muffle, 0.14 * muffle],
                 [decay, decay * 0.55, decay * 0.32, decay * 0.18], dur, 0.0015, 0.004)


def creak(dur=0.55, r0=26, r1=58, f=520):
    """Скрип дерева: цепочка «зацепов» (stick-slip) возбуждает резонанс доски."""
    n = int(dur * SR)
    x = np.zeros(n)
    t = 0.0
    while t < dur * 0.92:
        k = t / dur
        rate = r0 + (r1 - r0) * k + RNG.uniform(-4, 4)
        i = int(t * SR)
        x[i] += RNG.uniform(0.6, 1.0)
        t += 1.0 / rate
    res = bp(x, f * 0.8, f * 1.5, 2) + 0.5 * bp(x, f * 2.1, f * 2.9, 2)
    return res * env(dur, 0.05, dur * 0.6, dur * 0.2)


def coin(f=1650, dur=0.35):
    return modal([f, f * 1.47, f * 2.08, f * 2.71], [1, 0.6, 0.35, 0.2], [0.16, 0.12, 0.08, 0.05], dur, 0.001, 0.02)


def whoosh(dur=0.45, f0=280, f1=1400, peak_at=0.55, q=1.4):
    n = noise(dur)
    c = np.linspace(0, 1, len(n))
    curve = np.where(c < peak_at, c / peak_at, 1 - (c - peak_at) / (1 - peak_at) * 0.6)
    x = sweep_bp(n, f0, f1, q, curve)
    e = np.sin(np.pi * np.clip(c, 0, 1)) ** 1.6
    return x * e


def swell(freqs, dur=1.2, attack=0.45, decay=0.5, amps=None):
    t = t_(dur)
    x = np.zeros_like(t)
    for k, f in enumerate(freqs):
        a = amps[k] if amps else 1 / (k + 1)
        x += a * np.sin(2 * np.pi * f * t) * (1 + 0.004 * np.sin(2 * np.pi * 5 * t))
    return x * env(dur, attack, decay, 0.05)


# ------------------------------------------------------------------ палитра
def s_hover():
    # лёгкое касание бумаги кончиком пальца: тихо, глухо, без звона
    x = paper(0.05, 700, 2600, 0.004, 0.25) * 0.6 + wood_tap(780, 0.05, 0.2) * 0.35
    return finish(x, 0.01, 0.5, 3200)


def s_click():
    x = M(wood_tap(560, 0.13), 0.4 * wood_tap(1180, 0.08, 0.4))
    return finish(room(x, 0.12, 0.12), 0.02)


def smooth_air(dur, f0, f1, q=2.2, level=1.0):
    """Чистый «воздух»: узкая полоса шума плавно скользит f0→f1, огибающая — синус,
    без хруста (правка 07.11: бумажный шорох «грязный»)."""
    x = sweep_bp(noise(dur), f0, f1, q)
    c = np.linspace(0, 1, len(x))
    return lp(x, 2400) * np.sin(np.pi * c) ** 2 * level


def s_tab():
    # v2: внятный двойной «ток-тик» по дереву — вкладка переключилась
    x = pad(wood_tap(620, 0.09, 0.6), 0.16)
    place(x, wood_tap(930, 0.08, 0.5) * 0.75, 0.045)
    return finish(room(x, 0.1, 0.1), 0.02, 0.5, 3600)


def s_paper_slide():
    # v2: окно — мягкий взмах воздуха и тихий деревянный «ток», когда лист лёг
    x = pad(smooth_air(0.2, 380, 900, 2.4), 0.3)
    place(x, wood_tap(430, 0.1, 0.3) * 0.55, 0.15)
    return finish(room(x, 0.12, 0.1), 0.04, 0.5, 3000)


def s_page_turn():
    # v2: страница — один плавный взмах вверх и мягкий хлопок листа о лист
    x = pad(smooth_air(0.26, 450, 1300, 2.0), 0.4)
    place(x, M(wood_tap(520, 0.07, 0.25) * 0.4, thud(180, 120, 0.08, 0.02) * 0.35), 0.22)
    return finish(room(x, 0.15, 0.1), 0.05, 0.5, 3200)


def s_error():
    # два глухих стука костяшкой по столу — «нельзя», без писка
    a = wood_tap(240, 0.12, 0.35) + 0.6 * thud(140, 90, 0.12, 0.03)
    x = pad(a, 0.3); place(x, a * 0.8, 0.11)
    return finish(x, 0.03, 0.5, 2200)


def s_stamp():
    x = M(thud(160, 70, 0.3, 0.05) * 0.8, paper(0.06, 600, 2400, 0.004, 0.05) * 0.5, wood_tap(330, 0.1, 0.3) * 0.5)
    return finish(room(x, 0.18, 0.15), 0.04, 0.5, 3000)


def s_item_get():
    # находка: две мягкие ноты маримбы вверх (ля4 → ре5)
    x = pad(mallet(440, 0.6, 0.3), 0.75)
    place(x, mallet(587, 0.6, 0.35) * 0.9, 0.09)
    return finish(room(x, 0.3, 0.2), 0.08)


def s_armor_equip():
    # v2 (правка 07.11: «грязно, много шума»): без шороха и колец — два глухих
    # стука пластин доспеха, щелчок пряжки и мягкая посадка
    x = np.zeros(int(0.6 * SR))
    place(x, M(bronze(300, 0.35, 0.12, 0.35) * 0.7, thud(130, 80, 0.15, 0.03) * 0.5), 0.0)
    place(x, M(bronze(360, 0.3, 0.1, 0.3) * 0.5, thud(150, 90, 0.12, 0.025) * 0.35), 0.11)
    place(x, M(wood_tap(1050, 0.06, 0.5) * 0.45, bronze(1250, 0.12, 0.05, 0.2) * 0.12), 0.27)
    return finish(room(x, 0.2, 0.12), 0.06, 0.5, 3600)


def s_coins():
    x = np.zeros(int(0.45 * SR))
    for at, f, g in ((0.0, 1450, 1.0), (0.06, 1720, 0.7), (0.11, 1560, 0.5)):
        place(x, coin(f, 0.33) * g, at)
    return finish(room(x, 0.2, 0.15), 0.05, 0.45, 4200)


def s_level_up():
    # тёплое восхождение: до5 ми5 соль5 + мягкая подложка, без «победной» фанфары
    x = pad(swell([261.6, 329.6, 392.0], 1.4, 0.35, 0.5, [0.5, 0.35, 0.3]) * 0.35, 1.5)
    for k, f in enumerate((523.3, 659.3, 784.0)):
        place(x, mallet(f, 0.9, 0.45) * (0.9 - k * 0.1), 0.02 + k * 0.1)
    place(x, mallet(1046.5, 0.9, 0.5) * 0.45, 0.34)
    return finish(room(x, 0.45, 0.25), 0.15)


def s_star_on():
    x = pad(M(bronze(780, 0.9, 0.5, 0.5) * 0.5, mallet(784, 0.8, 0.45) * 0.7), 1.0)
    place(x, mallet(1175, 0.6, 0.35) * 0.35, 0.07)
    return finish(room(x, 0.35, 0.22), 0.1, 0.5, 4600)


def s_chest_appear():
    x = whoosh(0.6, 220, 900, 0.6, 1.2) + swell([196, 294], 0.6, 0.3, 0.2, [0.35, 0.2]) * 0.4
    return finish(room(x, 0.3, 0.2), 0.08, 0.5, 3800)


def s_chest_land():
    x = M(thud(110, 55, 0.4, 0.08), wood_tap(260, 0.18, 0.5) * 0.6)
    place(x, wood_tap(420, 0.08, 0.4) * 0.25, 0.07)  # крышка подпрыгнула
    return finish(room(x, 0.25, 0.18), 0.05, 0.5, 2600)


def s_chest_open():
    # защёлка, скрип петель, крышка легла
    x = np.zeros(int(1.0 * SR))
    place(x, M(wood_tap(980, 0.06, 0.7) * 0.5, coin(1200, 0.08) * 0.08), 0.0)
    place(x, creak(0.55, 22, 46, 480) * 0.8, 0.07)
    place(x, M(thud(120, 70, 0.3, 0.05) * 0.5, wood_tap(300, 0.15, 0.4) * 0.4), 0.62)
    return finish(room(x, 0.3, 0.2), 0.08, 0.5, 3600)


def s_reveal():
    # обычная находка в сундуке: мягкий аккорд маримбы
    x = pad(mallet(392, 0.9, 0.45) * 0.8, 1.0)
    place(x, mallet(494, 0.9, 0.45) * 0.6, 0.04)
    place(x, mallet(587, 0.9, 0.5) * 0.55, 0.08)
    return finish(room(x, 0.4, 0.25), 0.1)


def s_memory_tick():
    return finish(room(mallet(587, 0.45, 0.22), 0.25, 0.2), 0.06, 0.45)


def s_reveal_rare():
    # эпик/легенда/секрет: низкая «вдохновляющая» подложка и восходящее арпеджио
    x = pad(swell([146.8, 220.0, 293.7], 2.0, 0.55, 0.7, [0.6, 0.4, 0.3]) * 0.5, 2.1)
    for k, f in enumerate((587.3, 740.0, 880.0, 1174.7)):
        place(x, mallet(f, 1.0, 0.5) * (0.8 - k * 0.12), 0.35 + k * 0.11)
    place(x, bronze(587, 1.2, 0.7, 0.3) * 0.2, 0.35)
    return finish(room(x, 0.6, 0.3), 0.2)


def s_blade_strike():
    x = M(bronze(330, 0.9, 0.4, 0.6) * 0.6, thud(100, 50, 0.4, 0.08) * 0.7)
    return finish(room(x, 0.35, 0.22), 0.1, 0.5, 3600)


def s_echo():
    # «вдох» эха: перевёрнутый мягкий аккорд, затем короткий хвост
    a = mallet(440, 0.6, 0.3) + mallet(660, 0.6, 0.3) * 0.6
    a = a[::-1] * np.linspace(0.2, 1, len(a)) ** 2
    x = pad(a, 0.9)
    place(x, mallet(880, 0.3, 0.12) * 0.25, 0.58)
    return finish(room(x, 0.4, 0.3), 0.1, 0.45, 3800)


def s_anvil():
    x = M(bronze(420, 0.9, 0.38, 0.75), thud(120, 70, 0.2, 0.03) * 0.5)
    return finish(room(x, 0.3, 0.2), 0.1, 0.5, 4200)


def s_forge_heat():
    n = lp(noise(1.1), 700) * env(1.1, 0.35, 0.3, 0.2)
    cr = np.zeros(int(1.1 * SR))
    for _ in range(14):
        place(cr, bp(noise(0.012), 1500, 3500) * RNG.uniform(0.1, 0.3), RNG.uniform(0.1, 0.95))
    return finish(n + cr * 0.6, 0.12, 0.45, 3600)


def s_quench():
    hiss = hp(noise(1.2), 2200) * env(1.2, 0.01, 0.35)
    hiss = lp(hiss, 5000)
    bub = np.zeros(int(1.2 * SR))
    for _ in range(9):
        f = RNG.uniform(500, 900)
        d = 0.05
        tt = t_(d)
        b = np.sin(2 * np.pi * (f + 2500 * tt) * tt) * np.exp(-tt / 0.015)
        place(bub, b * RNG.uniform(0.1, 0.25), RNG.uniform(0.1, 0.8))
    return finish(hiss * 0.7 + bub, 0.15, 0.45, 5000)


def s_forge_success():
    x = pad(s_anvil() * 0.7, 1.3)
    place(x, mallet(523.3, 0.9, 0.45) * 0.35, 0.14)
    place(x, mallet(784, 0.9, 0.5) * 0.3, 0.24)
    return finish(room(x, 0.4, 0.2), 0.12)


def s_forge_fail():
    x = M(bronze(210, 0.5, 0.15, 0.3) * 0.6, thud(90, 50, 0.3, 0.05) * 0.6)
    return finish(x, 0.06, 0.45, 2000)


def s_spark():
    x = np.zeros(int(0.4 * SR))
    for _ in range(8):
        place(x, bp(noise(0.01), 2000, 4800) * RNG.uniform(0.2, 0.6), RNG.uniform(0, 0.3))
    return finish(x, 0.05, 0.35, 5000)


def s_coin_tick():
    return finish(coin(1500, 0.15), 0.03, 0.4, 4000)


# id звука → (функция, что озвучивает, ключи игры, громкость в игре)
PALETTE = [
    # группа, id, fn, описание, заменяет
    ('Навигация', 'hover', s_hover, 'Наведение на кнопку, слот, пункт списка', ['ui_hover', 'choice_hover', 'list_tick', 'uiHover (шина)', 'stone_tick'], 0.25),
    ('Навигация', 'click', s_click, 'Нажатие кнопки', ['ui_click', 'ui (шина)', 'dialog_next', 'confirm', 'floor_pick'], 0.35),
    ('Навигация', 'tab', s_tab, 'Вкладка, выбор ответа', ['tab_select', 'choice_pick'], 0.3),
    ('Навигация', 'paper_slide', s_paper_slide, 'Окно открылось / закрылось, разговор', ['paper_slide', 'dialog_open', 'dialog_close', 'ui_open_scene'], 0.3),
    ('Навигация', 'page_turn', s_page_turn, 'Листание книги героя', ['page_turn', 'page_back'], 0.35),
    ('Навигация', 'error', s_error, '«Нельзя»: мало денег, нет места, закрыто', ['error', 'mana_empty'], 0.35),
    ('Навигация', 'stamp', s_stamp, 'Подтвердил: печать, купил, выучил талант', ['stamp'], 0.35),
    ('Награды', 'item_get', s_item_get, 'Получен новый предмет (тост)', ['reward_pop', 'new_topic'], 0.35),
    ('Награды', 'armor_equip', s_armor_equip, 'Надел броню / выпала броня', ['armorEquip (шина)'], 0.4),
    ('Награды', 'coins', s_coins, 'Золото', ['coins'], 0.3),
    ('Награды', 'coin_tick', s_coin_tick, 'Счётчик золота тикает', ['coin_tick'], 0.25),
    ('Награды', 'level_up', s_level_up, 'Новый уровень, задание выполнено', ['level_up', 'levelUp (шина)', 'hubQuest (шина)'], 0.4),
    ('Награды', 'star_on', s_star_on, 'Звезда ★ / талант / медаль', ['star_on', 'medal'], 0.35),
    ('Сундук', 'chest_appear', s_chest_appear, 'Сундук появляется и летит в сумку', ['chest_appear', 'chest_fly'], 0.3),
    ('Сундук', 'chest_land', s_chest_land, 'Сундук ставится на стол / подобран', ['chest_land', 'chest_pickup', 'stone_slab'], 0.4),
    ('Сундук', 'chest_open', s_chest_open, 'Защёлка, скрип крышки', ['lid_open', 'chest_open', 'chest (шина)'], 0.4),
    ('Сундук', 'blade_strike', s_blade_strike, 'Клинок касается сундука («читает память»)', ['blade_strike', 'blade_form'], 0.35),
    ('Сундук', 'memory_tick', s_memory_tick, 'Перебор редкостей (тик)', ['memory_tick'], 0.25),
    ('Сундук', 'reveal', s_reveal, 'Показ обычного / редкого предмета', ['item_reveal'], 0.35),
    ('Сундук', 'reveal_rare', s_reveal_rare, 'Эпик, легенда, секрет', ['memory_secret'], 0.4),
    ('Кузня', 'anvil', s_anvil, 'Удар молота по наковальне', ['forge_strike', 'forge_anvil'], 0.35),
    ('Кузня', 'forge_heat', s_forge_heat, 'Горн разгорается', ['forge_heat', 'candle'], 0.3),
    ('Кузня', 'quench', s_quench, 'Закалка в воде', ['forge_quench'], 0.3),
    ('Кузня', 'spark', s_spark, 'Искры', ['forge_spark'], 0.25),
    ('Кузня', 'forge_success', s_forge_success, 'Улучшение удалось (+★)', ['forge_success', 'forge_reveal'], 0.4),
    ('Кузня', 'forge_fail', s_forge_fail, 'Не хватает материала / отказ кузни', ['forge_fail'], 0.35),
    ('Кузня', 'echo', s_echo, 'Эхо / душа впитывается', ['echo_absorb', 'echo_socket', 'soul (шина)'], 0.35),
]


def main(only=None):
    global RNG
    os.makedirs(os.path.join(OUT, 'ogg'), exist_ok=True)
    os.makedirs(os.path.join(OUT, 'mp3'), exist_ok=True)
    meta = []
    from scipy.io import wavfile
    import zlib
    for group, sid, fn, what, keys, vol in PALETTE:
        if only and sid not in only:
            continue
        RNG = np.random.default_rng(zlib.crc32(sid.encode()))  # у каждого звука своё зерно
        x = fn()
        wav = os.path.join(OUT, f'{sid}.wav')
        wavfile.write(wav, SR, (x * 32767).astype(np.int16))
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '6',
                        os.path.join(OUT, 'ogg', f'{sid}.ogg')], check=True)
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libmp3lame', '-b:a', '96k',
                        os.path.join(OUT, 'mp3', f'{sid}.mp3')], check=True)
        os.remove(wav)
        meta.append(dict(group=group, id=sid, what=what, keys=keys, volume=vol, dur=round(len(x) / SR, 2)))
    if not only:
        json.dump(meta, open(os.path.join(OUT, 'palette.json'), 'w'), ensure_ascii=False, indent=1)
    print(len(meta), 'звуков →', OUT)


if __name__ == '__main__':
    main(sys.argv[2:] or None)
