"""Статическая сверка переделки способностей (07.11.2026): каждая фаза kind = "v2", которую шлёт сервер,
есть в обработчиках Controllers/AbilityFxV2; каждое действие из AbilityAnimations есть в PlayerAnimWeapons
или PlayerAnimator. python3 tools/check_weapons_v2.py  → «0 расхождений»."""
import re, sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def read(p):
    return open(os.path.join(ROOT, p), encoding='utf-8').read()
server = read('src/ServerScriptService/Systems/WeaponAbilitiesV2.lua') + read('src/ServerScriptService/Systems/WeaponAbilitiesChronicle.lua')
client = read('src/StarterPlayer/StarterPlayerScripts/Controllers/AbilityFxV2.lua')
# фазы V2: в WeaponAbilitiesV2 все fx(...) — kind v2; в Chronicle — только с kind = "v2"
phases = set(re.findall(r'fx\(\{ phase = "(\w+)"', read('src/ServerScriptService/Systems/WeaponAbilitiesV2.lua')))
phases |= set(re.findall(r'kind = "v2", phase = "(\w+)"', read('src/ServerScriptService/Systems/WeaponAbilitiesChronicle.lua')))
block = client[client.index('AbilityFxV2.handlers = {'):]
block = block[:block.index('\n}\n')]
handled = set(re.findall(r'^\t\t(\w+) = \w+,', block, re.M))
problems = []
for p in sorted(phases - handled):
    problems.append(f'фаза без обработчика: {p}')
for p in sorted(handled - phases):
    problems.append(f'обработчик без фазы: {p}')
anims = read('src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerAnimWeapons.lua')
animator = read('src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerAnimator.lua')
mapping = anims[anims.index('PlayerAnimWeapons.AbilityAnimations = {'):]
for ability, action in re.findall(r'^\t(\w+) = \{ "(\w+)", [\d.]+ \}', mapping, re.M):
    if f'A.{action} = ' not in anims and f'Actions.{action} = ' not in animator:
        problems.append(f'нет анимации {action} ({ability})')
if 'huntLunge' not in anims:
    problems.append('нет huntLunge для гона')
print(f'фаз V2: {len(phases)}, обработчиков: {len(handled)}')
print('\n'.join(problems) if problems else '0 расхождений')
sys.exit(1 if problems else 0)
