# Rojo: автосинхронизация файлов в Studio

## Что установлено

| Компонент | Где |
|---|---|
| Rojo CLI 7.7.1 | `tools\rojo\rojo.exe` |
| Плагин Studio | `%LOCALAPPDATA%\Roblox\Plugins\Rojo.rbxm` |
| Проект | `default.project.json` в корне |
| Сервер синхронизации | `rojo serve`, порт `34872`, PID смотри ниже |

Проверка, что сервер жив:

```powershell
curl.exe --noproxy "*" http://127.0.0.1:34872/api/rojo
```

Ответ должен содержать `"projectName":"KlinokPamyati"`.

## Как включить синхронизацию (один раз за сессию Studio)

1. Перезапустить Studio — плагин подхватывается только при старте.
2. Открыть `KlinokPamyati123.rbxl`.
3. На панели плагинов нажать **Rojo** → **Connect** (адрес по умолчанию
   `localhost:34872`).
4. После подключения правки файлов в VS Code попадают в Studio в реальном
   времени, без `sync.js` и без Script Sync.

## Что синхронизируется

| Папка на диске | Куда в Studio |
|---|---|
| `src\ReplicatedStorage` | `ReplicatedStorage.Shared` |
| `src\ServerScriptService` | `ServerScriptService` (Bootstrap, Systems, Hub) |
| `src\StarterPlayer\StarterPlayerScripts` | `StarterPlayer.StarterPlayerScripts` |

Остальные сервисы Rojo не трогает.

## Защита от потери объектов

В Studio есть объекты, которых нет на диске, и они нужны игре:

* `ReplicatedStorage.EnemyPrefabs` — используется `EnemyVisualController`;
* `ReplicatedStorage.HubAccessories` — используется `VillagerService`.

Поэтому у сервисов в `default.project.json` стоит
`"$ignoreUnknownInstances": true`: Rojo обновляет то, что пришло с диска, и
**не удаляет** остальное. Без этого флага Connect стёр бы обе папки.

## Правила совместимости

* **Не включать одновременно Script Sync** — два разных механизма будут
  перезаписывать друг друга.
* **Не запускать `tools\sync.js`**, пока работает Rojo: он делает то же самое
  другим способом.
* MCP-мост (`tools\roblox-mcp.js`) работает независимо: Rojo синхронизирует
  файлы, MCP даёт агенту выполнять код и запускать Play.
* Rojo — односторонний: диск → Studio. Обратно (Studio → диск) ничего не
  пишется, поэтому правки в Studio нужно либо переносить в файлы вручную, либо
  не делать их вовсе.

## Запуск и остановка сервера

```powershell
# запустить (как отдельный процесс, переживает закрытие VS Code)
Start-Process -FilePath "tools\rojo\rojo.exe" -ArgumentList "serve","default.project.json" -WorkingDirectory "C:\Users\artem\KlinokPamyati" -WindowStyle Hidden

# остановить
Get-NetTCPConnection -LocalPort 34872 -State Listen | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }
```

`Запуск.bat` поднимает Studio и VS Code; при необходимости добавь туда же
запуск Rojo — скажи, и впишу.

## Если что-то не так

| Симптом | Причина / действие |
|---|---|
| В Studio нет панели Rojo | плагин не загрузился: перезапусти Studio; проверь `%LOCALAPPDATA%\Roblox\Plugins\Rojo.rbxm` |
| Connect не подключается | сервер не запущен: проверь порт 34872 командой выше |
| Скрипты не обновляются | проверь путь в проекте: файлы должны лежать в `src\...`, как в таблице |
| Пропали объекты в Studio | значит sync шёл без `$ignoreUnknownInstances`; верни объекты из копии плейса |
