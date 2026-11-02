# Requires a Unity Personal/Pro license already activated on this machine
# (open C:\src\UnityHub\Unity Hub.exe once, sign in, accept the license).
$ErrorActionPreference = 'Stop'
$Unity = 'C:\Program Files\Unity\Hub\Editor\6000.6.7f1\Editor\Unity.exe'
if (-not (Test-Path $Unity)) { $Unity = 'C:\src\Unity\6000.0.47f1\Editor\Unity.exe' }
$Hub = 'C:\src\UnityHub\Unity Hub.exe'
$Project = Join-Path $PSScriptRoot '..\game' | Resolve-Path
$LogDir = Join-Path $Project 'Logs'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Run-Unity([string]$logName, [string[]]$extra) {
    $log = Join-Path $LogDir $logName
    Write-Host "Unity -> $log"
    & $Unity -batchmode -nographics -projectPath $Project -quit -logFile $log @extra
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED $LASTEXITCODE. Tail of log:"
        Get-Content $log -Tail 40
        exit $LASTEXITCODE
    }
}

if (-not (Test-Path $Unity)) { throw "Unity Editor missing at $Unity" }

Run-Unity 'setup.log' @('-executeMethod', 'LuminaVale.EditorTools.LuminaSetup.Setup')
Run-Unity 'tests.log' @('-runTests', '-testPlatform', 'editmode', '-testResults', (Join-Path $LogDir 'editmode.xml'))

$android = Join-Path (Split-Path $Unity) 'Data\PlaybackEngines\AndroidPlayer'
if (Test-Path $android) {
    Run-Unity 'android.log' @('-executeMethod', 'LuminaVale.EditorTools.LuminaSetup.BuildAndroid')
    Write-Host "APK should be at $(Join-Path $Project 'Builds\LuminaVale.apk')"
} else {
    Write-Host "Android module not installed. Sign in to Hub, then:"
    Write-Host "  & '$Hub' -- --headless install-modules --version 6000.0.47f1 -m android --childModules"
    Write-Host "Or run the installer: C:\src\unity-dl\UnitySetup-Android-6000.0.47f1.exe /S /D=C:\src\Unity\6000.0.47f1"
}
Write-Host 'DONE'
