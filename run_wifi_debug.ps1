param(
    [string]$DeviceId
)

$ErrorActionPreference = 'Stop'
$sdkRoot = $env:ANDROID_SDK_ROOT
if (-not $sdkRoot) {
    $sdkRoot = $env:ANDROID_HOME
}
if (-not $sdkRoot) {
    $sdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
}

$adb = Join-Path $sdkRoot 'platform-tools\adb.exe'
if (-not (Test-Path $adb)) {
    throw "Android Debug Bridge was not found at $adb. Set ANDROID_SDK_ROOT to your Android SDK."
}

$network = Get-NetIPConfiguration |
    Where-Object { $_.NetAdapter.Status -eq 'Up' -and $_.IPv4DefaultGateway -and $_.IPv4Address } |
    Select-Object -First 1
$lanAddress = $network.IPv4Address.IPAddress |
    Where-Object { $_ -notmatch '^(127\.|169\.254\.)' } |
    Select-Object -First 1

if (-not $lanAddress) {
    throw 'No active LAN IPv4 address was found. Connect this PC to the same Wi-Fi network as the phone.'
}

$apiUrl = "http://${lanAddress}:8000"
try {
    $health = Invoke-RestMethod -Uri "${apiUrl}/api/" -TimeoutSec 5
    if ($health.service -ne 'ShopGenie Django API') {
        throw 'The response did not identify itself as the ShopGenie Django API.'
    }
}
catch {
    throw "Django is not reachable at ${apiUrl}/api/. Start it in shopgenie_unified with .\run_lan.ps1. Details: $($_.Exception.Message)"
}

$connectedDevices = @(& $adb devices |
    Select-String '^\S+\s+device$' |
    ForEach-Object { ($_ -split '\s+')[0] } |
    Where-Object { $_ -match ':\d+$' })

if ($DeviceId) {
    if ($connectedDevices -notcontains $DeviceId) {
        throw "Wireless Android device '$DeviceId' is not connected. Pair and connect it with adb over Wi-Fi first."
    }
    $selectedDevice = $DeviceId
}
elseif ($connectedDevices.Count -eq 1) {
    $selectedDevice = $connectedDevices[0]
}
elseif ($connectedDevices.Count -eq 0) {
    throw 'No wireless Android device is connected. Enable Wireless debugging, run adb pair <phone-ip>:<pairing-port>, then adb connect <phone-ip>:<adb-port>.'
}
else {
    throw "More than one wireless Android device is connected. Specify one with -DeviceId. Connected: $($connectedDevices -join ', ')"
}

Push-Location $PSScriptRoot
try {
    $env:ANDROID_SERIAL = $selectedDevice
    $apiBaseUrl = "${apiUrl}/"
    & .\gradlew.bat installDebug "-PshopgenieApiBaseUrl=$apiBaseUrl"
    if ($LASTEXITCODE -ne 0) {
        throw "Gradle installDebug failed with exit code $LASTEXITCODE."
    }

    & $adb -s $selectedDevice shell am start -n 'com.aistudio.shopgenie.xrkvzq/com.example.MainActivity'
    if ($LASTEXITCODE -ne 0) {
        throw 'The app installed but Android could not launch its main activity.'
    }
    Write-Host "ShopGenie is using backend $apiBaseUrl"
}
finally {
    Pop-Location
}
