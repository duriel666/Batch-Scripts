@echo off
setlocal enabledelayedexpansion

REM Usage: just run in folder

pushd %~dp0 || (
    echo Error: Could not map the UNC path
    pause
    exit /b 1
)

echo Directory: %cd%

for %%F in (*.mp4) do (
    echo Converting file %%F ...
    ffmpeg -i "%%F" -c copy "%%~nF.mkv"
)

echo Done
popd
endlocal
