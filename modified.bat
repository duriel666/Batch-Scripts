@echo off
setlocal enabledelayedexpansion

REM Filetype to modify
set "ext=mp4"

REM Loop through all files in current folder with the specified extension
for %%F in ("*.!ext!") do (
    REM Extract year, month and day from filename formatted as "(2024-08-19) something.mp4"
    set "filename=%%~nF"

    REM set "month=!filename:~6,2!" start from index 6 and get 2 characters
    set "year=!filename:~1,4!"
    set "month=!filename:~6,2!"
    set "day=!filename:~9,2!"

    REM set "hour=!filename:~12,2!"
    REM set "minute=!filename:~15,2!"
    REM set "second=!filename:~18,2!"

    echo modifying file !filename!.!ext!
    powershell -command "(Get-Item '!filename!.!ext!').LastWriteTime = '!year!-!month!-!day! 12:00:00'"
    REM powershell -command "(Get-Item '!filename!.!ext!').LastWriteTime = '!year!-!month!-!day! !hour!:!minute!:!second!'"
)

echo Done
endlocal
