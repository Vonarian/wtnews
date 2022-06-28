@echo off
SET currentDirectory=%~dp0
PUSHD %currentDirectory%
CD ..
CD ..
CD ..
CD ..
SET MNIST_DIR=%CD%
SET appExeDir=%MNIST_DIR%
powershell "$s=(New-Object -COM WScript.Shell).CreateShortcut('%userprofile%\Start Menu\Programs\Startup\WTNews.lnk');$s.TargetPath='%appExeDir%\wtnews.exe';$s.Arguments='startup';$s.IconLocation='%userprofile%\Start Menu\Programs\WTNews.lnk';$s.WorkingDirectory='%appExeDir%';$s.WindowStyle=7;$s.Save()"
