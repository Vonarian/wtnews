@echo off
taskkill /F /IM wtnews.exe
set arg1=%1
powershell.exe Add-AppPackage -Path '%arg1%\out\WTNews.msix'
timeout 3
powershell.exe start "shell:AppsFolder\$(Get-AppxPackage 'WTNews' | select -ExpandProperty PackageFamilyName)!wtnews"