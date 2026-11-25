# Броня врагов: сетки → меши → префабы

Шаг 5 конвейера врагов (ТЗ врагов этажа 1, разделы 2.1–2.4). Заглушки из
шага 3 (`tools/lua/build_enemy_prefabs.lua`, простые блоки) заменяются
воксельными мешами по пиксельным сеткам ТЗ.

| Файл | Что это |
|---|---|
| `armor.json` | Все сетки ТЗ дословно + параметры деталей, описанных словами |
| `build_armor.py` | Генератор: greedy meshing, палитра 16 клеток, UV в центрах клеток, воксель 0,125 |
| `apply_template.lua` | Шаблон скрипта замены (генератор вписывает в него манифест) |
| `render_preview.py` | Превью врагов с мешами без Studio (нужен numpy) |
| `prefab_layout.json` | Раскладка префабов для превью (`tools/lua/export_prefab_layout.lua`) |
| `out/enemy_armor.glb` | Все 64 детали одним файлом (по узлу на деталь) — его и импортировать |
| `out/*.glb` | Те же меши по отдельности: `<враг>_<деталь>.glb` (для точечной замены) |
| `out/palette.png` | Палитра 16 клеток по 16 px (порядок `Palette.VoxelOrder`); в Studio — текстура импорта `rbxassetid://85494384872386` |
| `out/manifest.json` | Размеры, смещения от заглушек, цвета для распада |
| `../lua/apply_armor_meshes.lua` | Скрипт замены для Studio (собирается генератором) |

## Собрать меши

```
python tools/enemy-armor/build_armor.py
python tools/enemy-armor/render_preview.py          # out/preview.png — проверить на глаз
```

## Импорт в Studio — по шагам

Загрузить меш из скрипта нельзя (`AssetService:CreateAssetAsync` в Studio
пока закрыт), поэтому импорт делается руками, но файл один. Префабы-заглушки
и папка `ServerStorage.EnemyArmorMeshes` уже на месте. Палитра — текстура,
которую импорт загрузил вместе с `.glb` (`PALETTE_TEXTURE` в
`apply_template.lua`; `palette.png`, загруженный отдельно как Image,
текстурой меша не рисуется).

1. *Home* (или *Avatar*) → **Import 3D** → `tools/enemy-armor/out/enemy_armor.glb`.
   В окне импорта ничего не менять: *Upload to Roblox* включено по
   умолчанию (без него меши не сохранятся), масштаб и якорение скрипт
   выставит сам. → **Import**.
2. Появившуюся в Workspace модель перетащить в
   `ServerStorage.EnemyArmorMeshes`. Распаковывать не надо: скрипт ищет
   MeshPart с именами `guard_Helmet`, `knight_Mace`… по всем потомкам.
3. **Заменить заглушки.**
   `node C:\Users\artem\.dsh-roblox\s.js exec tools/lua/apply_armor_meshes.lua Edit`
   (или вставить файл в Command Bar). В ответе: «заменено: 64, не найдено: 0».
   Если чего-то нет — скрипт перечислит имена.
4. **Ctrl+S.**

Если префабов нет или они уже менялись — сначала пересобрать заглушки:
`node C:\Users\artem\.dsh-roblox\s.js exec tools/lua/build_enemy_prefabs.lua Edit`.
Сменили палитру этажа (2.6) — переимпортировать `enemy_armor.glb`, вписать
`TextureID` любой его детали в `PALETTE_TEXTURE`, пересобрать генератор и
повторить шаг 3 на свежих заглушках.

Что делает скрипт замены: ставит меш на место заглушки-якоря (смещение и
размер из манифеста × масштаб `ScaleTo` префаба), переносит на него
суставы (`WeaponGrip`, `ShieldGrip`, `BowGrip`, `Tabard`, `Cloak`, `Crest`,
`Crown`, `ChainR/L`), сварку с телом, точки `FX_*`, тетиву, частицы и
атрибуты (`Body`, `Role`, `Phase`) и пишет атрибут `Colors` — три самых
частых цвета детали для кубиков распада. Повторный запуск ничего не ломает.
Проверено на подставных MeshPart: 64 замены, все суставы на мешах, 40 точек
FX на прежних местах. Фитиль Треснувшего, глаза и трещины остаются Part.

## Проверка после импорта

* В Play враги выглядят как `out/preview.png`.
* Если деталь отражена или повёрнута (у стрелка ремень колчана должен идти
  к его правому плечу, у стража — поля шлема спереди с наносником) — значит,
  импорт повернул оси glTF. Сообщить, генератор поправит одной строкой.

## Если правите сетки

`armor.json` → `build_armor.py` → переимпортировать `enemy_armor.glb`
(старую модель удалить из `EnemyArmorMeshes`) → пересобрать заглушки
(`build_enemy_prefabs.lua`) → `apply_armor_meshes.lua` → Ctrl+S.

## Объёмные враги (пакет Enemies3D, 23.10.2026)

Пакет приходит как `<id>_armor.obj` ×8. OBJ импортёр Studio сливает в одну
MeshPart `default` — поэтому сначала конвертация в один glb (узел = деталь):

1. `python tools/enemy-armor/obj_to_glb.py <папка export пакета> tools/enemy-armor/out3d/enemies3d.glb`
   (поворот glTF на 180° уже компенсирован в вершинах, палитра встроена).
2. Префабы: `node tools/import-rbxmx.js <export>/EnemyPrefabs.rbxmx --into ReplicatedStorage`.
3. `EnemyArmorData.luau` → `src/ReplicatedStorage/Shared/Config/`.
4. Import 3D → `enemies3d.glb`, ничего не менять, модель оставить в Workspace.
5. `node C:\Users\artem\.dsh-roblox\s.js exec tools/lua/assemble_enemies3d.lua Edit`
   → «поставлено: 179, не найдено: 0, импорт удалён». Палитру скрипт берёт с
   импорта; вписать её id в `paletteTexture` конфига. → Ctrl+S.
