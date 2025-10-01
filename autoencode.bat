@echo off
setlocal enabledelayedexpansion

REM calculates bitrate for video and audio streams
REM converts files with calculated values to av1 encoded mkv files in a folder
REM Usage: just run in folder

pushd "%~dp0" || (
    echo Error: Could not map the UNC path
    pause
    exit /b 1
)

REM Set filetype and 1080p bitrate
set "filetype=mp4"
set "1080p=600"
mkdir new
echo Processing all %filetype% files...

for %%F in (*.%filetype%) do (
    echo Checking file %%F ...

    rem Get resolution as WidthxHeight (1920x1080)
    rem ffprobe -v error -show_entries stream=width,height,channels -of default=noprint_wrappers=1 "%%F" > tmp.txt
    ffprobe -v error -select_streams v:0 -show_entries stream=width,height,channels -of csv=p=0:s=x "%%F" > video.txt

    rem Read it back and split into width and height
    for /f "usebackq tokens=1,2 delims=x" %%W in ("video.txt") do (
        set /a pixels=%%W * %%X /1000
        echo %%W x %%X
    )
    ffprobe -v error -select_streams a:0 -show_entries stream=channels -of csv=p=0:s=x "%%F" > audio.txt
    for /f "usebackq tokens=1 delims=x" %%C in ("audio.txt") do (
        set channels=%%C
        echo Audio channels: !channels!
    )
    if "!channels!"=="1" set "audiobitrate=56"
    if "!channels!"=="2" set "audiobitrate=80"
    if "!channels!"=="3" set "audiobitrate=112"
    if "!channels!"=="4" set "audiobitrate=128"
    if "!channels!"=="5" set "audiobitrate=160"
    if "!channels!"=="6" set "audiobitrate=192"
    if "!channels!"=="7" set "audiobitrate=224"
    if "!channels!"=="8" set "audiobitrate=256"

    set /a videopercentage=pixels * !1080p! / 2073
    echo Video percentage: !videopercentage!k
    echo Audio bitrate: !audiobitrate!k

    ffmpeg -i "%%F" -c:v av1_nvenc -b:c !videopercentage!k -preset p7 -c:a libopus -b:a !audiobitrate!k "!folder!\%%~nF.mkv"
)

echo Done
endlocal
