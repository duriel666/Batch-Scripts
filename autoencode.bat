@echo off
setlocal enabledelayedexpansion

REM Calculates bitrate for video and audio streams
REM Convert set filetypes with calculated values to av1_nvec/opus mkv files in set folder
REM Usage: just run in folder
REM Note: REM = comments, rem = disabled lines

REM Set filetype and 1080p bitrate (bitrate is set value + 150)
set "filetypes=mp4 mkv avi mov wmv mpg mpeg"
set "anchor_bitrate=450"
set "folder=new"
rem set "folder2=old"

pushd "%~dp0" || (
    echo Error: Could not map the UNC path
    pause
    exit /b 1
)

mkdir "%folder%" 2>nul
rem mkdir "%folder2%" 2>nul
echo Processing all %filetypes% files...

REM Check for libopus support
ffmpeg -encoders | findstr /C:"libopus" >nul

REM If not found, fall back to libvorbis
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

REM Process a single file
:process_file
set "file=%~1"
set "name=%~n1"
call set "start_time=%time%"
set "timestamp=%date%"
set "audio_opts="
set "audio_maps=-map 0:a"
set "subtitle_maps="

echo Checking !file! ...

REM Get resolution
ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "!file!" > video.txt

REM Check for ffprobe error
if errorlevel 1 (
    echo Error: ffprobe failed for !file!
    call :log_error "ffprobe failed to get video info"
    goto :eof
)

REM Read width and height
for /f "tokens=1,2 delims=x" %%W in (video.txt) do (
    set /a pixels=%%W * %%X / 1000
    set "width=%%W"
    set "height=%%X"
)

set /a videobitrate=pixels * !anchor_bitrate! / 2073 + 150

REM Get audio stream details
ffprobe -v error -select_streams a -show_entries stream=index,channels,channel_layout:stream_tags=language -of csv=p=0 "!file!" > audio.txt

REM Check for ffprobe error
if errorlevel 1 (
    echo Error: ffprobe failed to get audio info for !file!
    call :log_error "ffprobe failed to get audio info"
    goto :eof
)

set "audio_count=0"
set "audio_opts="
set "audio_langs="

REM Define Opus-safe layouts
set "opus_safe_layouts=mono stereo 2.1 3.0 3.1 4.0 4.1 5.0 5.1 6.1 7.1"

REM Process each audio stream
for /f "tokens=1,2,3,4 delims=," %%I in (audio.txt) do (
    set "idx=%%I"
    set "channels=%%J"
    set "layout=%%K"
    set "lang=%%L"

    REM Default: assume layout is safe
    set "downmix="
    set "layoutfix="
    set "final_channels=!channels!"

    REM Check if layout is unsupported by Opus
    echo !opus_safe_layouts! | findstr /i "\<!layout!\>" >nul
    if errorlevel 1 (
        set "downmix=-ac 2"
        set "layoutfix=-channel_layout stereo"
        set "final_channels=2"
    )

    REM Fallback: Opus maxes out at 8 channels
    if !final_channels! gtr 8 (
        set "downmix=-ac 2"
        set "layoutfix=-channel_layout stereo"
        set "final_channels=2"
    )

    REM Fallback: if using libvorbis, always downmix
    if /i "!audio_codec!"=="libvorbis" (
        set "downmix=-ac 2"
        set "layoutfix=-channel_layout stereo"
        set "final_channels=2"
    )

    REM Bitrate table based on final_channels
    if "!final_channels!"=="1" set "ab=56"
    if "!final_channels!"=="2" set "ab=80"
    if "!final_channels!"=="3" set "ab=112"
    if "!final_channels!"=="4" set "ab=128"
    if "!final_channels!"=="5" set "ab=160"
    if "!final_channels!"=="6" set "ab=192"
    if "!final_channels!"=="7" set "ab=224"
    if "!final_channels!"=="8" set "ab=256"

    REM Build audio options
    set "current_opts=-c:a:!audio_count! !audio_codec! !downmix! !layoutfix! -b:a:!audio_count! !ab!k"
    set "audio_opts=!audio_opts! !current_opts!"

    REM Track language
    if defined lang (
        set "audio_langs=!audio_langs! !lang!"
    ) else (
        set "audio_langs=!audio_langs! unknown"
    )

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

REM Check for ffmpeg error
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

REM Validate output file
if "!output_size!"=="0" (
    echo Output file is empty, deleting "!folder!\!name!.mkv"
    del "!folder!\!name!.mkv"
    call :log_error "Output file was 0 bytes and was deleted"
    goto :eof
)

if !output_size! gtr !size! (
    echo Output file is larger than input, deleting "!folder!\!name!.mkv"
    del "!folder!\!name!.mkv"
    call :log_error "Output file was larger than input and was deleted"
    goto :eof
)

REM Get file durations
ffprobe -v error -select_streams v:0 -show_entries format^=duration -of default^=noprint_wrappers^=1:nokey^=1 "!file!" > durations.txt
ffprobe -v error -select_streams v:0 -show_entries format^=duration -of default^=noprint_wrappers^=1:nokey^=1 "!folder!\!name!.mkv" >> durations.txt

REM Read durations
set "line=0"
for /f "tokens=1 delims=." %%I in (durations.txt) do (
    if "!line!"=="0" set /a "input_sec=%%I"
    if "!line!"=="1" set /a "output_sec=%%I"
    set /a line+=1
)

REM Check if drift is over 10 seconds
set /a drift=input_sec - output_sec
if !drift! gtr 10 (
    echo Output duration is too short (drift: !drift!s), deleting "!folder!\!name!.mkv"
    del "!folder!\!name!.mkv"
    call :log_error "Drift: !drift!s - Input (!input_sec!s) --- Output (!output_sec!s)"
    goto :eof
)

call set "end_time=%time%"

REM Log success
(
    echo File:  !file!
    echo Command:  ffmpeg -i "!file!" ...
    echo Date:  !timestamp!
    echo Time:  !start_time! --- !end_time!
    echo Input size:  !size_kb! KB --- !size! bytes
    echo Output size:  !output_kb! KB --- !output_size! bytes
    echo Input duration:  !input_sec! seconds
    echo Output duration:  !output_sec! seconds
    echo Duration drift: !drift! seconds
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
call set "end_time=%time%"
(
    echo File:  !file!
    echo Error:  %~1
    echo Date:  !timestamp! 
    echo Time:  !start_time! --- !end_time!
    echo.
) >> error_log.txt
goto :eof

:cleanup
for %%F in (video.txt audio.txt subtitles.txt durations.txt) do if exist %%F del %%F
echo Done
popd
endlocal
exit /b 0
