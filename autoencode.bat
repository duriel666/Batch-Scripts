@echo off
setlocal enabledelayedexpansion

REM calculates bitrate for video and audio streams
REM convert set filetypes with calculated values to av1_nvec/opus mkv files in set folder
REM Usage: just run in folder

REM Set filetype and 1080p bitrate (bitrate is set value + 150)
set "filetypes=mp4 mkv avi mov wmv mpg mpeg"
set "1080p=450"
set "folder=new"
set "folder2=old"

pushd "%~dp0" || (
    echo Error: Could not map the UNC path
    pause
    exit /b 1
)

mkdir "!folder!" 2>nul
mkdir "!folder2!" 2>nul
echo Processing all %filetypes% files...

REM Check for libopus support
ffmpeg -encoders | findstr /C:"libopus" > nul
if errorlevel 1 (
    set "audio_codec=libvorbis"
    echo Warning: libopus not supported, falling back to libvorbis
) else (
    set "audio_codec=libopus"
)

for %%E in (%filetypes%) do (
    for %%F in (*%%E) do (
        echo Checking file %%F ...
        set "audio_opts="
        set "audio_maps=-map 0:a"
        set "subtitle_maps="

        REM Get video resolution
        ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "%%F" > video.txt
        if errorlevel 1 (
            echo Error: ffprobe failed to get video info for %%F
            goto :cleanup
        )
        for /f "usebackq tokens=1,2 delims=x" %%W in ("video.txt") do (
            set /a pixels=%%W * %%X / 1000
            set width=%%W
            set height=%%X
        )
        set /a videobitrate=pixels * !1080p! / 2073 + 150

        REM Get audio stream details
        ffprobe -v error -select_streams a -show_entries stream=index,channels,codec_name -of csv=p=0 "%%F" > audio.txt
        if errorlevel 1 (
            echo Error: ffprobe failed to get audio info for %%F
            goto :cleanup
        )
        set "audio_count=0"
        set "audio_opts="
        for /f "tokens=1,2,3 delims=," %%I in (audio.txt) do (
            set "idx=%%I"
            set "codec=%%J"
            set "channels=%%K"

            REM Bitrate table
            if "!channels!"=="1" set "ab=56"
            if "!channels!"=="2" set "ab=80"
            if "!channels!"=="3" set "ab=112"
            if "!channels!"=="4" set "ab=128"
            if "!channels!"=="5" set "ab=160"
            if "!channels!"=="6" set "ab=192"
            if "!channels!" geq "7" (
                set "ab=192"
                set "downmix=-ac 6"
            ) else (
                set "downmix="
            )

            set "current_opts=-c:a:!audio_count! !audio_codec! !downmix! -b:a:!audio_count! !ab!k"
            set "audio_opts=!audio_opts! !current_opts!"
            set /a audio_count+=1
        )

        REM Check for subtitle streams with language tags
        ffprobe -v error -select_streams s -show_entries stream=index:stream_tags=language -of csv=p=0 "%%F" > subtitles.txt
        set "subtitle_maps="
        set /a s_ord=0
        for /f "tokens=1,2 delims=," %%I in (subtitles.txt) do (
            set "idx_global=%%I"
            set "lang=%%J"
            if /i "!lang!"=="eng" (
                set "subtitle_maps=!subtitle_maps! -map 0:s:!s_ord!"
            ) else if /i "!lang!"=="fin" (
                set "subtitle_maps=!subtitle_maps! -map 0:s:!s_ord!"
            )
            set /a s_ord+=1
        )

        REM Encode
        echo Encoding %%F with command:
        echo ffmpeg -y -analyzeduration 1000M -probesize 1000M -i "%%F" -map 0:v !audio_maps! !subtitle_maps! -c:v av1_nvenc -b:v !videobitrate!k -preset slow -tune uhq -multipass 2 -pix_fmt p010le -profile:v main10 -rc vbr !audio_opts! -c:s copy -f matroska "!folder!\%%~nF.mkv"
        ffmpeg -y -analyzeduration 1000M -probesize 1000M -i "%%F" -map 0:v !audio_maps! !subtitle_maps! -c:v av1_nvenc -b:v !videobitrate!k -preset slow -tune uhq -multipass 2 -pix_fmt p010le -profile:v main10 -rc vbr !audio_opts! -c:s copy -f matroska "!folder!\%%~nF.mkv"
        if errorlevel 1 (
            echo Error in encoding for %%F
            goto :cleanup
        )

        move "%%F" "!folder2!" 2>nul

        echo Resolution: !width! x !height!
        echo Video: !videobitrate!k
        echo Audio: !audio_opts!
        echo Subtitles: !subtitle_maps!
    )
)

:cleanup
del video.txt audio.txt subtitles.txt 2>nul
echo Done
popd
endlocal
exit /b 0
