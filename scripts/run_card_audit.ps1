param(
    [string]$GodotDir = "D:\ai\godot",
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$Scene = "res://tests/TestRunner.tscn"
)

$ErrorActionPreference = "Stop"

function Resolve-GodotConsoleExe {
    param([string]$BaseDir)

    $preferred = Join-Path $BaseDir "Godot_v4.6.1-stable_win64_console.exe"
    if (Test-Path $preferred) {
        return (Resolve-Path $preferred).Path
    }

    $candidate = Get-ChildItem -Path $BaseDir -Filter "*console*.exe" -File |
        Sort-Object Name |
        Select-Object -First 1
    if ($null -ne $candidate) {
        return $candidate.FullName
    }

    throw "Godot console executable not found under '$BaseDir'."
}

$godotExe = Resolve-GodotConsoleExe -BaseDir $GodotDir
$projectRootPath = (Resolve-Path $ProjectRoot).Path
$reportPath = Join-Path $env:APPDATA "Godot\app_userdata\PTCG Train\logs\card_audit_latest.txt"
$statusMatrixPath = Join-Path $env:APPDATA "Godot\app_userdata\PTCG Train\logs\card_status_matrix_latest.txt"

Write-Host "Godot:" $godotExe
Write-Host "Project:" $projectRootPath
Write-Host "Scene:" $Scene

& $godotExe --headless --path $projectRootPath $Scene
$exitCode = $LASTEXITCODE

Write-Host "Exit code:" $exitCode
if (Test-Path $reportPath) {
    Write-Host "Card audit report:" $reportPath
}
if (Test-Path $statusMatrixPath) {
    Write-Host "Card status matrix:" $statusMatrixPath
}

exit $exitCode
