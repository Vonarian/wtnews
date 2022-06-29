@echo off
taskkill /F /IM wtnews.exe
set arg1=%1
powershell.exe Add-AppPackage -Path '%arg1%\out\WTNews.msix'
timeout 3
if exist '%userprofile%\Start Menu\Programs\Startup\WTNews.lnk' (
powershell.exe -NonInteractive -ExecutionPolicy Bypass -File .\addShortcut.ps1
)
timeout 1
powershell.exe Start-Process -FilePath 'wtnews.exe' -WorkingDirectory "(Get-AppxPackage -Name 'WTNews').InstallLocation"