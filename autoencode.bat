@echo off
setlocal enabledelayedexpansion

REM calculates bitrate for video and audio streams
REM convert set filetypes with calculated values to av1_nvec/opus mkv files in set folder
REM Usage: just run in folder

REM Set filetype and 1080p bitrate (bitrate is set value + 150)
set "filetypes=mp4 mkv avi mov wmv mpg mpeg"
set "anchor_bitrate=450"
set "folder=new"
set "folder2=old"

pushd "%~dp0" || (
    echo Error: Could not map the UNC path
    pause
    exit /b 1
)

mkdir "%folder%" 2>nul
mkdir "%folder2%" 2>nul
echo Processing all -%filetypes%- files...

REM Check for libopus support
ffmpeg -encoders | findstr /C:"libopus" >nul
if errorlevel 1 (
    set "audio_codec=libvorbis"
    echo Warning: libopus not supported, falling back to libvorbis
) else (
    set "audio_codec=libopus"
)

REM Loop over filetypes and files
for %%E in (%filetypes%) do (
    for %%F in (*.%%E) do (
        call :process_file "%%F"
    )
)
goto :cleanup

:process_file
set "file=%~1"
set "name=%~n1"
set "start_time=%time%"
set "timestamp=%date%"
set "audio_opts="
set "audio_maps=-map 0:a"
set "subtitle_maps="

echo Checking file !file! ...

REM Get resolution
ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "!file!" > video.txt
if errorlevel 1 (
    echo Error: ffprobe failed for !file!
    call :log_error "ffprobe failed to get video info"
    goto :eof
)
for /f "tokens=1,2 delims=x" %%W in (video.txt) do (
    set /a pixels=%%W * %%X / 1000
    set "width=%%W"
    set "height=%%X"
)
set /a videobitrate=pixels * !anchor_bitrate! / 2073 + 150

REM Get audio streams
ffprobe -v error -select_streams a -show_entries stream=index,channels,codec_name:stream_tags=language -of csv=p=0 "!file!" > audio.txt
if errorlevel 1 (
    echo Error: ffprobe failed for audio in !file!
    call :log_error "ffprobe failed to get audio info"
    goto :eof
)
set "audio_count=0"
set "audio_langs="
for /f "tokens=1,2,3,4 delims=," %%I in (audio.txt) do (
    set "idx=%%I"
    set "codec=%%J"
    set "channels=%%K"
    set "lang=%%L"

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
    if defined lang set "audio_langs=!audio_langs! !lang!"
    set /a audio_count+=1
)

REM Get subtitle streams
ffprobe -v error -select_streams s -show_entries stream=index:stream_tags=language -of csv=p=0 "!file!" > subtitles.txt
set "subtitle_langs="
set /a s_ord=0
for /f "tokens=1,2 delims=," %%I in (subtitles.txt) do (
    set "lang=%%J"
    if /i "!lang!"=="eng" (
        set "subtitle_maps=!subtitle_maps! -map 0:s:!s_ord!"
        set "subtitle_langs=!subtitle_langs! eng"
    ) else if /i "!lang!"=="fin" (
        set "subtitle_maps=!subtitle_maps! -map 0:s:!s_ord!"
        set "subtitle_langs=!subtitle_langs! fin"
    )
    set /a s_ord+=1
)

REM Encode
echo Encoding !file! ...
ffmpeg -y -analyzeduration 1000M -probesize 1000M -i "!file!" -map 0:v !audio_maps! !subtitle_maps! -c:v av1_nvenc -b:v !videobitrate!k -preset slow -tune uhq -multipass 2 -pix_fmt p010le -profile:v main10 -rc vbr !audio_opts! -c:s copy -f matroska "!folder!\!name!.mkv"
if errorlevel 1 (
    echo Error: ffmpeg failed for !file!
    call :log_error "ffmpeg failed during encoding"
    goto :eof
)

REM Log output size
set "size=%~z1"
for %%S in ("!folder!\!name!.mkv") do set "output_size=%%~zS"
set /a size_kb=!size! / 1024
set /a output_kb=!output_size! / 1024
set "end_time=%time%"

REM Log success
(
    echo File:  !file!
    echo Command:  ffmpeg -i "!file!" ...
    echo Date:  !timestamp!
    echo Time:  !start_time! --- !end_time!
    echo Input size:  !size_kb! KB --- !size! bytes
    echo Output size:  !output_kb! KB --- !output_size! bytes
    echo Resolution:  !width! x !height!
    echo Video:  !videobitrate! kbps
    echo Audio: !audio_opts!
    echo Audio languages: !audio_langs!
    echo Subtitles: !subtitle_maps!
    echo Subtitle languages: !subtitle_langs!
    echo.
) >> encode_log.txt

rem move "!file!" "!folder2!" 2>nul
goto :eof

:log_error
(
    echo Error:  %~1 for !file!
    echo Date:  !timestamp!
    echo Time:  %time%
    echo.
) >> encode_log.txt
goto :eof

:cleanup
del video.txt audio.txt subtitles.txt 2>nul
echo Done
popd
endlocal
exit /b 0
