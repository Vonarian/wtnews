@echo off
taskkill /F /IM wtnews.exe
powershell.exe Add-AppPackage -Path '%tmp%\WTNews\out\WTNews.msix'
timeout 3
powershell.exe Start-Process -FilePath 'wtnews.exe' -WorkingDirectory "(Get-AppxPackage -Name 'WTNews').InstallLocation"