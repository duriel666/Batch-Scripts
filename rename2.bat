@echo off
setlocal enabledelayedexpansion

REM Filetype to rename
set "ext=mkv"

REM Loop through all files in current folder with the specified extension
for %%F in ("*.!ext!") do (
    set "filename=%%~nF"

    REM Extract year, month and day from filename formatted as "(2024-08-19) something.mkv"
    REM set "month=!filename:~6,2!" start from index 6 and get 2 characters
    set "year=!filename:~0,4!"
    set "month=!filename:~4,2!"
    set "day=!filename:~6,2!"
    set "newname=(!year!-!month!-!day!) something%%~xF"

    echo modifying file !filename!.!ext!
    echo !newname!
    ren "%%F" "!newname!"
)

echo Done
endlocal
