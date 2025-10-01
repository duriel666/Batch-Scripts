@echo off
setlocal enabledelayedexpansion

REM 3D frame sequential .mkv to side-by-side .mp4
REM Usage: just run in folder

pushd %~dp0 || (
    echo Error: Could not map the UNC path
    pause
    exit /b 1
)

echo Directory: %cd%

for %%F in (*.mkv) do (
    echo Converting file %%F ...
    ffmpeg -y -analyzeduration 100M -probesize 100M -i "%%F" -map 0:v:0 -map 0:a:0 -c:v copy -c:a copy "%%~nF clean.mp4"
    ffmpeg -y -i "%%~nF clean.mp4" -vf "stereo3d=al:sbsl,format=yuv420p" -c:v av1_nvenc -b:v 3000k -preset p7 -rc vbr -c:a copy -metadata:s:v stereo_mode=1 "%%~nF 3D-SBS.mp4"
    del "%%~nF clean.mp4"
)

echo Done
endlocal
