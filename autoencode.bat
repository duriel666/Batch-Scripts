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
call set "start_time=!time!"
echo start_time: !start_time!
set "timestamp=!date!"
echo timestamp: !timestamp!
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

echo Encoding completed, validating output...

REM Get input and output sizes
set "input_size=%~z1"
echo Input size: !input_size! bytes
for %%S in ("!folder!\!name!.mkv") do set "output_size=%%~zS"
echo Output size: !output_size! bytes

REM Approximate KB by removing last 3 digits
set "input_kb=!input_size:~0,-3!"
echo Input size: !input_kb! KB
set "output_kb=!output_size:~0,-3!"
echo Output size: !output_kb! KB

REM Fallback if string is too short or non-numeric
for %%V in (input_kb output_kb) do (
    set /a dummy=!%%V! + 0 2>nul
    if errorlevel 1 set "%%V=0"
)
echo Validated Input size: !input_kb! KB
echo Validated Output size: !output_kb! KB

REM Convert to MB for logging, use 1049 for more accurate conversion
set "input_mb=0"
set "output_mb=0"

set /a dummy=!input_kb! + 0 2>nul
if not errorlevel 1 (
    set /a input_mb=!input_kb! / 1049
) else (
    set "input_kb=0"
)
echo Validated Input size: !input_mb! MB

set /a dummy=!output_kb! + 0 2>nul
if not errorlevel 1 (
    set /a output_mb=!output_kb! / 1049
) else (
    set "output_kb=0"
)
echo Validated Output size: !output_mb! MB

REM Validate output file
if "!output_size!"=="0" (
    echo Output file is empty, deleting "!folder!\!name!.mkv"
    del "!folder!\!name!.mkv"
    call :log_error "Output file was 0 bytes and was deleted"
    goto :eof
)
echo Output file size is non-zero

REM Compare sizes using validated KB values
if !output_kb! gtr !input_kb! (
    echo Output file is larger than input, deleting "!folder!\!name!.mkv"
    del "!folder!\!name!.mkv"
    call :log_error "Output file was larger than input and was deleted"
    goto :eof
)
echo Output file size is less than or equal to input

REM Get file durations
ffprobe -v error -select_streams v:0 -show_entries format^=duration -of default^=noprint_wrappers^=1:nokey^=1 "!file!" > durations.txt
echo Input duration logged
ffprobe -v error -select_streams v:0 -show_entries format^=duration -of default^=noprint_wrappers^=1:nokey^=1 "!folder!\!name!.mkv" >> durations.txt
echo Output duration logged

REM Read durations
set "line=0"
set "input_sec=0"
set "output_sec=0"
for /f "tokens=1 delims=." %%I in (durations.txt) do (
    if "!line!"=="0" set /a "input_sec=%%I"
    if "!line!"=="1" set /a "output_sec=%%I"
    set /a line+=1
)
echo Input duration: !input_sec! seconds
echo Output duration: !output_sec! seconds

REM Check if drift is over 5 seconds
set /a drift=input_sec - output_sec
echo Initial drift calculation: !drift! seconds
set "drift_str=!drift!"
if "!drift_str:~0,1!"=="-" (
    set "drift_str=!drift_str:~1!"
)
set /a drift=!drift_str!
echo Final drift: !drift! seconds
if !drift! gtr 5 (
    echo Drift over 5 seconds, deleting "!folder!\!name!.mkv"
    del "!folder!\!name!.mkv"
    set "logmsg=Drift: !drift!s - Input !input_sec!s --- Output !output_sec!s"
    call :log_error "!logmsg!"
    goto :eof
)
echo Duration drift: !drift! seconds
call set "end_time=!time!"
echo Validation successful, logging results...

REM Log success
(
    echo File:  !file!
    echo Command:  ffmpeg -i "!file!" ...
    echo Date:  !timestamp!
    echo Time:  !start_time! --- !end_time!
    echo Input size:  !input_mb! MB --- !input_size! bytes
    echo Output size:  !output_mb! MB --- !output_size! bytes
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
call set "end_time=!time!"
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
