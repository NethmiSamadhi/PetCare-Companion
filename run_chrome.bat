@echo off
setlocal
cd /d "%~dp0"
set "PETCARE_FLUTTER=D:\flutter\bin\flutter.bat"
if not exist "%PETCARE_FLUTTER%" (
  echo Edit PETCARE_FLUTTER in this file to your Flutter SDK path.
  pause
  exit /b 1
)
call "%PETCARE_FLUTTER%" run -d chrome --web-port 7357
pause
