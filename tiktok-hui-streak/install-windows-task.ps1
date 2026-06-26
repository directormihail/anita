# Registers a daily Windows Task Scheduler job for TikTok HUI streak bot.
# Run from the project folder after login + test work.

param(
    [string]$TaskName = "TikTokHuiStreak",
    [string]$SendTime = ""
)

$ErrorActionPreference = "Stop"
$ProjectDir = $PSScriptRoot
$PythonExe = Join-Path $ProjectDir ".venv\Scripts\python.exe"
$ConfigPath = Join-Path $ProjectDir "config.yaml"
$LogPath = Join-Path $ProjectDir "streak.log"

if (-not (Test-Path $PythonExe)) {
    throw "Missing $PythonExe. Run setup-windows.bat first."
}

if (-not (Test-Path $ConfigPath)) {
    throw "Missing config.yaml. Copy config.example.yaml to config.yaml and edit it."
}

if (-not $SendTime) {
    $line = Get-Content $ConfigPath | Where-Object { $_ -match '^\s*send_time:\s*"(.+)"\s*$' } | Select-Object -First 1
    if ($line -match 'send_time:\s*"(.+)"') {
        $SendTime = $Matches[1]
    }
}

if (-not $SendTime) {
    throw "Could not read send_time from config.yaml. Pass -SendTime '09:00'."
}

if ($SendTime -notmatch '^([01]?\d|2[0-3]):([0-5]\d)$') {
    throw "Invalid send_time '$SendTime'. Use 24h format like 09:00 or 21:30."
}

$hour = [int]$Matches[1]
$minute = [int]$Matches[2]
$triggerTime = Get-Date -Hour $hour -Minute $minute -Second 0

$action = New-ScheduledTaskAction `
    -Execute $PythonExe `
    -Argument "main.py send-now" `
    -WorkingDirectory $ProjectDir

$trigger = New-ScheduledTaskTrigger -Daily -At $triggerTime

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable

$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel LeastPrivilege

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "Send daily HUI TikTok DM to keep streak alive." `
    -Force | Out-Null

Write-Host "Scheduled task '$TaskName' installed."
Write-Host "Runs daily at $SendTime"
Write-Host "Log file: $LogPath"
Write-Host ""
Write-Host "Test now:  Start-ScheduledTask -TaskName $TaskName"
Write-Host "Remove:    powershell -ExecutionPolicy Bypass -File uninstall-windows-task.ps1"
