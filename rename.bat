@echo off
setlocal enabledelayedexpansion

REM Usage: rename.bat old new
REM file_old.txt -> file_new.txt

set "from=%1"
set "to=%2"

for %%F in (*.txt) do (
    set "filename=%%~nF"
    set "newname=!filename:%from%=%to%!"
    if not "!filename!"=="!newname!" (
        echo renaming file !filename! to !newname!
        ren "%%F" "!newname!%%~xF"
    )
)

echo Done
endlocal
