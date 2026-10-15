@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

set "SCRIPT_DIR=%~dp0"
set "WALLPAPER_DIR=%SCRIPT_DIR%wallpapers"

echo.
echo ==========================================
echo          RANDOM WALLPAPER
echo ==========================================
echo.

if not exist "%WALLPAPER_DIR%\" (
    echo [ОШИБКА] Не найдена папка:
    echo   %WALLPAPER_DIR%
    pause
    exit /b 1
)

echo Папка с обоями:
echo   %WALLPAPER_DIR%
echo.

set "LIST_FILE=%TEMP%\rw_list_%RANDOM%_%RANDOM%.txt"
del "%LIST_FILE%" 2>nul

for %%F in (
    "%WALLPAPER_DIR%\*.jpg"
    "%WALLPAPER_DIR%\*.jpeg"
    "%WALLPAPER_DIR%\*.png"
    "%WALLPAPER_DIR%\*.webp"
    "%WALLPAPER_DIR%\*.bmp"
) do (
    if exist "%%~F" echo %%~F>>"%LIST_FILE%"
)

set /a COUNT=0
for /f "usebackq delims=" %%F in ("%LIST_FILE%") do set /a COUNT+=1

if %COUNT% EQU 0 (
    echo [ОШИБКА] В папке wallpapers нет изображений.
    del "%LIST_FILE%" 2>nul
    pause
    exit /b 1
)

echo Найдено изображений: %COUNT%
echo.

set /a RIDX=%RANDOM% %% COUNT
set /a CUR=0
set "SELECTED="
for /f "usebackq delims=" %%F in ("%LIST_FILE%") do (
    if !CUR! EQU %RIDX% set "SELECTED=%%F"
    set /a CUR+=1
)
del "%LIST_FILE%" 2>nul

if not defined SELECTED (
    echo [ОШИБКА] Не удалось выбрать изображение.
    pause
    exit /b 1
)

echo Выбрано:
echo   %SELECTED%
echo.

echo Сканирую локальные диски...
set "DRIVES_FILE=%TEMP%\rw_drives_%RANDOM%_%RANDOM%.txt"
del "%DRIVES_FILE%" 2>nul

powershell.exe -NoProfile -Command "Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | ForEach-Object { $_.DeviceID }" >"%DRIVES_FILE%" 2>nul

set /a DCOUNT=0
for /f "usebackq delims=" %%D in ("%DRIVES_FILE%") do set /a DCOUNT+=1

set "TARGET_DIR="
if %DCOUNT% GTR 0 (
    echo Найдено локальных дисков: %DCOUNT%
    set /a DIDX=%RANDOM% %% DCOUNT
    set /a DCUR=0
    set "PICK="
    for /f "usebackq delims=" %%D in ("%DRIVES_FILE%") do (
        if !DCUR! EQU %DIDX% set "PICK=%%D"
        set /a DCUR+=1
    )
    if defined PICK (
        set "TRY1=!PICK!\.random-wallpaper-%USERNAME%"
        if not exist "!TRY1!" mkdir "!TRY1!" >nul 2>&1
        if exist "!TRY1!" set "TARGET_DIR=!TRY1!"
    )
) else (
    echo Локальные диски не обнаружены.
)
del "%DRIVES_FILE%" 2>nul

if not defined TARGET_DIR (
    set "TARGET_DIR=%USERPROFILE%\.cache\random-wallpaper"
    if not exist "!TARGET_DIR!" mkdir "!TARGET_DIR!" >nul 2>&1
    echo Фолбэк-папка: !TARGET_DIR!
)

attrib +h "%TARGET_DIR%" >nul 2>&1

echo Папка назначения:
echo   %TARGET_DIR%
echo.

for %%F in ("%SELECTED%") do set "EXT=%%~xF"

set "TARGET_FILE=%TARGET_DIR%\random-wallpaper-%RANDOM%-%RANDOM%%EXT%"

copy /Y "%SELECTED%" "%TARGET_FILE%" >nul
if errorlevel 1 (
    echo [ОШИБКА] Не удалось скопировать файл.
    pause
    exit /b 1
)

echo Скопировано в:
echo   %TARGET_FILE%
echo.
echo Устанавливаю обои...

reg add "HKCU\Control Panel\Desktop" /v Wallpaper /t REG_SZ /d "%TARGET_FILE%" /f >nul 2>&1
if errorlevel 1 (
    echo [ОШИБКА] Не удалось записать настройки реестра.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p='%TARGET_FILE%'; $w=Add-Type -MemberDefinition '[DllImport(\"user32.dll\",CharSet=CharSet.Auto)] public static extern int SystemParametersInfo(int a,int b,string c,int d);' -Name W -Namespace X -PassThru; $w::SystemParametersInfo(20,0,$p,3) | Out-Null"

for /f "usebackq delims=" %%V in (`powershell.exe -NoProfile -Command "(Get-ItemProperty 'HKCU:\Control Panel\Desktop').Wallpaper"`) do set "REG_NOW=%%V"
echo Реестр сейчас: !REG_NOW!
echo.

for %%F in (
    "%TARGET_DIR%\random-wallpaper-*.jpg"
    "%TARGET_DIR%\random-wallpaper-*.jpeg"
    "%TARGET_DIR%\random-wallpaper-*.png"
    "%TARGET_DIR%\random-wallpaper-*.webp"
    "%TARGET_DIR%\random-wallpaper-*.bmp"
) do (
    if /i not "%%~fF"=="%TARGET_FILE%" del "%%~F" >nul 2>&1
)

echo ==========================================
echo              ГОТОВО!
echo ==========================================
echo.
echo Файл:
echo   %TARGET_FILE%
echo.
pause
exit /b 0