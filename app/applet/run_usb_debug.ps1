param(
    [string]$DeviceId
)

$ErrorActionPreference = 'Stop'
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if (-not (Test-Path $adb)) {
    throw "Android Debug Bridge was not found at $adb."
}

$deviceState = & $adb get-state 2>$null
if ($LASTEXITCODE -ne 0 -or $deviceState -ne 'device') {
    throw 'No authorized USB-debugging device is connected. Unlock the phone and authorize this computer.'
}

& $adb reverse tcp:8000 tcp:8000
if ($LASTEXITCODE -ne 0) {
    throw 'Could not forward phone port 8000. Reconnect USB debugging and retry.'
}

try {
    $health = Invoke-WebRequest `
        -Uri 'http://127.0.0.1:8000/api/shops/' `
        -TimeoutSec 5 `
        -UseBasicParsing
    if ($health.StatusCode -lt 200 -or $health.StatusCode -ge 300) {
        throw "Django returned HTTP $($health.StatusCode) from /api/shops/."
    }
}
catch {
    throw "Django is not responding at http://127.0.0.1:8000. Start it from the shared backend with: python manage.py runserver 0.0.0.0:8000. Details: $($_.Exception.Message)"
}

$flutterArgs = @(
    'run',
    '--dart-define=BASE_URL=http://127.0.0.1:8000'
)
if ($DeviceId) {
    $flutterArgs += @('-d', $DeviceId)
}

Push-Location $PSScriptRoot
try {
    & flutter @flutterArgs
    if ($LASTEXITCODE -ne 0) {
        throw "flutter run failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}
