@echo off
setlocal enabledelayedexpansion

REM Convert .mkv first in to a clean .mp4 and 3D frame sequential to a side-by-side
REM Usage: just run in folder

pushd %~dp0 || (
    echo Error: Could not map the UNC path
    pause
    exit /b 1
)

echo Directory: %cd%

for %%F in (*.mp4) do (
    echo Converting file %%F ...
    ffmpeg -y -i "%%~nF.mp4" -vf "stereo3d=al:sbsl,format=yuv420p" -c:v av1_nvenc -b:v 3000k -preset p7 -rc vbr -c:a copy -metadata:s:v stereo_mode=1 "%%~nF 3D-SBS.mp4"
)

echo Done
endlocal
