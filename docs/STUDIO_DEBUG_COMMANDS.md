# Команды тестирования в Roblox Studio

Этот файл — единая памятка по `DebugCommands`; обновлять его вместе с командами в
[`DebugCommands.lua`](../src/ServerScriptService/Systems/DebugCommands.lua).

## Как запускать

1. Открой проект в Roblox Studio и нажми **Play**.
2. Открой **View → Command Bar**.
3. В контекстном меню Command Bar выбери **Server**.
4. Вставь команду, например:

   ```lua
   print(game.ServerStorage.KlinokDebug.Cmd:Invoke("floor 3"))
   ```

Команды создаются только в Studio. Они работают на сервере и используют первого
игрока в тестовой сессии, если в строке не указан игрок.

Чтобы выполнить действие за конкретного тестового игрока, добавь `@Имя`:

```lua
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("@Player2 floor 4"))
```

Для просмотра встроенной краткой подсказки:

```lua
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("help"))
```

## Телепорт без прохождения

`floor` напрямую запускает выбранный этаж на сложности `normal`: **не требует
пройти предыдущий этаж, открыть врата или разблокировать этаж в профиле**.
После входа можно телепортироваться к нужной зоне командой `zone`.

| Этаж | Команда | Короткая форма | Зоны для `zone <id>` |
|---|---|---|---|
| 1 — Хранилище | `floor 1` | `floor1` или `floor` | `intro`, `yard`, `street`, `warehouse`, `plaza`, `barbican`, `rest1`, `bridge`, `armory`, `forge`, `gallery`, `tower`, `hall`, `chapel`, `lastgates`, `boss` |
| 2 — Затопленные сады | `floor 2` | `floor2` | `pier`, `avenue`, `fountain`, `greenhouse`, `maze`, `arbor`, `lodge`, `canals`, `grotto`, `apiary`, `terraces`, `baths`, `aqueduct`, `mill`, `gazebo`, `statues`, `crypt`, `rosecourt` |
| 3 — Псарни охоты | `floor 3` | `floor3` | `gate`, `kennelrow`, `oldpen`, `manege`, `mews`, `lodge`, `trail`, `poacher`, `range`, `tannery`, `bridge`, `tower`, `chapel`, `stables`, `kennels`, `trophy`, `armory`, `lists` |
| 4 — Литейные | `floor 4` | `floor4` | `adit`, `railway`, `sorting`, `ingots`, `steiger`, `coalslope`, `cage`, `foundry`, `molds`, `coldforge`, `greatforge` |
| 5 — Зал хроник | `floor 5` | `floor5` | `narthex`, `gallery`, `readingroom`, `mapsarchive`, `scribecell`, `stacks`, `stair`, `scriptorium`, `antechamber`, `dome`, `beyond` |

Пример: перейти сразу в зону босса 4-го этажа:

```lua
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("floor4"))
task.wait(2)
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("zone greatforge"))
```

Вернуться в хаб: `hub`.

## Общие команды

Все команды запускаются одним шаблоном:

```lua
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("<команда>"))
```

| Команда | Что делает | Пример |
|---|---|---|
| `help` | Показать краткий список команд | `help` |
| `floor <1-5>` | Запустить этаж без проверки прогресса | `floor 5` |
| `floor1` … `floor5` | Короткая форма входа на конкретный этаж; `floor` без номера = этаж 1 | `floor4` |
| `hub` | Вернуться в хаб | `hub` |
| `zone <id>` | Перейти к зоне текущего этажа; список id — в таблице выше | `zone greatforge` |
| `spawn <тип> [N]` | Создать 1–20 врагов перед игроком; если `N` не задано — 1, для `guard` — 5 | `spawn hound 2` |
| `clear` | Удалить врагов, созданных через `spawn` | `clear` |
| `give <оружие>` | Выдать и надеть оружие по псевдониму или полному id | `give vortex` |
| `give all` | Выдать все 8 оружий; Ключ будет надет | `give all` |
| `star <N>` | Установить уровень звезды оружия в руке (ограничен редкостью) | `star 3` |
| `cd` | Сбросить перезарядки способностей | `cd` |
| `nocd [on\|off]` | Включить или выключить мгновенный сброс перезарядки после каста; без аргумента переключает режим | `nocd on` |
| `god [on\|off]` | Включить или выключить бессмертие; при включении также лечит | `god on` |
| `heal` | Восстановить здоровье и заряды лечения | `heal` |
| `cam side\|front\|top\|back\|off` | Поставить отладочную камеру; `off` возвращает обычную | `cam top` |
| `sfx` | Вывести доступные звуки и варианты | `sfx` |
| `sfx <имя> [N]` | Проиграть выбранный вариант звука; `N` выбирает вариант и сохраняет выбор игрока | `sfx swing3 2` |
| `@Имя <команда>` | Выполнить команду за указанного игрока в тесте на нескольких игроков | `@Player2 floor 2` |

`give` понимает короткие имена `rusty`, `falchion`, `forge`, `gblade`,
`ghammer`, `vortex`, `rift`, `key`; также принимает полный id предмета.

## Команды и враги по этажам

`spawn` создаёт врага рядом с игроком независимо от текущего этажа. Используй
id из нужной строки:

| Этаж | Типы врагов (`spawn <тип>`) | Дополнительные команды |
|---|---|---|
| 1 | `guard`, `shade`, `knight`, `archer`, `martyr`, `gatekeeper`, `guard_elite`, `knight_elite`, `centurion`, `arbalest` | — |
| 2 | `treant`, `bee`, `drowned`, `gardener`, `ranger`, `rosewarden` | `valves` — зачистить зоны вентилей, чтобы их можно было повернуть |
| 3 | `hound`, `beater`, `beater_elite`, `crossbowman`, `trapper`, `falconer`, `falcon`, `bear_hunter`, `bear_hunter_elite`, `torchbearer`, `skinner`, `tanner`, `trophy_bear`, `pack_leader`, `royal_huntsman` | `trophies` — открыть зоны трёх трофеев; `trophies take` — сразу выдать все три и открыть решётку |
| 4 | `forge_automaton`, `fire_spirit`, `slag_thrower`, `smolder`, `elder_founder` | — |
| 5 | `stone_reader`, `seal_mage`, `ward_seal`, `ink_scribe`, `ink_blot`, `shelf_warden`, `bookbinder`, `chief_chronicler` | — |

Псевдонимы боссов для `spawn`: `boss` → Привратник (этаж 1), `boss4` →
Старший литейщик, `boss5` → Главный хронист, `mini5` → Переплётчик. Для
мобов этажа 3 используй полные id, например `spawn royal_huntsman`.

Примеры тестирования:

```lua
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("spawn royal_huntsman"))
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("spawn pack_leader"))
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("clear"))
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("trophies take"))
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("valves"))
```

`trophies` и `valves` действуют на своих этажах; сначала перейди на нужный этаж.
