@echo off
REM ============================================================
REM   집 PC 첫 셋업 — 더블클릭 한 번으로 자동 진행
REM   (GitHub repo 자동 생성 + 환경 백업 + 첫 push)
REM ============================================================

setlocal
cd /d "%~dp0"

echo.
echo ============================================================
echo   Claude Env Sync - INIT (집 PC 첫 셋업)
echo ============================================================
echo.

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0init.ps1"
