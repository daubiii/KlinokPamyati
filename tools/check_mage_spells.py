"""Сверка заклинаний посохов сервер ↔ клиент (08.11.2026).
Для каждого заклинания из Config/LootMage.Abilities проверяет:
  * есть CASTS.<id> на сервере (Systems/WeaponAbilitiesMage) и нет чужого id с тем же именем у воина;
  * фазы, которые сервер реально шлёт (spellFx(c, "<фаза>")), = серверный PHASES = клиентский PHASES;
  * у клиента есть обработчик на каждую фазу (MageSpellFx H.<id> или MageSpellFxV2);
  * анимация каста (PlayerAnimMage.SPELL_ANIM) и иконка в Config/AbilityIconsMage.
  python3 tools/check_mage_spells.py
"""
import re, sys, glob

ROOT = 'src/'
read = lambda p: open(p, encoding='utf-8').read()
server = read(ROOT + 'ServerScriptService/Systems/WeaponAbilitiesMage.lua')
client = read(ROOT + 'StarterPlayer/StarterPlayerScripts/Controllers/MageSpellFx.lua')
clientV2 = read(ROOT + 'StarterPlayer/StarterPlayerScripts/Controllers/MageSpellFxV2.lua')
loot = read(ROOT + 'ReplicatedStorage/Shared/Config/LootMage.lua')
anim = read(ROOT + 'StarterPlayer/StarterPlayerScripts/Controllers/PlayerAnimMage.lua')
icons = read(ROOT + 'ReplicatedStorage/Shared/Config/AbilityIconsMage.lua')

spells = re.findall(r'\n\t(\w+) = spell\("(\w+)", "[^"]*", "(\w+)"', loot)
problems = []


def phases_table(src):
    block = src[src.index('PHASES = {'):]
    block = block[:block.index('\n}')]
    return {k: re.findall(r'"(\w+)"', v) for k, v in re.findall(r'\n\t(\w+) = \{([^}]*)\}', block)}


sp, cp = phases_table(server), phases_table(client)

# серверные spellFx по каждому CASTS
casts = {}
parts = re.split(r'\nCASTS\.(\w+) = function', server)
for i in range(1, len(parts), 2):
    casts[parts[i]] = re.findall(r'spellFx\(c, "(\w+)"', parts[i + 1].split('\nCASTS.')[0].split('\nfunction ')[0])

# клиентские обработчики
handlers = {}
for src in (client, clientV2):
    for m in re.finditer(r'\n\t*H\.(\w+) = \{', src):
        start = m.end()
        depth, j = 1, start
        while depth and j < len(src):
            depth += src[j] == '{'
            depth -= src[j] == '}'
            j += 1
        body = src[start:j]
        handlers.setdefault(m.group(1), set()).update(re.findall(r"\n\t{1,3}\[?\"?(\w+)\"?\]? = function", body))
for phase in re.findall(r'\n\t\ttime\.(\w+) = function', clientV2):
    handlers.setdefault('time_stop', set()).add(phase)

# чужие id: способности воина с тем же именем
warrior_ids = set()
for f in glob.glob(ROOT + 'ReplicatedStorage/Shared/Config/Loot*.lua'):
    if f.endswith('LootMage.lua'):
        continue
    warrior_ids.update(re.findall(r'\n\t(\w+) = \{\s*\n\t\tid = "\w+"', read(f)))
    warrior_ids.update(re.findall(r'ability\("(\w+)"', read(f)))

for key, sid, icon in spells:
    sent = sorted(set(casts.get(sid, [])))
    if sid not in casts:
        problems.append(f'{sid}: нет CASTS на сервере')
    if sid in warrior_ids:
        problems.append(f'{sid}: id совпадает со способностью воина')
    if sorted(sp.get(sid, [])) != sent:
        problems.append(f'{sid}: сервер шлёт {sent}, а PHASES сервера {sp.get(sid)}')
    if sp.get(sid) != cp.get(sid):
        problems.append(f'{sid}: PHASES сервер {sp.get(sid)} ≠ клиент {cp.get(sid)}')
    missing = [p for p in sent if p not in handlers.get(sid, set())]
    if missing:
        problems.append(f'{sid}: нет клиентских обработчиков {missing}')
    if not re.search(r'\n\t%s = "' % sid, anim):
        problems.append(f'{sid}: нет анимации в SPELL_ANIM')
    if not re.search(r'\n\t\t%s = \{ x' % icon, icons):
        problems.append(f'{sid}: иконка {icon} не в AbilityIconsMage')

# поля способности, которые читает сервер, должны быть в LootMage (иначе nil в арифметике)
COMMON = {'id', 'name', 'icon', 'mana', 'cooldown', 'castTime', 'description', 'school', 'damageMultiplier'}
for key, sid, icon in spells:
    start = loot.index('\t%s = spell(' % sid)
    block = loot[start:loot.index('}),', start)]
    have = set(re.findall(r'(\w+) = ', block)) | COMMON
    body = server.split('\nCASTS.%s = function' % sid)[1].split('\nCASTS.')[0] if sid in casts else ''
    used = set(re.findall(r'ability\.(\w+)', body))
    lack = sorted(used - have)
    if lack:
        problems.append(f'{sid}: сервер читает поля, которых нет в LootMage: {lack}')

passives_block = loot[loot.index('LootMage.Passives = {'):]
for pid in re.findall(r'\n\t(\w+) = \{ id = "', passives_block[:passives_block.index('\n}')]):
    if pid in warrior_ids:
        problems.append(f'пассивка {pid}: id совпадает с пассивкой/способностью воина')

print(f'Заклинаний: {len(spells)}; фаз всего: {sum(len(set(casts.get(s, []))) for _, s, _ in spells)}')
for p in problems:
    print('  ✗', p)
print('Расхождений:', len(problems))
sys.exit(1 if problems else 0)
