@echo off
setlocal enabledelayedexpansion

REM Encode files with set filetypes with set video/audio bitrate to av1_nvenc/opus mkv files in set folder
REM Usage: just run in folder

REM Configuration
set "filetypes=mkv"
set "audio=192"
set "video=500"
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
goto :the_end

REM Process a single file
:process_file
set "file=%~1"

ffmpeg -i "!file!" -c:v av1_nvenc -b:v !video!k -preset slow -tune uhq -multipass 2 -pix_fmt p010le -profile:v main10 -rc vbr -c:a libopus -b:a !audio!k -c:s copy "!folder!\!file!" -y

REM All done
:the_end
echo.
echo Finished processing all files.
echo.

popd
endlocal
exit /b 0
