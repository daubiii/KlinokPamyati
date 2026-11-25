"""Баланс посохов: применяет множители из tools/lua/balance_classes.lua (режим BALANCE_SOLVE)
к Config/LootMage.lua — урону посохов (обычные/редкие/эпики) и долям урона заклинаний.
  python3 tools/balance/apply_factors.py items  < solve.txt
  python3 tools/balance/apply_factors.py spells < solve.txt
"""
import re, sys

PATH = 'src/ReplicatedStorage/Shared/Config/LootMage.lua'
SHARES = {
    'ward_circle': ['burst', 'tickDamage'], 'signal_fire': ['blast', 'tickDamage'], 'light_gate': ['surge', 'close'],
    'lotus_bloom': ['geyser', 'petal'], 'mycelium': ['spore', 'cloudTick', 'burst'], 'thorn_garden': ['ring', 'tickDamage'],
    'spirit_pack': ['howl', 'bite', 'pounce'], 'hunters_moon': ['beam', 'crescent'], 'royal_hunt': ['net', 'spear', 'tear'],
    'fire_rain': ['meteor'], 'forged_lightning': ['strike'], 'forge_heart': ['pillar', 'tickDamage'],
    'meteor': ['impact', 'tickDamage'], 'first_cast': ['rift', 'nova'], 'open_tome': ['glyph', 'storm'],
    'time_stop': ['sweep', 'strike'], 'fate_line': ['beam'], 'ink_hole': ['tickDamage', 'blast'], 'total_recall': ['beam', 'orb'],
}

mode = sys.argv[1]
rows = [l.split() for l in sys.stdin if l.startswith('SOLVE ') and not l.startswith('SOLVE id')]
s = open(PATH, encoding='utf-8').read()
abil = dict(re.findall(r'weapon\("(\w+)", "[^"]*", "\w+", \d, "(\w+)"', s))
changed = []
for _, wid, rarity, itemF, spellF in rows:
    itemF, spellF = float(itemF), float(spellF)
    if mode == 'items':
        lo, hi = (0.88, 1.15) if rarity in ('common', 'rare') else ((0.92, 1.12) if rarity == 'epic' else (1.0, 1.0))
        f = min(max(itemF, lo), hi)
        if abs(f - 1) < 0.03:
            continue
        m = re.search(r'(\n\t%s = staff\()([\d.]+)' % wid, s)
        old = float(m.group(2))
        new = round(old * f, 2)
        s = s[:m.start(2)] + ('%g' % new) + s[m.end(2):]
        changed.append('%s damage %.2f -> %.2f' % (wid, old, new))
    else:
        if rarity in ('common', 'rare') or spellF <= 0:
            continue
        f = min(max(spellF, 0.7), 1.5)
        if abs(f - 1) < 0.12:
            continue
        sid = abil[wid]
        start = s.index('\t%s = spell(' % sid)
        end = s.index('}),', start)
        block = s[start:end]
        for key in SHARES[sid]:
            mm = re.search(r'([{ ,]%s = )([\d.]+)' % key, block)
            old = float(mm.group(2))
            new = round(old * f, 2)
            block = block[:mm.start(2)] + ('%g' % new) + block[mm.end(2):]
            changed.append('%s.%s %.2f -> %.2f' % (sid, key, old, new))
        s = s[:start] + block + s[end:]
open(PATH, 'w', encoding='utf-8').write(s)
print('\n'.join(changed))
