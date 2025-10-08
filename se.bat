@echo off
setlocal enabledelayedexpansion

REM Encode set files with filetype with set video/audio bitrate to av1_nvenc/opus mkv files in set folder
REM Usage: just run in folder or with parameters:
REM se.bat [filetype] [audio bitrate] [video bitrate] [output folder]
REM Example: se.bat mkv 192 500 new

REM Configuration
set "filetype=mkv"
set "audio=192"
set "video=500"
set "folder=new"

set "valid_files=mp4 mkv avi mov wmv mpg mpeg"
REM Override configuration with parameters
if "%~1" == "" goto :start_encode
REM check if parameter 1 is valid
for %%E in (%valid_files%) do (
    if /I "%%E" == "%~1" set "is_valid=1"
)
if not defined is_valid (
    goto :parse_error
)
set "filetype=%~1"
if "%~2" == "" goto :parse_error
echo %~2 | findstr /R "^[0-9][0-9]*$" >nul || goto :parse_error
if "%~2" lss "16" goto :parse_error
if "%~2" gtr "8196" goto :parse_error
set "audio=%~2"
if "%~3" == "" goto :parse_error
echo %~3 | findstr /R "^[0-9][0-9]*$" >nul || goto :parse_error
if "%~3" lss "64" goto :parse_error
if "%~3" gtr "50000" goto :parse_error
set "video=%~3"
if not "%~4" == "" set "folder=%~4"
goto :start_encode

:parse_error
echo Error: Missing or invalid parameters.
echo Usage: simpleencode.bat [filetype] [audio bitrate] [video bitrate]
echo Example: simpleencode.bat mkv 192 500 new
goto :the_end

:start_encode
REM Prepare working directory
pushd "%~dp0" || (
    echo Error: Could not map the UNC path
    pause
    exit /b 1
)

mkdir "%folder%" 2>nul

REM Loop over files
for %%F in (*.%filetype%) do (
    call :process_file "%%F"
)
goto :finished

REM Process a single file
:process_file
set "file=%~1"

echo ffmpeg -i "!file!" -c:v av1_nvenc -b:v !video!k -preset slow -tune uhq -multipass 2 -pix_fmt p010le -profile:v main10 -rc vbr -c:a libopus -b:a !audio!k -c:s copy "!folder!\!file!" -y
ffmpeg -i "!file!" -c:v av1_nvenc -b:v !video!k -preset slow -tune uhq -multipass 2 -pix_fmt p010le -profile:v main10 -rc vbr -c:a libopus -b:a !audio!k -c:s copy "!folder!\!file!" -y

REM All done
:finished
echo.
echo Finished processing all files.
echo.

:the_end
popd
endlocal
exit /b 0
