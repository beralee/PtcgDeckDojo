param(
    [string]$DeckName = "gardevoir",
    [string]$DeckPrefix = "gardevoir",
    [string]$Encoder = "gardevoir",
    [string]$PipelineName = "gardevoir_focus_training",
    [string]$PipelineSuffix = "gardevoir_focus",
    [int]$OptimizedDeck = 578647,
    [int[]]$Opponents = @(575720, 575716, 569061),
    [int]$Rounds = 4,
    [int]$TimeBudgetSeconds = 1800,
    [int]$MirrorGames = 160,
    [int]$CrossGames = 96,
    [double]$BenchmarkGateThreshold = 0.55,
    [double]$BootstrapGateThreshold = 0.0,
    [string]$BenchmarkSeedSet = "11,29,47,83,101,149,197,239,283,331,379,431",
    [double]$TeacherWeight = 0.0,
    [double]$DecisionStateWeight = 0.75,
    [double]$InteractionStateWeight = 0.5,
    [int]$ValueEpochs = 160,
    [int]$ActionEpochs = 24,
    [string]$Godot = "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe",
    [string]$Project = "D:/ai/code/ptcgtrain",
    [string]$Python = "python"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
if (Get-Variable PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

function Resolve-UserRoot {
    return Join-Path $env:APPDATA "Godot/app_userdata/PTCG Train"
}

function Globalize-UserPath {
    param([string]$Path)
    if ($Path.StartsWith("user://")) {
        return Join-Path $script:UserRoot ($Path.Substring(7))
    }
    return $Path
}

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Write-Log {
    param([string]$Message)
    $Message | Tee-Object -FilePath $script:LogPath -Append
}

function Invoke-NativeCommand {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$StepName
    )

    $stdoutPath = Join-Path $script:RunDir ("native_{0}_stdout.log" -f ([guid]::NewGuid().ToString("N")))
    $stderrPath = Join-Path $script:RunDir ("native_{0}_stderr.log" -f ([guid]::NewGuid().ToString("N")))
    try {
        $quotedArgs = @()
        foreach ($arg in $ArgumentList) {
            $text = [string]$arg
            if ($text -match '[\s"]') {
                $quotedArgs += '"' + ($text -replace '"', '\"') + '"'
            } else {
                $quotedArgs += $text
            }
        }
        $argumentString = $quotedArgs -join " "
        $proc = Start-Process -FilePath $FilePath -ArgumentList $argumentString -NoNewWindow -PassThru -Wait -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        if (Test-Path $stdoutPath) {
            Get-Content -Path $stdoutPath | Add-Content -Path $script:LogPath
        }
        if (Test-Path $stderrPath) {
            Get-Content -Path $stderrPath | Add-Content -Path $script:LogPath
        }
        if ($proc.ExitCode -ne 0) {
            throw ("{0} failed with exit code {1}" -f $StepName, $proc.ExitCode)
        }
    } finally {
        if (Test-Path $stdoutPath) { Remove-Item -Force -Path $stdoutPath }
        if (Test-Path $stderrPath) { Remove-Item -Force -Path $stderrPath }
    }
}

function Copy-IfExists {
    param([string]$Source, [string]$Dest)
    if ($Source -ne "" -and (Test-Path $Source)) {
        Copy-Item -Force -Path $Source -Destination $Dest
        return $true
    }
    return $false
}

function Sync-CurrentBest {
    param(
        [string]$ValueSource,
        [string]$ActionSource,
        [string]$InteractionSource
    )

    Copy-Item -Force -Path (Globalize-UserPath $ValueSource) -Destination $script:CurrentBestValueGlobalPath
    Copy-Item -Force -Path $script:CurrentBestValueGlobalPath -Destination $script:LegacyValueNet
    $script:CurrentBaselineValueUserPath = $script:CurrentBestValueUserPath
    $script:CurrentBaselineValueGlobalPath = $script:CurrentBestValueGlobalPath

    if ($ActionSource -ne "") {
        $actionGlobal = Globalize-UserPath $ActionSource
        if (Test-Path $actionGlobal) {
            Copy-Item -Force -Path $actionGlobal -Destination $script:CurrentBestActionGlobalPath
            Copy-Item -Force -Path $script:CurrentBestActionGlobalPath -Destination $script:LegacyActionScorer
            $script:CurrentBaselineActionUserPath = $script:CurrentBestActionUserPath
            $script:CurrentBaselineActionGlobalPath = $script:CurrentBestActionGlobalPath
        }
    }

    if ($InteractionSource -ne "") {
        $interactionGlobal = Globalize-UserPath $InteractionSource
        if (Test-Path $interactionGlobal) {
            Copy-Item -Force -Path $interactionGlobal -Destination $script:CurrentBestInteractionGlobalPath
            Copy-Item -Force -Path $script:CurrentBestInteractionGlobalPath -Destination $script:LegacyInteractionScorer
            $script:CurrentBaselineInteractionUserPath = $script:CurrentBestInteractionUserPath
            $script:CurrentBaselineInteractionGlobalPath = $script:CurrentBestInteractionGlobalPath
        }
    }
}

function Get-LatestApprovedBaseline {
    param([string]$IndexPath)
    if (-not (Test-Path $IndexPath)) {
        return $null
    }
    $data = Get-Content -Raw -Path $IndexPath | ConvertFrom-Json -AsHashtable
    if (-not ($data -is [hashtable])) {
        return $null
    }
    $playable = @()
    foreach ($entry in $data.GetEnumerator()) {
        if ($entry.Value -is [hashtable] -and [string]$entry.Value.status -eq "playable") {
            $playable += $entry.Value
        }
    }
    if ($playable.Count -eq 0) {
        return $null
    }
    return $playable | Sort-Object created_at, save_order, version_id | Select-Object -Last 1
}

function Count-Files {
    param([string]$Path, [string]$Filter)
    if (-not (Test-Path $Path)) {
        return 0
    }
    return (Get-ChildItem -Path $Path -File -Filter $Filter | Measure-Object).Count
}

function Invoke-Collector {
    param(
        [int]$DeckA,
        [int]$DeckB,
        [int]$Games,
        [int]$SeedOffset,
        [string]$RoundDataUserDir,
        [string]$RoundActionUserDir
    )

    $args = @(
        "--headless",
        "--path", $Project,
        "--quit-after", "9999",
        "res://scenes/tuner/ValueNetDataRunner.tscn",
        "--",
        "--games=$Games",
        "--deck-a=$DeckA",
        "--deck-b=$DeckB",
        "--encoder=$Encoder",
        "--pipeline-name=$PipelineName",
        "--data-dir=$RoundDataUserDir",
        "--action-data-dir=$RoundActionUserDir",
        "--export-action-data",
        "--seed-offset=$SeedOffset"
    )
    if ($script:CurrentBaselineValueUserPath -ne "") {
        $args += "--value-net=$($script:CurrentBaselineValueUserPath)"
    }
    if ($script:CurrentBaselineActionUserPath -ne "") {
        $args += "--action-scorer=$($script:CurrentBaselineActionUserPath)"
    }
    if ($script:CurrentBaselineInteractionUserPath -ne "") {
        $args += "--interaction-scorer=$($script:CurrentBaselineInteractionUserPath)"
    }

    Invoke-NativeCommand -FilePath $Godot -ArgumentList $args -StepName ("collector {0} vs {1}" -f $DeckA, $DeckB)
}

function Invoke-PythonTrain {
    param([string]$ScriptPath, [string[]]$ScriptArgs)
    $pythonArgs = @($ScriptPath)
    $pythonArgs += $ScriptArgs
    Invoke-NativeCommand -FilePath $Python -ArgumentList $pythonArgs -StepName ("training {0}" -f [System.IO.Path]::GetFileName($ScriptPath))
}

$UserRoot = Resolve-UserRoot
$RunsUserDir = "user://training_data/$DeckPrefix/runs"
$RunsGlobalDir = Globalize-UserPath $RunsUserDir
$RunRegistryUserDir = "user://training_runs/$PipelineSuffix"
$VersionRegistryUserDir = "user://ai_versions/$PipelineSuffix"
$VersionRegistryGlobalDir = Globalize-UserPath $VersionRegistryUserDir
$AiAgentsDir = Join-Path $UserRoot "ai_agents"
$LegacyValueNet = Join-Path $AiAgentsDir "${DeckPrefix}_value_net.json"
$LegacyActionScorer = Join-Path $AiAgentsDir "${DeckPrefix}_action_scorer.json"
$LegacyInteractionScorer = Join-Path $AiAgentsDir "${DeckPrefix}_interaction_scorer.json"
$LatestLogPointer = Join-Path $Project "${DeckPrefix}_decision_training_latest.txt"

$TrainScript = Join-Path $Project "scripts/training/train_value_net.py"
$ActionTrainScript = Join-Path $Project "scripts/training/train_action_scorer.py"
$InteractionTrainScript = Join-Path $Project "scripts/training/train_interaction_scorer.py"

$RunStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$RunId = "${DeckPrefix}_decision_run_${RunStamp}_$PID"
$RunUserDir = "$RunsUserDir/$RunId"
$RunDir = Join-Path $RunsGlobalDir $RunId
Ensure-Dir $RunDir
Ensure-Dir (Join-Path $RunDir "current_best")
Ensure-Dir $AiAgentsDir
Ensure-Dir $VersionRegistryGlobalDir

$CurrentBestValueUserPath = "$RunUserDir/current_best/${DeckPrefix}_value_net.json"
$CurrentBestValueGlobalPath = Join-Path $RunDir "current_best/${DeckPrefix}_value_net.json"
$CurrentBestActionUserPath = "$RunUserDir/current_best/${DeckPrefix}_action_scorer.json"
$CurrentBestActionGlobalPath = Join-Path $RunDir "current_best/${DeckPrefix}_action_scorer.json"
$CurrentBestInteractionUserPath = "$RunUserDir/current_best/${DeckPrefix}_interaction_scorer.json"
$CurrentBestInteractionGlobalPath = Join-Path $RunDir "current_best/${DeckPrefix}_interaction_scorer.json"
$LogPath = Join-Path $RunDir "${DeckPrefix}_decision_training.log"

Set-Content -Path $LatestLogPointer -Value $LogPath
Set-Content -Path $LogPath -Value ""

$CurrentBaselineSource = "greedy-bootstrap"
$CurrentBaselineVersionId = ""
$CurrentBaselineDisplayName = ""
$CurrentBaselineValueUserPath = ""
$CurrentBaselineValueGlobalPath = ""
$CurrentBaselineActionUserPath = ""
$CurrentBaselineActionGlobalPath = ""
$CurrentBaselineInteractionUserPath = ""
$CurrentBaselineInteractionGlobalPath = ""
$Promotions = 0

$approved = Get-LatestApprovedBaseline (Join-Path $VersionRegistryGlobalDir "index.json")
if ($null -ne $approved -and [string]$approved.value_net_path -ne "") {
    $CurrentBaselineVersionId = [string]$approved.version_id
    $CurrentBaselineDisplayName = [string]$approved.display_name
    $CurrentBaselineValueUserPath = [string]$approved.value_net_path
    $CurrentBaselineActionUserPath = [string]$approved.action_scorer_path
    $CurrentBaselineInteractionUserPath = [string]$approved.interaction_scorer_path
    $CurrentBaselineSource = "approved-playable"
    Sync-CurrentBest $CurrentBaselineValueUserPath $CurrentBaselineActionUserPath $CurrentBaselineInteractionUserPath
} elseif (Test-Path $LegacyValueNet) {
    Copy-Item -Force -Path $LegacyValueNet -Destination $CurrentBestValueGlobalPath
    $CurrentBaselineValueUserPath = $CurrentBestValueUserPath
    $CurrentBaselineValueGlobalPath = $CurrentBestValueGlobalPath
    $CurrentBaselineSource = "legacy-champion"
    Copy-IfExists $LegacyActionScorer $CurrentBestActionGlobalPath | Out-Null
    if (Test-Path $CurrentBestActionGlobalPath) {
        $CurrentBaselineActionUserPath = $CurrentBestActionUserPath
        $CurrentBaselineActionGlobalPath = $CurrentBestActionGlobalPath
    }
    Copy-IfExists $LegacyInteractionScorer $CurrentBestInteractionGlobalPath | Out-Null
    if (Test-Path $CurrentBestInteractionGlobalPath) {
        $CurrentBaselineInteractionUserPath = $CurrentBestInteractionUserPath
        $CurrentBaselineInteractionGlobalPath = $CurrentBestInteractionGlobalPath
    }
}

Write-Log "===== $DeckName Decision Training ====="
Write-Log "Run ID: $RunId"
Write-Log "Start: $(Get-Date)"
Write-Log "Pipeline: $PipelineName"
Write-Log "Encoder: $Encoder"
Write-Log "Optimized deck: $OptimizedDeck"
Write-Log "Opponents: $($Opponents -join ', ')"
Write-Log "Time budget: ${TimeBudgetSeconds}s"
Write-Log "Baseline source: $CurrentBaselineSource"
if ($CurrentBaselineVersionId -ne "") {
    Write-Log "Baseline version: $CurrentBaselineVersionId"
}
Write-Log ""

$StartTs = Get-Date
for ($round = 1; $round -le $Rounds; $round++) {
    if (((Get-Date) - $StartTs).TotalSeconds -ge $TimeBudgetSeconds) {
        Write-Log "[budget] stopping before round $round; time budget reached"
        break
    }

    $roundLabel = "{0:d2}" -f $round
    $RoundDir = Join-Path $RunDir "round_$roundLabel"
    $RoundUserDir = "$RunUserDir/round_$roundLabel"
    $RoundDataDir = Join-Path $RoundDir "self_play"
    $RoundActionDataDir = Join-Path $RoundDir "action_decisions"
    $RoundModelDir = Join-Path $RoundDir "models"
    $RoundBenchmarkDir = Join-Path $RoundDir "benchmark"
    $RoundDataUserDir = "$RoundUserDir/self_play"
    $RoundActionUserDir = "$RoundUserDir/action_decisions"
    Ensure-Dir $RoundDataDir
    Ensure-Dir $RoundActionDataDir
    Ensure-Dir $RoundModelDir
    Ensure-Dir $RoundBenchmarkDir

    $RoundValueGlobalPath = Join-Path $RoundModelDir "${DeckPrefix}_value_net_candidate_round_$roundLabel.json"
    $RoundValueUserPath = "$RoundUserDir/models/${DeckPrefix}_value_net_candidate_round_$roundLabel.json"
    $RoundActionGlobalPath = Join-Path $RoundModelDir "${DeckPrefix}_action_scorer_candidate_round_$roundLabel.json"
    $RoundActionUserPath = "$RoundUserDir/models/${DeckPrefix}_action_scorer_candidate_round_$roundLabel.json"
    $RoundInteractionGlobalPath = Join-Path $RoundModelDir "${DeckPrefix}_interaction_scorer_candidate_round_$roundLabel.json"
    $RoundInteractionUserPath = "$RoundUserDir/models/${DeckPrefix}_interaction_scorer_candidate_round_$roundLabel.json"
    $RoundSummaryGlobalPath = Join-Path $RoundBenchmarkDir "summary.json"
    $RoundSummaryUserPath = "$RoundUserDir/benchmark/summary.json"
    $RoundAnomalyUserPath = "$RoundUserDir/benchmark/anomaly_summary.json"
    $RoundRunId = "${RunId}_round_$roundLabel"

    Write-Log "========== ROUND $round =========="
    Write-Log "Time: $(Get-Date)"
    Write-Log "[R$round] Collecting mirror ($MirrorGames games)..."
    Invoke-Collector -DeckA $OptimizedDeck -DeckB $OptimizedDeck -Games $MirrorGames -SeedOffset ($round * 100000) -RoundDataUserDir $RoundDataUserDir -RoundActionUserDir $RoundActionUserDir
    Write-Log "[R$round] Mirror done"

    foreach ($opponent in $Opponents) {
        Write-Log "[R$round] Collecting vs $opponent ($CrossGames games)..."
        Invoke-Collector -DeckA $OptimizedDeck -DeckB $opponent -Games $CrossGames -SeedOffset ($round * 100000 + $opponent) -RoundDataUserDir $RoundDataUserDir -RoundActionUserDir $RoundActionUserDir
        Write-Log "[R$round] vs $opponent done"
    }

    $dataCount = Count-Files $RoundDataDir "game_*.json"
    $actionDataCount = Count-Files $RoundActionDataDir "*.json"
    Write-Log "[R$round] Value files: $dataCount"
    Write-Log "[R$round] Action files: $actionDataCount"
    if ($dataCount -eq 0 -or $actionDataCount -eq 0) {
        Write-Log "[R$round] Missing training artifacts; skipping round."
        Write-Log ""
        continue
    }

    Write-Log "[R$round] Training value net..."
    Invoke-PythonTrain -ScriptPath $TrainScript -ScriptArgs @(
        "--data-dir", $RoundDataDir,
        "--decision-data-dir", $RoundActionDataDir,
        "--output", $RoundValueGlobalPath,
        "--hidden1", "128", "--hidden2", "64", "--hidden3", "32",
        "--decision-state-weight", "$DecisionStateWeight",
        "--interaction-state-weight", "$InteractionStateWeight",
        "--epochs", "$ValueEpochs", "--teacher-weight", "$TeacherWeight", "--patience", "15",
        "--batch-size", "256", "--lr", "0.001"
    )

    Write-Log "[R$round] Training action scorer..."
    Invoke-PythonTrain -ScriptPath $ActionTrainScript -ScriptArgs @(
        "--data-dir", $RoundActionDataDir,
        "--output", $RoundActionGlobalPath,
        "--epochs", "$ActionEpochs",
        "--batch-size", "256", "--lr", "0.001"
    )

    Write-Log "[R$round] Training interaction scorer..."
    Invoke-PythonTrain -ScriptPath $InteractionTrainScript -ScriptArgs @(
        "--data-dir", $RoundActionDataDir,
        "--output", $RoundInteractionGlobalPath,
        "--epochs", "$ActionEpochs",
        "--batch-size", "256", "--lr", "0.001"
    )

    if (-not (Test-Path $RoundValueGlobalPath) -or -not (Test-Path $RoundActionGlobalPath) -or -not (Test-Path $RoundInteractionGlobalPath)) {
        Write-Log "[R$round] Candidate model missing; skipping benchmark."
        Write-Log ""
        continue
    }

    $roundGateThreshold = if ($CurrentBaselineValueUserPath -eq "") { $BootstrapGateThreshold } else { $BenchmarkGateThreshold }
    Write-Log "[R$round] Benchmark gate via BenchmarkRunner (threshold=$roundGateThreshold)..."
    $benchmarkArgs = @(
        "--headless",
        "--path", $Project,
        "--quit-after", "3600",
        "res://scenes/tuner/BenchmarkRunner.tscn",
        "--",
        "--pipeline-name=$PipelineName",
        "--seed-set=$BenchmarkSeedSet",
        "--gate-threshold=$roundGateThreshold",
        "--value-net-a=$RoundValueUserPath",
        "--action-scorer-a=$RoundActionUserPath",
        "--interaction-scorer-a=$RoundInteractionUserPath",
        "--summary-output=$RoundSummaryUserPath",
        "--anomaly-output=$RoundAnomalyUserPath",
        "--run-id=$RoundRunId",
        "--run-dir=$RoundUserDir",
        "--run-registry-dir=$RunRegistryUserDir",
        "--version-registry-dir=$VersionRegistryUserDir",
        "--publish-display-name=$DeckName decision round $round candidate",
        "--baseline-source=$CurrentBaselineSource",
        "--baseline-version-id=$CurrentBaselineVersionId",
        "--baseline-display-name=$CurrentBaselineDisplayName",
        "--baseline-value-net=$CurrentBaselineValueUserPath",
        "--baseline-action-scorer=$CurrentBaselineActionUserPath",
        "--baseline-interaction-scorer=$CurrentBaselineInteractionUserPath"
    )
    if ($CurrentBaselineValueUserPath -ne "") { $benchmarkArgs += "--value-net-b=$CurrentBaselineValueUserPath" }
    if ($CurrentBaselineActionUserPath -ne "") { $benchmarkArgs += "--action-scorer-b=$CurrentBaselineActionUserPath" }
    if ($CurrentBaselineInteractionUserPath -ne "") { $benchmarkArgs += "--interaction-scorer-b=$CurrentBaselineInteractionUserPath" }

    $benchmarkFailed = $false
    try {
        Invoke-NativeCommand -FilePath $Godot -ArgumentList $benchmarkArgs -StepName ("benchmark round {0}" -f $round)
    } catch {
        $benchmarkFailed = $true
        if (Test-Path $RoundSummaryGlobalPath) {
            Write-Log "[R$round] Benchmark runner exited non-zero but produced summary; continuing with summary output."
        } else {
            Write-Log "[R$round] Benchmark runner failed: $($_.Exception.Message)"
        }
    }

    if (-not (Test-Path $RoundSummaryGlobalPath)) {
        Write-Log "[R$round] Benchmark summary missing."
        Write-Log ""
        continue
    }

    $summary = Get-Content -Raw -Path $RoundSummaryGlobalPath | ConvertFrom-Json
    $winRate = [double]$summary.win_rate_vs_current_best * 100.0
    $gatePassed = [bool]$summary.gate_passed
    if ($gatePassed) {
        Sync-CurrentBest $RoundValueUserPath $RoundActionUserPath $RoundInteractionUserPath
        $CurrentBaselineSource = "published-run"
        $Promotions += 1
        if ($benchmarkFailed) {
            Write-Log ("[R{0}] >>> PROMOTED ({1:N1}%) despite non-zero Godot exit code; summary gate passed." -f $round, $winRate)
        } else {
            Write-Log ("[R{0}] >>> PROMOTED ({1:N1}%)" -f $round, $winRate)
        }
    } else {
        if ($benchmarkFailed) {
            Write-Log ("[R{0}] >>> Rejected ({1:N1}%). Baseline unchanged; summary gate failed after non-zero Godot exit code." -f $round, $winRate)
        } else {
            Write-Log ("[R{0}] >>> Rejected ({1:N1}%). Baseline unchanged." -f $round, $winRate)
        }
    }
    Write-Log ""
}

Write-Log "===== COMPLETE ====="
Write-Log "End: $(Get-Date)"
Write-Log "Promotions: $Promotions"
Write-Log "Current best value: $CurrentBestValueGlobalPath"
Write-Log "Current best action: $CurrentBestActionGlobalPath"
Write-Log "Current best interaction: $CurrentBestInteractionGlobalPath"
