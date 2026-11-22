@echo off
setlocal
rem Ergonomic umbrella entry point: forward all args to the safe-release script under build\.
call "%~dp0build\vento-unified-safe-release.bat" %*
exit /b %ERRORLEVEL%
