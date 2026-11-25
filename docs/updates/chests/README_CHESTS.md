# Сундуки этажей v3 — «Клинок читает память»

Сундук больше **не открывается на этаже**. Зачистил комнату — сундук сам
собирается из квадратов памяти, парит, разворачивается и летит в сумку героя;
сверху выезжает лента «ПОЛУЧЕН СУНДУК». Открывают его в **долине** (хаб):
сумка `[I]` → вкладка «Сундуки» → «ОТКРЫТЬ». Там Клинок Памяти «читает», что
хранил сундук, и показывает находку.

## Откуда берутся сундуки

| Вид | Где выпадает | Ключ |
|---|---|---|
| Обычный (`common`) | секретные комнаты, ответвления, мини-боссы | `f<этаж>_common` |
| Золотой (`gold`) | босс этажа (`Config.Chests[kind].final == true`) | `f<этаж>_gold` |

Содержимое прежнее (`LootService.rollContents`): золотой = «сундук босса»
(броня всегда, припасов больше, аксессуар чаще). Содержимое бросается в момент
открытия, а не при выдаче.

## 10 дизайнов (по 2 на этаж)

| Этаж | Обычный | Золотой |
|---|---|---|
| 1 Привратный двор | Сундук стражи | Золотой сундук Привратника |
| 2 Затопленные сады | Замшелый сундук | Золотой сундук Садовницы |
| 3 Псарни охоты | Охотничий сундук | Золотой сундук Ловчего |
| 4 Литейные | Литейный сундук | Золотой сундук Литейщика |
| 5 Зал хроник | Сундук-фолиант | Золотой сундук Хрониста |

Модели собираются из деталей `Config/ChestDesigns.lua` (`Util/ChestModel.lua`),
цвета — из `Config/Chests.lua` (под `Palette.Floors`). Превью всех десяти —
`tools/chests/previews/chests_sheet.png` и `chests_icons.png`.

## Что видит игрок

1. **На этаже.** Сундук проявляется над местом зачистки → парит → летит к
   герою и «падает» в значок сумки (`ChestFlyController`). Лента сверху
   «ПОЛУЧЕН СУНДУК · <имя>», у сумки значок `×N`.
2. **Босс.** Баннер «<Босс> повержен · Золотой сундук летит в сумку — откроешь
   в долине». Итог этажа ждёт `Chests.SummaryDelay` (3,6 с), пока сундук
   долетит; в итоге — строка «Сундуки в сумке: N (★золотых)».
3. **Сумка.** Вкладка «Сундуки» (вторая): стопки по видам, крупный арт, этаж,
   шансы (оружие/броня/припасы/аксессуар), кнопка «ОТКРЫТЬ · ×N». Вне долины —
   «ОТКРЫТЬ — В ДОЛИНЕ» (неактивна).
4. **Сцена «Клинок читает память»** (`ChestRevealController`, ~10 с):
   - затемнение и размытие, сундук падает с отскоком и пылью;
   - из квадратов памяти собирается Клинок, остриём вниз;
   - удар в замок: вспышка, тряска, искры, кольца;
   - крышка открывается, лучи цвета этажа, Клинок зависает над сундуком;
   - поток памяти по спирали, дол клинка пульсирует цветами редкостей до
     выпавшей; печатается «шёпот этажа»;
   - **секретная** редкость: сбой, три кольца, «ТАКОГО КЛИНОК ЕЩЁ НЕ ПОМНИЛ»;
   - Клинок рассыпается в находку — столб света, лучи;
   - карточка: мощь (со счётчиком и ±% к надетому), способность,
     броня/аксессуар/припасы, золото и материалы, «В сумке ещё: N»,
     кнопки **НАДЕТЬ** / **В СУМКУ** / **ОТКРЫТЬ ЕЩЁ**.
   - Клик или Пробел — пропустить сразу к карточке; Esc / Enter / B — «В сумку».

Предметы зачисляются на сервере в момент запроса (`StationApi.chests.open`),
сцена только показывает результат — выход из игры посреди анимации ничего не
теряет.

## Установка

1. Распаковать архив поверх проекта (Rojo).
2. Загрузить `assets/chests/chest_atlas.png` через Asset Manager и вписать id
   в `src/ReplicatedStorage/Shared/Config/ChestArt.lua`:
   ```lua
   ChestArt.Atlas = "rbxassetid://<id>"
   ```
   Без атласа всё работает: сумка и лента показывают живую 3D-модель во
   ViewportFrame — красиво, но дороже на телефонах.
3. Сохранения: `DataService` v4 добавляет `profile.chests` (миграция сама).

## Отладка

```lua
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("chest give 1 gold 3")) -- 3 золотых сундука 1-го этажа
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("chest fly 4 common"))  -- показать полёт сундука к герою
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("chest list"))          -- что лежит в сумке
print(game.ServerStorage.KlinokDebug.Cmd:Invoke("chest clear"))         -- убрать все сундуки
```

Быстрый прогон сцены: `hub` → `chest give 5 common 5` → `[I]` → «Сундуки» →
«ОТКРЫТЬ», потом «ОТКРЫТЬ ЕЩЁ».

## Инструменты

- `python3 tools/chests/build_chest_art.py` — перегенерировать `ChestDesigns.lua`,
  `ChestAtlas.lua`, `assets/chests/chest_atlas.png` и превью.
- `python3 tools/chests/preview_reveal.py` — офлайн-превью сцены раскрытия:
  `tools/chests/previews/reveal_f1_gold.mp4` (легендарное) и
  `reveal_f5_common.mp4` (секретное) + ключевые кадры.
- Тест: `LUAU=<путь к luau> node tools/run-luau.js tools/lua/test_chests.lua`.

## Файлы

Общие: `Config/Chests.lua`, `Config/ChestDesigns.lua`, `Config/ChestAtlas.lua`,
`Config/ChestArt.lua`, `Util/ChestModel.lua`, `Net/Net.lua` (ChestGranted).
Сервер: `ChestService.lua` (новый), `LootService.lua`, `FloorService.lua`,
`DataService.lua`, `InventoryService.lua`, `DebugCommands.lua`, `Bootstrap.server.lua`.
Клиент: `Lib/ChestVisual.lua` (новый), `Controllers/ChestFlyController.lua`
(новый), `Controllers/ChestRevealController.lua` (новый), `PixelHudController`,
`FloorUiController`, `Windows/CharacterWindow`, `Lib/PaperUi` (`slot.custom`),
`Lib/Ui` (иконка `chest`), `Lib/UiSound` (10 новых звуков), `Lib/StationApi`
(`chests.get/open`), `Bootstrap.client.lua`.

Звуки — синтезированные миксы `UiSound.Mix` (`chest_appear`, `chest_fly`,
`chest_pickup`, `chest_land`, `blade_form`, `blade_strike`, `lid_open`,
`memory_tick`, `memory_secret`, `item_reveal`); можно заменить своими id.
