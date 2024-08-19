@echo off

setlocal enabledelayedexpansion
set "baseURL=https://somewebsite.something/video_"
set "urlNumber=1234"
set "newNumber=urlNumber+1"
set "number=1"
set "count=123"
set "command=yt-dlp -o "%%(title)s [%%(id)s] %%(upload_date)s.%%(ext)s""

REM https://somewebsite.something/video_1234 , https://somewebsite.something/video_1233 etc.
for /L %%i in (1,1,%count%) do (
    set /a "newNumber=!newNumber! - !number!"
    set "fullURL=!baseURL!!newNumber!"
    echo      running     "!command! !fullURL!"
    !command! !fullURL!
)

endlocal
