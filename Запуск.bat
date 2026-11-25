@echo off
setlocal
cd /d "%~dp0"

echo ============================================
echo   Klinok Pamyati - start work session
echo ============================================
echo.
echo   1) Roblox Studio + KlinokPamyati123.rbxl
echo   2) VS Code with the project folder
echo   3) check Claude - Studio bridge
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\start-dev.ps1"

echo.
echo --------------------------------------------
echo If Studio is not connected:
echo   open the place and enable MCP in Assistant
echo   (Assistant - Manage MCP Servers - Enable Studio as MCP server)
echo.
echo Claude chat: left Claude icon -^> Sessions -^> top session.
echo Before closing Studio press Ctrl+S.
echo --------------------------------------------
echo.
pause
