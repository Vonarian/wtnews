@echo off
SET currentDirectory=%~dp0
PUSHD %currentDirectory%
CD ..
CD ..
CD ..
SET MNIST_DIR=%CD%
  @timeout 2 /nobreak >NUL
taskkill /F /IM wtnews.exe
powershell.exe Add-AppPackage -Path '%MNIST_DIR%\out\WTNews.msix'
timeout 1
powershell.exe Start-Process -FilePath 'wtnews.exe' -WorkingDirectory "(Get-AppxPackage -Name 'WTNews').InstallLocation"