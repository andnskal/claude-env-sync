@echo off
REM ============================================================
REM   더블클릭 한 번으로 GitHub repo에서 최신 환경을 받아와
REM   이 PC에 복원합니다.
REM ============================================================

setlocal
cd /d "%~dp0"

echo.
echo ============================================================
echo   Claude Env Sync - PULL (GitHub -^> 이 PC)
echo ============================================================
echo.

powershell -ExecutionPolicy Bypass -NoProfile -Command ^
  "& { Write-Host '→ git pull 진행' -ForegroundColor Cyan; git pull; if ($LASTEXITCODE -eq 0) { Write-Host ''; .\import.ps1 } else { Write-Host '✗ git pull 실패' -ForegroundColor Red } }"

echo.
echo ============================================================
echo   완료. 아무 키나 누르면 창이 닫힙니다.
echo ============================================================
pause >nul
