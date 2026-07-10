@echo off
setlocal
cd /d "%~dp0"

if not exist "input" mkdir "input"
if not exist "output" mkdir "output"

where docker >nul 2>nul
if errorlevel 1 (
  echo Docker was not found. Start or install Docker Desktop first.
  set "STATUS=1"
  goto :finish
)

echo Converting Markdown files in input\ ...
docker compose run --build --rm md2docx
set "STATUS=%ERRORLEVEL%"

:finish
echo.
if "%STATUS%"=="0" (
  echo Finished. Converted files are in output\.
) else (
  echo Conversion failed ^(exit code: %STATUS%^).
)
echo.
pause
exit /b %STATUS%
