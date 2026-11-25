# Связка VS Code + Claude Code + Roblox Studio

## Что уже готово (сделано автоматически)

| Что | Состояние |
|---|---|
| VS Code | установлен, 1.142.0, проект открыт (`File → Open Folder` → `C:\Users\artem\KlinokPamyati`) |
| Расширение Claude Code | установлено: `anthropic.claude-code` |
| MCP-сервер для Claude | `tools/roblox-mcp.js` + `.mcp.json` в корне проекта |
| Мост до Studio | `tools/studio-bridge.js`, поднимается сам при первом обращении Claude |
| Studio | открыта с `KlinokPamyati123.rbxl`, MCP включён (мост её видит) |

Проверка связки без Claude (её можно повторить в любой момент):

```
node tools\test-mcp.js
```

Ожидаемый вывод: `initialize -> ...`, `tools/list -> 29 инструментов ...`,
`tools/call bridge_status -> { "ok": true, "studios": [ { "name": "KlinokPamyati123.rbxl" } ] }`.

## Что нужно сделать руками

### 1. Войти в Claude в VS Code

Иконка Claude на левой панели → вход в аккаунт Anthropic.
Веб-версия Claude Code и расширение — разные сессии: вход в браузере не
переносится, нужен вход именно в расширении.

### 2. Включить Script Sync (бета) в Studio

`File → Beta Features → Script Sync` → перезапустить Studio.
Затем в Explorer правой кнопкой по сервису → `Script Sync → Sync to Folder…`
и указать папку:

| Сервис в Studio | Папка проекта |
|---|---|
| `ServerScriptService` | `C:\Users\artem\KlinokPamyati\src\ServerScriptService` |
| `ReplicatedStorage` | `C:\Users\artem\KlinokPamyati\src\ReplicatedStorage` |
| `StarterPlayer → StarterPlayerScripts` | `C:\Users\artem\KlinokPamyati\src\StarterPlayer\StarterPlayerScripts` |

Важно: указывать именно эти папки, а не корень проекта — иначе Studio создаст
лишние папки `src`, `tools`, `docs` внутри сервисов.

Расширения файлов уже подходят: `.server.lua` → Script, `.client.lua` →
LocalScript, `.lua` → ModuleScript.

### 3. Перезапустить VS Code и разрешить MCP

После перезапуска VS Code прочитает `.mcp.json` и спросит разрешение на сервер
`roblox-studio` — разрешить. Затем в чате Claude Code:

```
Use the roblox-studio MCP tool bridge_status and list what's in game.Workspace
```

Если в ответе `KlinokPamyati123.rbxl` и дерево объектов — связка работает.

## Как это устроено

```
Claude Code (VS Code)
   │  MCP по stdio
   ▼
tools/roblox-mcp.js   ← этот файл Claude запускает сам
   │  если мост не запущен — поднимает его
   ▼
tools/studio-bridge.js → StudioMCP.exe → Roblox Studio
   │  HTTP 127.0.0.1:8799
```

Инструменты Studio Claude получает как обычные MCP-инструменты:
`execute_luau`, `start_stop_play`, `get_console_output`, `script_read`,
`multi_edit`, `search_game_tree` и остальные (всего 29).

## Сеть: почему расширение не могло войти (и как исправлено)

Симптом: `connect ECONNREFUSED 160.79.104.10:443` на экране входа.

Что выяснилось:

| Проверка | Результат |
|---|---|
| DNS `api.anthropic.com`, `claude.ai`, `claude.com` | все → `160.79.104.10` |
| Прямой TCP на `160.79.104.10:443` | отказ (curl — таймаут) |
| Локальный прокси `127.0.0.1:10809` | работает, туннель `CONNECT api.anthropic.com:443` → 200 |
| Через прокси `curl` к Anthropic | `api.anthropic.com` → 405, `claude.ai` → 302 |
| Выходной IP прокси | `140.225.209.170`, Франкфурт (DE) |

Причина: системный прокси включён (`ProxyEnable=1`, `127.0.0.1:10809`), но VS Code и
Claude Code его не использовали и шли напрямую на заблокированный IP.

Что настроено:

1. `%APPDATA%\Code\User\settings.json`:
   `"http.proxy": "http://127.0.0.1:10809"`, `"http.proxySupport": "on"`,
   `"http.proxyStrictSSL": true`.
2. Пользовательские переменные окружения: `HTTPS_PROXY` и `HTTP_PROXY` =
   `http://127.0.0.1:10809`, `NO_PROXY` = `localhost,127.0.0.1,::1`
   (важно: локальный адрес моста не должен уходить в прокси).
3. VS Code полностью перезапущен — новые переменные подхватываются только при
   старте процесса.

Проверено после перезапуска: в логе расширения
`MCP server "roblox-studio": Connection established ... "hasTools":true`,
ошибок `ECONNREFUSED` нет; встроенный CLI отвечает `2.1.301 (Claude Code)` и
доходит до «Not logged in · Please run /login», то есть сеть в порядке.

Важно: прокси-клиент и VPN не изменялись. Браузер и VS Code выходят одним и тем
же IP (Германия), поэтому вход в аккаунт идёт с одного адреса. Не меняй регион
VPN во время входа — разные IP на одном аккаунте как раз и вызывают подозрения.



| Симптом | Что делать |
|---|---|
| `Studio не подключена к мосту` | открой плейс в Studio и проверь Assistant → ⋯ → Manage MCP Servers → Enable Studio as MCP server |
| `мост не поднялся` | закрой лишние окна Studio, запусти `node tools\studio-bridge.js` вручную и посмотри `tools\bridge.log` |
| Claude не видит `roblox-studio` | VS Code → Settings → MCP: проверь, что `.mcp.json` в корне открытой папки, затем `Developer: Reload Window` |
| Script Sync молчит | перезапусти Studio после включения беты; проверь, что папка синхронизации не корень проекта |

Логи: `tools\bridge.log` (мост и Studio), `tools\mcp.log` (MCP-обмен с Claude).

## Правила работы

* Скрипты правятся в файлах, Studio получает их через Script Sync.
* Ручная синхронизация (если Script Sync выключен): `node tools\sync.js`
  (диск → DataModel, односторонне).
* Перед Playtest сохраняй плейс (`Ctrl+S`), иначе правки останутся только в
  памяти сессии.
