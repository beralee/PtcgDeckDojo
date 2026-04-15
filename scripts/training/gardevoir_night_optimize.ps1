param(
    [int]$Hours = 6,
    [string]$AppDataRoot = "D:\ai",
    [string]$ProjectRoot = "D:\ai\code\ptcgtrain"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-ControllerLog {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    $line | Tee-Object -FilePath $script:ControllerLog -Append
}

function Get-LatestRunDir {
    param([string]$RunsRoot)
    if (-not (Test-Path $RunsRoot)) {
        return $null
    }
    return Get-ChildItem $RunsRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

$env:APPDATA = $AppDataRoot
$runsRoot = Join-Path $AppDataRoot "Godot\app_userdata\PTCG Train\training_data\gardevoir\runs"
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$script:ControllerLog = Join-Path $ProjectRoot "gardevoir_night_optimize_${stamp}.log"
$deadline = (Get-Date).AddHours($Hours)

$attempts = @(
    @{ MirrorGames = 64; CrossGames = 32; SeedSet = "11,29,47,83,101,149"; Label = "attempt1" },
    @{ MirrorGames = 96; CrossGames = 48; SeedSet = "11,29,47,83,101,149"; Label = "attempt2" },
    @{ MirrorGames = 128; CrossGames = 64; SeedSet = "11,29,47,83,101,149"; Label = "attempt3" },
    @{ MirrorGames = 128; CrossGames = 64; SeedSet = "11,29,47,83,101,149"; Label = "attempt4" }
)

Write-ControllerLog "Starting gardevoir overnight optimizer"
Write-ControllerLog "APPDATA=$env:APPDATA"
Write-ControllerLog "Runs root=$runsRoot"
Write-ControllerLog "Deadline=$deadline"

foreach ($attempt in $attempts) {
    if ((Get-Date) -ge $deadline) {
        Write-ControllerLog "Stopping: deadline reached before $($attempt.Label)"
        break
    }

    $before = Get-LatestRunDir -RunsRoot $runsRoot
    Write-ControllerLog ("Launching {0}: mirror={1}, cross={2}, seeds={3}" -f $attempt.Label, $attempt.MirrorGames, $attempt.CrossGames, $attempt.SeedSet)

    & powershell -ExecutionPolicy Bypass -File (Join-Path $ProjectRoot "scripts\training\run_decision_training.ps1") `
        -DeckName gardevoir `
        -DeckPrefix gardevoir `
        -Encoder gardevoir `
        -PipelineName gardevoir_focus_training `
        -PipelineSuffix gardevoir_focus `
        -OptimizedDeck 578647 `
        -OpponentsCsv "575720,575716,569061" `
        -Rounds 1 `
        -TimeBudgetSeconds 14400 `
        -MirrorGames $attempt.MirrorGames `
        -CrossGames $attempt.CrossGames `
        -BenchmarkSeedSet $attempt.SeedSet

    $after = Get-LatestRunDir -RunsRoot $runsRoot
    if ($null -eq $after) {
        Write-ControllerLog "No run directory found after $($attempt.Label)"
        continue
    }
    if ($null -ne $before -and $after.FullName -eq $before.FullName) {
        Write-ControllerLog ("Latest run directory did not advance after {0}: {1}" -f $attempt.Label, $after.FullName)
    } else {
        Write-ControllerLog ("Completed {0} with run {1}" -f $attempt.Label, $after.Name)
    }

    $summaryPath = Join-Path $after.FullName "round_01\benchmark\summary.json"
    $decisionMetricsPath = Join-Path $after.FullName "round_01\models\decision_metrics.json"

    if (Test-Path $summaryPath) {
        $summary = Get-Content -Raw $summaryPath | ConvertFrom-Json
        Write-ControllerLog ("Summary: gate_passed={0}, win_rate={1:P1}, all_cases_passed={2}" -f $summary.gate_passed, [double]$summary.win_rate_vs_current_best, $summary.all_cases_passed)
        foreach ($pairing in $summary.pairing_results) {
            Write-ControllerLog ("Pairing {0}: gate={1}, text={2}" -f $pairing.pairing_name, $pairing.gate_passed, $pairing.text_summary)
        }
        if ([bool]$summary.gate_passed) {
            Write-ControllerLog ("Stopping early: successful promotion candidate in {0}" -f $after.Name)
            break
        }
    } else {
        Write-ControllerLog ("Summary missing for run {0}" -f $after.Name)
    }

    if (Test-Path $decisionMetricsPath) {
        $decisionMetrics = Get-Content -Raw $decisionMetricsPath | ConvertFrom-Json
        Write-ControllerLog ("Decision top1_gain_vs_heuristic={0:N4}, top3_gain_vs_heuristic={1:N4}" -f [double]$decisionMetrics.overall.top1_gain_vs_heuristic, [double]$decisionMetrics.overall.top3_gain_vs_heuristic)
    }
}

Write-ControllerLog "Gardevoir overnight optimizer finished"
