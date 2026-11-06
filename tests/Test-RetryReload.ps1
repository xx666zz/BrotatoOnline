param(
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [string]$Godot = 'D:\GodotSteam\godotsteam.36.editor.windows.64.exe'
)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$output = Join-Path (Split-Path -Parent $project) "logs\retry-reload-regression\$stamp"
New-Item -ItemType Directory -Force -Path "$output\userdata\Brotato\logs" | Out-Null
$sourceScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\menu_sync_manager.gd'
$installedScript = Join-Path $project 'mods-unpacked\six666-BrotatoOnline\scripts\menu_sync_manager.gd'
$sourceHash = (Get-FileHash -LiteralPath $sourceScript).Hash
if ($sourceHash -ne (Get-FileHash -LiteralPath $installedScript).Hash) {
    throw 'Deploy the current Mod before running this regression.'
}
"menu_sync_manager.gd SHA256=$sourceHash" | Set-Content "$output\source.txt"
$previousAppData = $env:APPDATA
$previousTestDir = $env:BROTATO_TEST_DIR
try {
    $env:APPDATA = "$output\userdata"
    $env:BROTATO_TEST_DIR = $output
    $arguments = '--path "{0}" --no-window --audio-driver Dummy res://mods-unpacked/six666-BrotatoOnline/tests/retry_reload.tscn' -f $project
    $process = Start-Process $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$output\stdout.log" -RedirectStandardError "$output\stderr.log"
} finally {
    $env:APPDATA = $previousAppData
    $env:BROTATO_TEST_DIR = $previousTestDir
}
if (-not $process.WaitForExit(55000)) {
    $process.Kill()
    throw "Regression timed out: $output"
}
$process.Refresh()
$result = Get-Content "$output\stdout.log" | Select-String 'RETRY_RELOAD_'
$result
Write-Output "Evidence: $output"
if ($process.ExitCode -ne 0 -or -not ($result -match 'RETRY_RELOAD_RESULT: 10 checks, 0 failures') -or (Select-String "$output\stderr.log" -Pattern 'SCRIPT ERROR:|RETRY_RELOAD_FAIL:' -Quiet)) {
    throw "Regression failed: $output"
}
