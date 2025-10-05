@echo off
setlocal enabledelayedexpansion

REM Configuration
set "include_lang=eng fin"
set "filetypes=mkv"
set "folder=new"

REM Prepare working directory
pushd "%~dp0" || (
    echo Error: Could not map the UNC path
    pause
    exit /b 1@echo off
setlocal enabledelayedexpansion

REM Configuration
set "include_lang=eng fin und"
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

REM Extract audio stream indices and languages
ffprobe -v error -select_streams a -show_entries stream=index:stream_tags=language -of csv=p=0 "!file!" > keepaudio_audio.txt

REM Filter out not included languages
for /f "tokens=1,2 delims=," %%A in ('type keepaudio_audio.txt') do (
    for %%E in (!include_lang!) do (
        if /I "%%B" == "%%E" (
            set "audio_maps=!audio_maps! -map 0:a:!audio_count!"
        )
    )
    set /a audio_count+=1
)

REM Extract filename only
for %%G in ("!file!") do set "name=%%~nxG"

REM Check for subtitle streams
set "sub_maps="
set "sub_count=0"
ffprobe -v error -select_streams s -show_entries stream=index -of csv=p=0 "!file!" > keepaudio_subs.txt

for /f %%S in ('type keepaudio_subs.txt') do (
    set "sub_maps=!sub_maps! -map 0:s:!sub_count!"
    set /a sub_count+=1
)

REM Run FFmpeg with selected streams
ffmpeg -i "!file!" -map 0:v !sub_maps! !audio_maps! -c copy "!folder!\!name!"
if errorlevel 1 (
    echo Error: ffmpeg failed for !file!
    echo Failed file: !file! >> keepaudio_error.txt
    goto :eof
)

REM Log success
echo Processed !file! successfully.
(
    echo Processed file: !file!
    echo Time: !time!
    echo Date: !date!
) >> keepaudio_log.txt
type keepaudio_audio.txt >> keepaudio_log.txt
(
    echo Audio maps: !audio_maps!
    echo Subtitle maps: !sub_maps!
    echo.
) >> keepaudio_log.txt
goto :eof

:cleanup
del keepaudio_audio.txt 2>nul
echo Done
popd
endlocal
exit /b 0

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
ffprobe -v error -select_streams a -show_entries stream=index:stream_tags=language -of csv=p=0 "!file!" > keepaudio_audio.txt

REM Filter out not included languages
for /f "tokens=1,2 delims=," %%A in ('type keepaudio_audio.txt') do (
    for %%E in (!include_lang!) do (
        if /I "%%B" == "%%E" (
            set "audio_maps=!audio_maps! -map 0:a:!audio_count!"
        )
    )
    set /a audio_count+=1
)

REM Extract filename only
for %%G in ("!file!") do set "name=%%~nxG"

REM Check for subtitle streams
set "sub_maps="
set "sub_count=0"
ffprobe -v error -select_streams s -show_entries stream=index -of csv=p=0 "!file!" > keepaudio_subs.txt

for /f %%S in ('type keepaudio_subs.txt') do (
    set "sub_maps=!sub_maps! -map 0:s:!sub_count!"
    set /a sub_count+=1
)

REM Run FFmpeg with selected streams
ffmpeg -i "!file!" -map 0:v !sub_maps! !audio_maps! -c copy "!folder!\!name!"
if errorlevel 1 (
    echo Error: ffmpeg failed for !file!
    echo Failed file: !file! >> keepaudio_error.txt
    goto :eof
)

REM Log success
echo Processed !file! successfully.
(
    echo Processed file: !file!
    echo Time: !time!
    echo Date: !date!
) >> keepaudio_log.txt
type keepaudio_audio.txt >> keepaudio_log.txt
(
    echo Audio maps: !audio_maps!
    echo Subtitle maps: !sub_maps!
    echo.
) >> keepaudio_log.txt
goto :eof

:cleanup
del keepaudio_audio.txt 2>nul
echo Done
popd
endlocal
exit /b 0
