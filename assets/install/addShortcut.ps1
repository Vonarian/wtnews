$V = (Get-AppxPackage -Name 'WTNews').InstallLocation;
$path = $V + '\wtnews.exe';
$objShell = New-Object -COM ("WScript.Shell");
$objShortCut = $objShell.CreateShortcut($env:USERPROFILE + "\Start Menu\Programs\Startup" + "\WTNews.lnk");
$objShortCut.TargetPath = $path;
$objShortCut.Arguments = "startup";

$objShortCut.Save();