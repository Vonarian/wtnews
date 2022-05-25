@echo off
taskkill /F /IM wtnews.exe
timeout 1
powershell.exe Start-Process -FilePath 'wtnews.exe' -WorkingDirectory "(Get-AppxPackage -Name 'WTNews').InstallLocation"
for /f "delims=" %%a in ('powershell %~dp0\getPath.ps1') do Set "$Value=%%a"
if exist '%userprofile%\Start Menu\Programs\Startup\WTNews.lnk' (
powershell "$s=(New-Object -COM WScript.Shell).CreateShortcut('%userprofile%\Start Menu\Programs\Startup\WTNews.lnk');$s.TargetPath='%$Value%\wtnews.exe';$s.Arguments='connect';$s.IconLocation='%$Value%\wtnews.exe';$s.WorkingDirectory='%$Value%';$s.WindowStyle=7;$s.Save()"
)