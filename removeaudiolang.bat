@echo off
setlocal enabledelayedexpansion

REM Removes audio streams of specified language from mkv files in folder
REM Usage: just run in folder

REM Configuration
set "exclude_lang=ita"
set "filetypes=mkv"
set "folder=new"

REM Prepare working directory
pushd "%~dp0" || (
    echo Error: Could not map the UNC path
    pause
    exit /b 1
)

mkdir "%folder%" 2>nul

REM Loop over filetypes and files
for %%E in (%filetypes%) do (
    for %%F in (*.%%E) do (
        call :process_file "%%F"
    )
)
goto :cleanup

:process_file
set "file=%~1"
set "audio_maps="
set "audio_count=0"
set "excluded_count=0"

REM Extract audio stream indices and languages
ffprobe -v error -select_streams a -show_entries stream=index:stream_tags=language -of csv=p=0 "!file!" > removeaudio_audio.txt

REM Count total and excluded streams
for /f "tokens=1,2 delims=," %%A in ('type removeaudio_audio.txt') do (
    if /I "%%B" == "!exclude_lang!" (
        set /a excluded_count+=1
    )
    set /a audio_count+=1
)

REM Skip file if no excluded language found
if !excluded_count! EQU 0 (
    echo Skipped !file! — no !exclude_lang! audio stream found.
    echo Skipped file: !file! — no !exclude_lang! audio stream found. >> removeaudio_log.txt
    goto :eof
)

REM Reset audio_count for mapping
set "audio_count=0"


REM Decide mapping logic
if !excluded_count! EQU !audio_count! (
    REM All streams are excluded—include them anyway
    for /f "tokens=1,2 delims=," %%A in ('type removeaudio_audio.txt') do (
        set "audio_maps=!audio_maps! -map 0:a:!audio_count!"
        set /a audio_count+=1
    )
) else (
    REM Exclude matching language
    for /f "tokens=1,2 delims=," %%A in ('type removeaudio_audio.txt') do (
        if /I "%%B" neq "!exclude_lang!" (
            set "audio_maps=!audio_maps! -map 0:a:!audio_count!"
        )
        set /a audio_count+=1
    )
)

REM Check for subtitle streams
set "sub_maps="
set "sub_count=0"
ffprobe -v error -select_streams s -show_entries stream=index -of csv=p=0 "!file!" > removeaudio_subs.txt

for /f %%S in ('type removeaudio_subs.txt') do (
    set "sub_maps=!sub_maps! -map 0:s:!sub_count!"
    set /a sub_count+=1
)

REM Extract filename only
for %%G in ("!file!") do set "name=%%~nxG"

REM Run FFmpeg with selected streams
ffmpeg -i "!file!" -map 0:v !sub_maps! !audio_maps! -c copy "!folder!\!name!"
if errorlevel 1 (
    echo Error: ffmpeg failed for !file!
    echo Failed file: !file! >> removeaudio_error.txt
    goto :eof
)

REM Log success
echo Processed !file! successfully.
(
    echo Processed file: !file!
    echo Time: !time!
    echo Date: !date!
) >> removeaudio_log.txt
type removeaudio_audio.txt >> removeaudio_log.txt
(
    echo Audio maps: !audio_maps!
    echo Subtitle maps: !sub_maps!
    echo.
) >> removeaudio_log.txt
goto :eof

:cleanup
del removeaudio_audio.txt 2>nul
echo Done
popd
endlocal
exit /b 0
