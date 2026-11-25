# tools/data — данные инструментов

Эти файлы раньше лежали в `src/ReplicatedStorage/Shared/Config/` и раздавались
каждому клиенту игры (~0,5 МБ на игрока), хотя нужны только сборщикам из
`tools/`. Перенесены сюда по PLAN_DORABOTKI P3-1.

| Файл | Кто использует |
|---|---|
| `FloorMapData.lua`, `Floor2–5MapData.lua` | сборщики карт: `tools/floor1map/`, `tools/floor2map/`, `tools/studio/AssembleFloor45.lua`, `tools/lua/place_merged_v2.lua` |
| `EnemyRig3/4/5.lua` | `tools/lua/assemble_enemies3d.lua`, `tools/studio/AssembleEnemies45.lua` |
| `EnemyArmorData.luau`, `EnemyArmorData2.lua` | `tools/enemy-armor/` |

## Как собирать заново

- **Node/Python-сборщики** (читают с диска): путь уже поправлен
  (`make-floor1-assemble.js`). `tools/floor1map/v3/build.py` пишет результат в
  каталог из аргумента — указывай `tools/data`.
- **Studio-сборщики** (`AssembleFloor1.lua`, `AssembleFloor2.lua`,
  `AssembleFloor45.lua`, `AssembleEnemies45.lua`, `place_merged_v2.lua`)
  делают `require(RS.Shared.Config.X)` — они одноразовые, их выходы уже
  запечены в `.rbxl`. Если такой нужно перезапустить: временно верни файлы
  (`git mv tools/data/<файл> src/ReplicatedStorage/Shared/Config/`), запусти
  сборку, потом верни обратно. Внимание: пока файл в `Shared/Config`, клиенты
  снова качают его — не публикуй игру в этом состоянии.

## Новые карты

`tools/floor1map/v3/build.py OUT_DIR` — указывай `OUT_DIR = tools/data`.
Свежие карты кладутся сюда же и в git не попадают к клиентам.
