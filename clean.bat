@echo off
setlocal enabledelayedexpansion

REM Clean .mp4 from .mkv for additional converting
REM Usage: just run in folder

pushd %~dp0 || (
    echo Error: Could not map the UNC path
    pause
    exit /b 1
)

echo Directory: %cd%

for %%F in (*.mkv) do (
    echo Converting file %%F ...
    ffmpeg -y -analyzeduration 100M -probesize 100M -i "%%F" -map 0:v:0 -map 0:a:0 -c:v copy -c:a copy "%%~nF.mp4"
)

echo Done
popd
endlocal
