@echo off
setlocal enabledelayedexpansion

REM Filetype to modify
set "ext=mp4"

REM Loop through all files in current folder with the specified extension
for %%F in ("*.!ext!") do (
    REM Extract year, month and day from filename formatted as "(2024-08-19) something.mp4"
    set "filename=%%~nF"
    set "year=!filename:~1,4!"
    set "month=!filename:~6,2!"
    set "day=!filename:~9,2!"

    echo modifying file !filename!.!ext!
    powershell -command "(Get-Item '!filename!.!ext!').LastWriteTime = '!year!-!month!-!day!'"
)

echo Done
