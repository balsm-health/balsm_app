@echo off
rem Balsm CLI (Windows) — same entry point as bin/balsm: wraps tool/build.dart.
rem Uses fvm when installed, plain dart otherwise.
setlocal
cd /d "%~dp0.."
set "RUNNER=dart"
if exist .fvmrc where fvm >nul 2>nul && set "RUNNER=fvm dart"
%RUNNER% run tool\build.dart %*
exit /b %errorlevel%
