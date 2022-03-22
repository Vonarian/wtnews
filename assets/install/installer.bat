@echo off
SET currentDirectory=%~dp0
PUSHD %currentDirectory%
CD ..
CD ..
CD ..
SET MNIST_DIR=%CD%
  @timeout 2 /nobreak >NUL
  @echo Proceeding to update the application, please do not close the window!
taskkill /F /IM wtnews.exe
"%MNIST_DIR%\out\WTNews.msix"
timeout 1