@echo off
setlocal enabledelayedexpansion

REM calculates bitrate for video and audio streams
REM convert set filetypes with calculated values to av1_nvec/opus mkv files in set folder
REM Usage: just run in folder

REM Set filetype and 1080p bitrate (bitrate is set value + 200)
set "filetypes=mp4 mkv avi mov wmv mpg mpeg"
set "1080p=400"
set "folder=new"

pushd "%~dp0" || (
    echo Error: Could not map the UNC path
    pause
    exit /b 1
)

mkdir "%folder%" 2>nul
echo Processing all %filetypes% files...

for %%E in (%filetypes%) do (
    set "ext=%%~xF"
    set "ext=!ext:~1!"
    for %%F in (*%%E) do (
        echo Checking file %%F ...

        rem Get resolution as WidthxHeight (1920x1080)
        ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "%%F" > video.txt

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

        set /a videobitrate=pixels * !1080p! / 2073 + 200
        echo Video bitrate: !videobitrate!k
        echo Audio bitrate: !audiobitrate!k

        ffmpeg -i "%%F" -c:v av1_nvenc -b:v !videobitrate!k -preset p7 -c:a libopus -b:a !audiobitrate!k "!folder!\%%~nF.mkv"
    )
)

del video.txt audio.txt 2>nul
echo Done
endlocal
pause
