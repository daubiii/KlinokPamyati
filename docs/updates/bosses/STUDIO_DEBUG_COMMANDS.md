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
| `class <warrior\|mage>` | Сменить класс: броня класса (своя или стартовая), статы, мана | `class mage` |
| `mana [N\|full]` | Мана мага: без аргумента — сколько сейчас и откуда; `full` — полная; `N` — поставить | `mana 20` |
| `magearmor <набор>` | Маг: выдать и надеть комплект (если герой не маг — сначала `class mage`) | `magearmor oblivion` |
| `staff <id\|спелл\|floorN\|all>` | Маг: выдать и надеть посох. Без аргумента — список; `спелл` — посох с этим заклинанием; `floorN` — все посохи этажа в рюкзак; `all` — все 37 | `staff meteor` |
| `veil` | Маг: «Покров» (клавиша 3) без перезарядки и маны; печатает фактические длительность и перезарядку (с учётом древа) | `veil` |
| `level <1-60>` | Поставить уровень героя; очки древа = уровень − 1; статы (здоровье, броня, урон, мана) растут только до 30-го | `level 45` |
| `talents` | Древо текущего класса: уровень, очки (всего / потрачено / свободно), число сбросов и цена следующего | `talents` |
| `talents list [all]` | Пути древа и их узлы (5 узлов + 3 ключевых): слот, id, имя, цена, описание; `all` — ещё и 14 малых узлов каждого пути | `talents list all` |
| `talents learn <id>` | Изучить узел по обычным правилам (очки, уровень, зависимости) | `talents learn w_plates` |
| `talents all` / `talents branch <1-3>` | Изучить всё древо / один путь принудительно, без очков | `talents branch 2` |
| `talents reset` | Бесплатный сброс древа (в любом месте, счётчик сбросов не растёт) | `talents reset` |
| `talents points N` / `talents free` | Добавить N отладочных очков (не сохраняются) / убрать их | `talents points 20` |
| `chest [list]` | Сундуки в сумке: виды, количество, где можно открыть | `chest` |
| `chest give [этаж] [common\|gold] [N]` | Положить в сумку N (1–50) сундуков этажа; полёт показывается один раз | `chest give 1 gold 3` |
| `chest fly [этаж] [common\|gold]` | Выдать сундук с полным полётом к герою и лентой «ПОЛУЧЕН СУНДУК» | `chest fly 4 common` |
| `chest clear` | Убрать все сундуки из сумки | `chest clear` |
| `boss <1-5> [full\|short]` | Поставить босса этажа N в 18 стадах перед игроком и показать его сцену появления; `short` — короткий повтор (3,4 с) | `boss 3 short` |
| `bossmove` | Список фирменных атак ближайшего босса | `bossmove` |
| `bossmove <id> [1-3]` | Ближайший босс сразу начинает атаку; фаза 1–3 меняет параметры (III — злее) | `bossmove gridDrop 3` |
| `@Имя <команда>` | Выполнить команду за указанного игрока в тесте на нескольких игроков | `@Player2 floor 2` |

`give` понимает короткие имена `rusty`, `falchion`, `forge`, `gblade`,
`ghammer`, `vortex`, `rift`, `key`; также принимает полный id предмета.

Наборы мага для `magearmor`: `novice` (стартовый), `reader`, `chronicler`,
`oblivion`, `archivist`. Витрина всех пяти на манекенах:
`print(game.ServerStorage.KlinokDebug.PreviewArmor:Invoke("mage"))`
(`"clear"` — убрать). Подробно — docs/README_MAGE.md.

Посохи мага для `staff`: id из `Config/LootMage.lua` (`apprentice_staff`, `gate_staff`,
`memory_staff`…) или id заклинания (`ward_circle`, `meteor`, `time_stop`, `total_recall`…).
Быстрый прогон всех заклинаний: `class mage` → `nocd on` → `mana full` → `staff <спелл>` → клавиша 1.

Древо талантов (клавиша T или закладка «Древо» в книге героя): быстрый прогон —
`level 60` → `talents all` → открыть T. Игрок видит только древо своего класса
(«Древо воина», «Древо мага»): три пути по 22 узла (14 малых, 5 обычных, 3 ключевых
по 5 очков). Уровень общий, очки и изученные узлы хранятся отдельно для каждого
класса. `talent` — синоним `talents`. Подробно — docs/README_TALENTS.md.

Сундуки этажей (обычный — секретные комнаты, ответвления, мини-боссы; золотой —
босс) больше не открываются на этаже: сундук летит в сумку, а открывается в
долине через сумку `[I]` → «Сундуки» → «ОТКРЫТЬ» (сцена «Клинок читает память»;
клик или Пробел — сразу к карточке). Быстрый прогон:

```lua
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("hub"))
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("chest give 5 common 5"))
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("chest give 1 gold 2"))
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("chest list"))
```

Подробно — docs/README_CHESTS.md.

### Боссы

У каждого из пяти боссов две фирменные атаки и своя сцена появления.
`boss` ставит босса прямо перед игроком (на любом этаже) и проигрывает сцену;
`clear` убирает его. Id атак для `bossmove`:

| Этаж | `boss N` | Атаки (`bossmove <id>`) |
|---|---|---|
| 1 | Привратник | `gridDrop` — «Решётки Хранилища», `keyTurn` — «Поворот ключа» |
| 2 | Садовница | `flood` — «Половодье», `gaze` — «Мраморный взгляд» |
| 3 | Королевский ловчий | `houndDrive` — «Королевская травля», `huntMark` — «Метка ловчего» |
| 4 | Старший литейщик | `ingot` — «Раскалённая заготовка», `bellows` — «Дыхание горна» |
| 5 | Главный хронист | `rewind` — «Переписать прошлое», `bookSlam` — «Глава закрыта» |

```lua
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("god on"))
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("boss 1"))
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("bossmove keyTurn 2"))
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("clear"))
```

Подробно — docs/README_BOSSES.md.

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
