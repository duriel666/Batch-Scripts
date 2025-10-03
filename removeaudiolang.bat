@echo off
setlocal enabledelayedexpansion

REM Removes audio streams of specified language from mkv files in folder
REM Usage: just run in folder

REM Configuration
set "exclude_lang=ita"
set "filetypes=mkv"
set "folder=output"

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

REM Extract audio stream indices and languages
ffprobe -v error -select_streams a -show_entries stream=index:stream_tags=language -of csv=p=0 "!file!" > removeaudio.txt

REM Filter out excluded language
for /f "tokens=1,2 delims=," %%A in ('type removeaudio.txt') do (
    if /I "%%B" neq "!exclude_lang!" (
        set "audio_maps=!audio_maps! -map 0:a:!audio_count!"
    )
    set /a audio_count+=1
)

REM Extract filename only
for %%G in ("!file!") do set "name=%%~nxG"

REM Run FFmpeg with selected streams
ffmpeg -i "!file!" -map 0:v -map 0:s !audio_maps! -c copy "!folder!\!name!"
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
type removeaudio.txt >> removeaudio_log.txt
(
    echo Audio maps: !audio_maps!
    echo.
) >> removeaudio_log.txt
goto :eof

:cleanup
del removeaudio.txt 2>nul
echo Done
popd
endlocal
exit /b 0
