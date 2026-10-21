@echo off
setlocal
cd /d "%~dp0"
echo.
echo ================================================
echo          GiftExpress - Vista de prueba
 echo ================================================
echo.
echo No abras index.html desde el Explorador.
echo Este archivo levanta un servidor local.
echo.
where py >nul 2>nul
if %errorlevel%==0 (
  start "" "http://localhost:8765/"
  py -3 -m http.server 8765 --bind 127.0.0.1
  goto end
)
where python >nul 2>nul
if %errorlevel%==0 (
  start "" "http://localhost:8765/"
  python -m http.server 8765 --bind 127.0.0.1
  goto end
)
echo No se encontro Python instalado.
echo Instala Python desde https://www.python.org/downloads/
echo Activa "Add python.exe to PATH" durante la instalacion.
echo Alternativamente publica el contenido en Netlify.
pause
:end
