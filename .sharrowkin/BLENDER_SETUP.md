# Окружение рендера оружия

Установлен Blender 4.2.16 LTS:
`C:\Program Files\Blender Foundation\Blender 4.2\blender.exe`

Встроенный Python 3.11.7: bpy, mathutils, NumPy 1.24.3.
Pillow 11.3.0 установлен в `.sharrowkin/blender-deps` и подключается через `.sharrowkin/scripts/blender_project.py`.
В существующем Python 3.14 также доступны NumPy и Pillow; повторно не устанавливались.

## Проверенный рендер существующего OBJ
Из корня проекта:
```bat
"C:\Program Files\Blender Foundation\Blender 4.2\blender.exe" -b --python-exit-code 1 -P .sharrowkin/scripts/blender_project.py -- tools/weapons/render_sheet.py C:/Users/artem/KlinokPamyati/tools/weapons/floor2-assets/weapons_floor2.obj .sharrowkin/floor2-render-check.png iso 4
uv run --no-project --python C:/Users/artem/AppData/Local/Python/pythoncore-3.14-64/python.exe python tools/weapons/compose_sheet.py .sharrowkin/floor2-render-check.png
```
OBJ передавать абсолютным путём: при относительном Blender не нашёл текстуру палитры. Для сравнения сохранить независимые исходные и новые экспорты, использовать одинаковые ракурс, свет, порядок и масштаб. Обёртка предназначена для render_sheet.py и других скриптов, читающих аргументы после `--`, а не для export_weapons*.py.

## Повторение для сравнения «до/после»
Для каждого независимого экспорта используйте команду рендера выше, заменяя абсолютный путь OBJ на нужный экспорт, а выходной файл — на `.sharrowkin/floor2-before.png` или `.sharrowkin/floor2-after.png`. Затем склейте соответствующий лист:
```bat
skpy tools/weapons/compose_sheet.py .sharrowkin/floor2-before.png
skpy tools/weapons/compose_sheet.py .sharrowkin/floor2-after.png
```
Не запускайте обе версии рендера в один выходной файл. Склейку выполняйте сразу после рендера: отдельные кадры хранятся во временной папке Windows. Сами итоговые PNG остаются в проекте. Это команды для будущих экспортов, а не свидетельство готового сравнения.

## Проверка после возобновления задачи
Blender подтвердил `RENDER_DEPS_OK 4.2.16 LTS 1.24.3 11.3.0` (Blender / NumPy / Pillow); импорты bpy и mathutils успешны. Повторный рендер сохранил все 8 кадров этажа 2 и загрузил текстуру палитры. Для склейки также подходит встроенный `skpy`, без дополнительной установки Python.

## Ограничения
Пробный лист существующего OBJ второго этажа — проверка окружения, не исходный лист всех актуальных генераторов и не сравнение до/после. Рендер содержит существующие glow-объекты; эффекты Roblox им не проверяются.
В экспортёрах есть вызов `vox.to_blender` для сохранения .blend; установка зависимостей не исправляет отсутствие функции в исходниках. Перед полным экспортом нужно отдельно устранить этот дефект пайплайна. Игровые исходники, модели и FX при установке не изменялись.
