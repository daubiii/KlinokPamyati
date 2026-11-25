# Передача проекта «Клинок Памяти» (для агента)

Этот файл — краткая карта проекта и предупреждения о подводных камнях.
Читать первым, до любых правок.

## Что где лежит

```
src/                       весь код игры (Rojo-дерево)
  ReplicatedStorage/Shared/    конфиги, воксельные сборщики, FX-описания
  ServerScriptService/         серверные системы (Systems/, Hub/)
  StarterPlayer/StarterPlayerScripts/  клиентские контроллеры и окна
default.project.json       соответствие папок Rojo ↔ DataModel
tools/                     генераторы и вспомогательные скрипты
  rojo/rojo.exe            сервер Rojo (сам бинарник в архив не входит)
  lua/                     проверочные скрипты для Command Bar / MCP
  <пакеты>/                экспортёры GLB, сборщики атласов, BuildFx
docs/updates/              документация каждого пакета обновлений
  README.md                общее описание проекта и механик
Ставка: место Roblox — отдельный файл `KlinokPamyati123.rbxl`.
```

## Git: где история и что в неё не попадает

Репозиторий локальный, без удалённых копий:

```
путь:     C:\Users\artem\KlinokPamyati
ветка:    master
коммитов: 183 (на 21.11.2026)
remote:   нет
```

История доступна обычным git — из VS Code, из терминала, любому агенту:

```powershell
git log --oneline -20                 # последние коммиты
git show --stat HEAD                  # файлы последнего коммита
git show HEAD:src/ServerScriptService/Bootstrap.server.lua   # файл на тот момент
git log --oneline -S "capWalls"       # в каком коммите менялась строка
git log --oneline -- <путь>           # история конкретного файла
```

**В git НЕ попадает (важно для агента):**

