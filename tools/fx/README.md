# Эффекты способностей (ReplicatedStorage.FX)

Внешний вид эффектов живёт в шаблонах `ReplicatedStorage.FX` в файле места.
Код только ставит их на место и запускает. Цвет, текстуры, размер, скорость
и время жизни правятся в Studio, без правок скриптов.

| Папка | Что внутри |
|---|---|
| `Common` | `Flash` (вспышка с искрами), `Dust` (кольцо пыли), `Shockwave` (расширяющаяся сфера) |
| `Vortex` | `Funnel` (воронка), `Arm` (луч-рукав), `Sickle` (серп), `BladeTrail`, `Pull` (затягивание на тике), `Wave` (режущая волна) |
| `Rift` | `Slam` (удар), `Crack` и `Magma` (лучи трещины), `CrackFx` (искры вдоль трещины), `Spike` (каменный шип, модель), `SpikeBurst` |
| `Unlock` | `Key` (след и искры летящего ключа), `Impact`, `Seal` (печать), `Chain` (цепь), `ChainEnd`, `Burst` (взрыв) |
| `Keyhole` | `Mark` (значок метки), `Burst` |
| `Garden` | `Reap*` (серповидная волна и движущийся след), `Flood*` (удар и водяной гребень), `Prune*` (перекрёстные срезы), `Bloom*` (цветение), `Rot`, `Thorn`; `*Ribbon` — анимированные пространственные ленты |
| `WeaponHits` | Уникальные цветные всплески и частицы удара для каждого из восьми видов оружия этажа 2 |
| `Weapon` | `epic`, `legendary`: аура на клинке, подхватывается при сборке оружия |

Звуки способностей этажа 2 (`gardenReap`, `gardenFlood`, `gardenPrune` и др.)
настроены слоями в `src/ReplicatedStorage/Shared/Config/Sfx.lua`; используются
бесплатные звуковые эффекты Pro Sound Effects из Creator Store.

## Правки в Studio

- Меняйте свойства шаблона и сохраняйте место (Ctrl+S). Rojo папку `FX` не трогает.
- `Rift/Spike` можно заменить своей моделью или MeshPart. Опорная точка — низ шипа, атрибут `Height` — высота.
- Атрибуты эмиттеров:

  | Атрибут | Что делает |
  |---|---|
  | `Emit` | выбросить N частиц разом; без него эмиттер работает непрерывно |
  | `EmitDelay` | задержка выброса, с |
  | `Pattern` | `ring` — разлёт кольцом, `inward` — затягивание к центру (направление `Front`) |
  | `ScaleSize`, `ScaleSpeed` | масштабировать по радиусу способности (`BaseRadius` у детали) |
  | `MatchLife` | время жизни частицы равно длительности эффекта |

- У PointLight атрибут `Fade` — за сколько секунд свет погаснет.

Подробнее — в шапке `BuildFx.lua` и `src/.../Lib/FxKit.lua`.

## Пересборка

- `BuildFx.lua` в Command Bar (режим Edit) создаёт недостающие шаблоны. Уже существующие и правленые не трогает.
- `BuildFxGarden.lua` после него создаёт шаблоны и ауры оружия второго этажа. Повторный запуск добавляет недостающие шаблоны, не удаляя существующие.
- `local REBUILD = true` в начале файла сносит `FX` и собирает заново. Все ручные правки при этом теряются.
- Из терминала, через мост MCP: `python -I tools/fx/run_in_studio.py tools/fx/BuildFx.lua Edit [--rebuild]`.
- Для этажа 2: `python -I tools/fx/run_in_studio.py tools/fx/BuildFxGarden.lua Edit`.

## Текстуры

- `make_textures.py` рисует PNG в `textures/`: белые с альфой, цвет задаётся в шаблоне.
- Загрузка в Roblox — инструмент `upload_image` моста MCP. Картинки отдаёт локальный HTTP-сервер:
  ```
  python -I -m http.server 8811 --bind 127.0.0.1    # в папке textures
  ```
- Полученные `rbxassetid` вписать в таблицу `TEX` в `BuildFx.lua`.
- Сразу после загрузки текстура несколько минут может не показываться: в Output будет `Asset content representation is being generated`.

## Проверка в Play

Command Bar, контекст сервера:
```lua
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("give vortex"))   -- vortex | rift | key
-- god on, nocd on, spawn 6, cam side|front|top|back|off, clear
```

Серия кадров с каста (мост MCP):
```
python -I tools/fx/fx_test.py "give rift;god on;nocd on;spawn 6;cam side" 6 150 --start
```

## Подводные камни

- Направление выброса движок берёт в момент отрисовки, а не в момент `Emit`. Поэтому `ring` и `inward` — это веер копий эмиттера на своих Attachment.
- Новый эмиттер не выпускает частицы в кадре, когда его создали. FxKit выбрасывает со следующего кадра.
- BillboardGui в этом месте не рисуется. Значки над врагами — частицы с `LockedToPart`.
- `HTTP 429 (Too Many Requests)` у `ContentId` / `MeshContentProvider` — временное ограничение загрузки Roblox CDN, не ошибка Lua. Дайте Studio завершить загрузку и повторно проверьте конкретный меш; не пересобирайте и не удаляйте карту из-за единичного 429.
