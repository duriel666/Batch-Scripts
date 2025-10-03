Batch scripts to do random stuff to files

modified.bat - modified dates from filenames, example usage correct release dates for personal files in Plex.

yt-dlp-loop.bat - uses yt-dlp (https://github.com/yt-dlp/yt-dlp) to download sequentially numbered video files.

rename.bat - renames files, replaces a string in filename with another.
rename2.bat - adds creation date to filename

clean.bat - uses ffmpeg to create a clean copy of a video file for further converting
clean2sbs - uses ffmpeg to convert clean copy of frame sequential 3d to a side-by-side in av1 format at 3000kbps using nvidia hardware
seq2sbs.bat - clean.bat + clea2sbs.bat in a same + deletes the clean file after conversion
mp4tomkv.bat - uses ffmpeg to convert mp4 to mkv

autoencode.bat uses ffmpeg to convert selected filetypes to mkv
removeaudiolang.bat uses ffmpeg to copy files without excluded language
