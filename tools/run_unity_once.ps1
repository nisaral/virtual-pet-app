param(
    [string]$Method = "LuminaVale.EditorTools.LuminaSetup.Setup",
    [string]$LogName = "unity-run.log",
    [switch]$RunTests,
    [switch]$BuildApk
)
$env:ANDROID_HOME = "C:\Android"
$env:ANDROID_SDK_ROOT = "C:\Android"
$env:JAVA_HOME = "C:\src\jdk"
$Unity = "C:\Program Files\Unity\Hub\Editor\6000.6.7f1\Editor\Unity.exe"
$Project = "C:\Users\nisar\virtual-pet-app\game"
$Log = Join-Path "C:\src\unity-dl" $LogName
Write-Host "Unity $Method -> $Log"
$args = @(
    "-batchmode",
    "-nographics",
    "-projectPath", $Project,
    "-logFile", $Log
)
if ($RunTests) {
    $args += @("-runTests", "-testPlatform", "editmode", "-testResults", "C:\src\unity-dl\editmode.xml")
} elseif ($BuildApk) {
    $args += @("-quit", "-executeMethod", "LuminaVale.EditorTools.LuminaSetup.BuildAndroid")
} elseif ($Method -and $Method -ne "none") {
    $args += @("-quit", "-executeMethod", $Method)
} else {
    $args += "-quit"
}
$p = Start-Process -FilePath $Unity -PassThru -ArgumentList $args
Write-Host "started $($p.Id)"
Wait-Process -Id $p.Id
# trampoline: wait for leftover editor
do {
    Start-Sleep 5
    $kids = Get-CimInstance Win32_Process | Where-Object { $_.Name -eq "Unity.exe" -and $_.CommandLine -like "*virtual-pet-app*" }
} while ($kids)
Write-Host "finished"
exit 0
