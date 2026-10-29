param (
    [switch]$WaitForDebugger
)

$adb = "C:\Users\vinay\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$apk = "app\build\outputs\apk\debug\app-debug.apk"
$appId = "com.aistudio.shopgenie.xrkvzq"
$activity = "com.example.MainActivity"

Write-Host "=== ShopGenie Mobile Debug Runner ===" -ForegroundColor Cyan
Write-Host "1. Checking ADB device connection..." -ForegroundColor Yellow
& $adb devices -l

Write-Host "`n2. Waiting for device authorization (Please unlock phone screen & tap 'Allow' if prompted)..." -ForegroundColor Yellow
& $adb wait-for-device

Write-Host "`n3. Device connected! Installing debug APK ($apk)..." -ForegroundColor Yellow
$installRes = & $adb install -r -d $apk
Write-Host $installRes

if ($installRes -notmatch "Success") {
    Write-Host "Retrying install without -d flag..." -ForegroundColor Yellow
    & $adb install -r $apk
}

Write-Host "`n4. Launching app on mobile device..." -ForegroundColor Yellow
if ($WaitForDebugger) {
    & $adb shell am start -D -n "$appId/$activity"
    Write-Host "App launched with 'Wait for Debugger' flag (-D)." -ForegroundColor Green
} else {
    & $adb shell am start -n "$appId/$activity"
    Write-Host "App successfully launched on phone!" -ForegroundColor Green
}

Write-Host "`n5. Monitoring device logs (logcat) for ShopGenie..." -ForegroundColor Cyan
& $adb logcat -v time -s "ShopGenie" "AndroidRuntime:E" "$appId"
