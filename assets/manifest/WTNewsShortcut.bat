@echo off
powershell.exe start "shell:AppsFolder\$(Get-AppxPackage 'WTNews' | select -ExpandProperty PackageFamilyName)!wtnews" startup