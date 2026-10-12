@echo off
setlocal
cd /d "%~dp0"
set "PETCARE_FLUTTER=D:\flutter\bin\flutter.bat"
if not exist "%PETCARE_FLUTTER%" (
  echo Flutter was not found at D:\flutter\bin\flutter.bat.
  echo Edit PETCARE_FLUTTER in this file to your Flutter SDK path.
  pause
  exit /b 1
)
call "%PETCARE_FLUTTER%" pub get
if errorlevel 1 goto failed
call "%PETCARE_FLUTTER%" analyze
if errorlevel 1 goto failed
call "%PETCARE_FLUTTER%" test
if errorlevel 1 goto failed
echo Setup complete. Open run_chrome.bat to start the app.
pause
exit /b 0
:failed
echo Setup failed. Read the error above before continuing.
pause
exit /b 1