| Что | Где на самом деле |
|---|---|
| `KlinokPamyati123.rbxl` | `C:\Users\artem\Desktop\` — вне репозитория |
| Собранные меши оружия и брони | внутри плейса (`ReplicatedStorage.WeaponMeshes`, `HeroArmorMeshes`) |
| Шаблоны FX (133 шт.) | внутри плейса, сервер собирает их из конфигов при старте |
| Геометрия карты и правки террейна | внутри плейса (в git только `src/`-конфиги и генераторы) |

То есть по git можно понять **код**, но не **содержимое места**. Если нужен вид
игры — просить `KlinokPamyati123.rbxl`.

Скриншоты отладки (`tools/shots/`, `docs/shots/`) и сырые кадры референс-режима
(`reference_mode/`) в git не хранятся — только отобранные
(`docs/reference-mode/`).


## Как запускать

1. `rojo serve` из корня (порт 34872), в Studio — **Rojo → Connect**.
2. После правок Lua — `node tools/lua/check_syntax.js <файлы.lua>` (мост 8799
   запущен, плей остановлен). Это единственный настоящий парсер синтаксиса.
3. Играть — Play в Studio. Отладочные команды в Command Bar (только Studio):
   ```lua
   print(game.ServerStorage.KlinokDebug.Cmd:Invoke("give royal_scythe"))
   print(game.ServerStorage.KlinokDebug.Cmd:Invoke("class mage"))
   print(game.ServerStorage.KlinokDebug.Cmd:Invoke("help"))  -- полный список
   ```
4. Перед выключением — **Ctrl+S**, иначе новые объекты в месте пропадут.

## Критично: что НЕ лежит в папке и живёт только в .rbxl

Rojo хранит только скрипты. В месте (файле `.rbxl`) остаётся:

| Объект | Что это | Как восстановить из папки |
|---|---|---|
| `ReplicatedStorage.WeaponMeshes` | 213 MeshPart оружия | импорт GLB из `tools/weapons/`, `tools/mage-weapons/` + `tools/assemble/*` (см. `tools/make-assemble.js`) |
| `ReplicatedStorage.HeroArmorMeshes` | броня героя (190) | `tools/mage-armor/`, `tools/enemy-armor/` |
| `ReplicatedStorage.FX` | 87 шаблонов эффектов | `node tools/make-fx-build.js` → `tools/fx/BuildFx345_run.lua` в Edit |
| геометрия этажей и хаба | воксельные модели | `tools/lua/`, `tools/floor1map/`, `tools/hub/` |
| загруженные картинки | атласы (id в конфигах) | PNG в `assets/` каждого пакета, залить заново |

**Вывод:** для работы над кодом папки достаточно; для полного восстановления
нужен ещё `.rbxl` и PNG-атласы.

## Подводные камни (проверено на практике)

1. **Пакеты обновлений — ветки, а не слои.** Каждый следующий пакет может
   привезти свою версию файла и затереть правки предыдущего. Один раз так
   потерялись данные оружия этажей 3–5, алиасы отладочных команд, контроллеры
   и правки UI. Инструменты в `tools/`:
   - `audit-packages.js` — находит блоки, которые пропали (сравнивает версии всех пакетов);
   - `merge-packages.js` — трёхстороннее слияние (`git merge-file`, база — коммит до наложения);
   - `restore-files.js` — возвращает файл к версии самого свежего пакета;
   - `reapply-fixes.js` — идемпотентно возвращает известный набор правок.
   **После установки нового пакета всегда прогонять `audit-packages.js`.**
2. **Sandbox MCP (Assistant) не может создавать скрипты** в папках с
   `Capabilities: Network` (`Shared.Config`, `Controllers`, `Lib`, `Windows`,
   `ServerScriptService.Systems`). Обновлять существующие — может, создавать
   новые — нет. Новые файлы заливаются только через **Rojo → Connect**.
3. **`Enum.ParticleEmitterShape.Point` не существует** — был источником
   «клинок не появляется»: обращение бросало ошибку в `pcall`. Объёмные
   эмиттеры определять по `ShapeStyle == Volume`.
4. **Меши оружия** задаются `Config.WeaponMeshDataFloorN`: `size.y` и `offset.y`
   должны давать верх ровно на `bladeTip` (иначе клинок выглядит обрезанным).
5. **Хват оружия**: `Weld` с именем `GripWeld`, части варятся к `Root` модели.
   `C0` анимирует клиент (`PlayerAnimator.weaponSwing`), углы поворота —
   в атрибутах `IdleRoll` / `SwingRoll`. Косы разворачиваются на 90° в покое.
6. **UI**: `PixelUi.screen` учитывает верхнюю панель Roblox (корень меньше на её
   высоту) — не добавлять вторую компенсацию в окнах.

## Текущее состояние (21.11.2026)

Живой план работ — `PLAN_DORABOTKI.md` в корне (журналы STATE.md и
PLAN_PROGRESS.md удалены как устаревшие; история — в git).

- Установлены пакеты: weapons_345, ui_studio, mage, talents, chests(v1),
  bosses, skills_fx, chests(v3), worldmap.
- Меши собраны: оружие 3–5 — 74/74, броня мага — 77/77, посохи — 111/111.
- Атласы загружены, id вписаны в конфиги (сундуки, карта, таланты, Paper UI, иконки 3–5).
- Play стартует без ошибок, этажи 1–5 работают, враги спавнятся.
- Новое с 14.11: выбор пути v4 (класс-окно после справки), отряды до 3,
  дебафы мороз/огонь/яд, настройки-шестерёнка, голосование в конце этажа,
  охота Феофана (квест-цепочка), золотые мобы (P6), стена профилей
  (валидация+бэкап).
- **Не проверено в живой игре:** способности всех 25 видов оружия 3–5,
  бои на этажах 3–5, сундуки v3, карта мира, боссы, мультиплеер 2 клиентами.

## Обновление 14.11.2026 — новое в коде (карта)

**Новое в коде (где что лежит):**

| Что | Где |
|---|---|
| Справка новичка «Свиток памяти» (7 слайдов после ролика) | `Systems/TutorialService.lua` (мини-сервис: атрибут ShowSlides + RemoteEvent TutorialSlidesDone), `Controllers/TutorialController.client.lua` (перга-лист, PaperUi/PixelUi, печать «ИГРАТЬ» через PaperUi.stamp) |
| Иллюстрации слайдов (иконки владельца ×18, рисуются 1:1) | `Config/UiAssets.lua → TutorialArt` (7 id), исходники `tools/icons/out_user/slides/*.png` |
| Отряды до 3 игроков, телепорт к лидеру, групповые этажи | `Systems/PartyService.lua` (создан 14.11; ремоуты PartyState/PartyRequest), окно — `Controllers/PartyController.client.lua` |
| Групповой вход на этаж | `Hub/HubService.lua → enterFloor` дергает `PartyService.onLeaderEnteredFloor` (setHub в HubService.start) |
| HP врагов этажа +35% за лишнего игрока | хук `EnemyService.spawnHooks` внутри PartyService.start (EnemyService не тронут; масштаб по `enemy.room.floorId`) |
| Стена профилей: строгая валидация + бэкап | `Systems/DataService.lua → validateProfile` (после reconcile), бэкап-стор `KlinokPamyati_backup_v1` (кольцо cur+prev; восстановление при пропавшей/битой записи — `tryRestoreFromBackup`) |
| Заставка загрузки профиля | `Controllers/LoadingScreenController.client.lua` (первый в Bootstrap.client; уступает ролику, возвращается после него) |
| Отладка листания справки без кликов | атрибут игрока `TutorialSlidesPage` = 1..7 (Command Bar, контекст Client) |
| DebugCommands | `game.ServerStorage.KlinokDebug.Cmd:Invoke("tutorial reset")` — показать справку заново; «help» — весь список |

**Место НЕ опубликовано (критично для агента):** DataStore в Studio не работает
(«You must publish this place»), профили живут в памяти сессии — tutorialDone и
прочее не переживают прогоны (справка показывается каждый Play — это НЕ баг).
DataService печатает инструкцию при старте. Шаги владельца: File → Publish to
Roblox As, затем Game Settings → Security → «Enable Studio Access to API
Services». До публикации бэкап-стор тоже не пишется.

**Грабли, проверенные 14.11 (продолжение списка ниже):**

7. **Вызов метода на строковом литерале не компилируется** в сборке Studio
   владельца: `"x":format()` — ошибка «Expected identifier, got ':'».
   Работает `("x"):format()`. Настоящая проверка синтаксиса —
   `node tools/lua/check_syntax.js <файлы.lua>` (loadstring через мост 8799);
   rojo build синтаксис НЕ парсит; чекер требует **остановленный плей**
   (Edit datamodel недоступен в Play).
8. **`Enum.ResampleMode` в сборке нет** — только внутри pcall.
   **`GuiButton:Activate()` недоступен из execute_luau** — клики в мост-тестах
   недоступны; окна для скринов открываются прямой правкой `gui.Enabled`/
   атрибутов (справка — через `TutorialSlidesPage`, отряд — серверный
   `PartyService.leave/create` перепубликует состояние в открытое окно).
9. **Контроллеры в `Controllers/`** берут общие либы через
   `local Lib = script.Parent.Parent.Lib` (Lib — сосед папки Controllers,
   а не внутри неё).
10. **rojo serve запускать напрямую**: `./tools/rojo/rojo.exe serve` —
    `node tools/rojo/rojo.exe` молча не работает, пайп `| head` убивает serve
    (SIGPIPE). Мост (порт 8799) умирает сам — перезапускать
    `node tools/studio-bridge.js`; `screen_capture` возвращает **путь к jpg**
    в `tools/shots/` (читать инструментом Read).
11. **requestSave** (DataService) — вызывать после ценных изменений профиля
    (сундук, босс, квест): даёт отложенное сохранение + запись в бэкап-стор.

## Запуск после перезагрузки компьютера

Одна команда поднимает всё (откроет плейс в Studio, проект в VS Code,
проверит мост):

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\artem\KlinokPamyati\tools\start-dev.ps1
```

Переживает выключение: вход, настройки VS Code, переменные прокси, MCP и
мост (поднимается сам), `src/` + git. **НЕ переживает**: скрипты/объекты
внутри плейса — только `Ctrl+S` в Studio перед закрытием.

Проверка связи: написать агенту «Use the roblox-studio MCP tool
bridge_status» — в ответе должно быть `KlinokPamyati123.rbxl`.

Конвейер установки пакета `.rbxmx`: `tools\extract-rbxmx.ps1` →
`node tools\assemble-update.js` → `node tools\sync.js` → `node tools\status.js`
(после — всегда `node tools\audit-packages.js`, см. грабли №1).

Если что-то не поднялось: `STUDIO НЕ ПОДКЛЮЧЕНА` — Assistant → ⋯ → Manage
MCP Servers → Enable Studio as MCP server; мост молчит — перезапустить
`node tools\studio-bridge.js`; прокси — `docs/MCP_SETUP.md`.

## Стиль работы

- Код — Luau с `--!nonstrict`, комментарии по-русски, объясняют «почему», а не «что».
- Мелочи и правки — отдельными коммитами с описанием причины.
- Не трогать настройки прокси/VPN и MCP-мост без явной просьбы.
