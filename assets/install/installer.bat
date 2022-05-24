@echo off
taskkill /F /IM wtnews.exe
timeout 1
powershell.exe Start-Process -FilePath 'wtnews.exe' -WorkingDirectory "(Get-AppxPackage -Name 'WTNews').InstallLocation"