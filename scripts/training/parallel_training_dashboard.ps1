$ErrorActionPreference = 'Stop'

function Read-JsonFileUtf8 {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Path
	)

	if (-not (Test-Path -LiteralPath $Path)) {
		throw "JSON file not found: $Path"
	}

	$utf8 = New-Object System.Text.UTF8Encoding($false, $true)
	$raw = [System.IO.File]::ReadAllText([System.IO.Path]::GetFullPath($Path), $utf8)
	return ($raw | ConvertFrom-Json)
}

function Get-ParallelTrainingManifestPath {
	param(
		[Parameter(Mandatory = $true)]
		[string]$WorkspaceRoot
	)

	return (Join-Path ([System.IO.Path]::GetFullPath($WorkspaceRoot)) 'parallel_training_launch_manifest.json')
}

function Read-ParallelTrainingManifest {
	param(
		[Parameter(Mandatory = $true)]
		[string]$WorkspaceRoot
	)

	$manifestPath = Get-ParallelTrainingManifestPath -WorkspaceRoot $WorkspaceRoot
	if (-not (Test-Path -LiteralPath $manifestPath)) {
		throw "Launch manifest not found: $manifestPath"
	}

	return (Read-JsonFileUtf8 -Path $manifestPath)
}

function Get-LanePhaseFromLog {
	param(
		[Parameter(Mandatory = $true)]
		[string]$LogPath
	)

	if (-not (Test-Path -LiteralPath $LogPath)) {
		return 'pending'
	}

	$content = Get-Content -Path $LogPath -Raw -ErrorAction SilentlyContinue
	if ([string]::IsNullOrWhiteSpace($content)) {
		return 'pending'
	}

	if ($content -match '===== Training Complete =====') {
		return 'complete'
	}
	if ($content -match '\[phase 3\]') {
		return 'phase3'
	}
	if ($content -match '\[phase 2\]') {
		return 'phase2'
	}
	if ($content -match '\[phase 1\]') {
		return 'phase1'
	}
	return 'running'
}

function Get-LaneLatestRunDir {
	param(
		[Parameter(Mandatory = $true)]
		[string]$LaneRoot
	)

	$runsRoot = Join-Path $LaneRoot 'training_data\runs'
	if (-not (Test-Path -LiteralPath $runsRoot)) {
		return $null
	}

	return (Get-ChildItem -Path $runsRoot -Directory -ErrorAction SilentlyContinue |
		Sort-Object LastWriteTimeUtc |
		Select-Object -Last 1)
}

function Get-LaneStatusLabel {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Phase,

		[Parameter(Mandatory = $false)]
		[string]$StdErrText = '',

		[Parameter(Mandatory = $false)]
		[datetime]$LastProgressAt = [datetime]::MinValue
	)

	if (-not [string]::IsNullOrWhiteSpace($StdErrText)) {
		return 'warning'
	}
	if ($Phase -eq 'complete') {
		return 'complete'
	}
	if ($LastProgressAt -ne [datetime]::MinValue -and $LastProgressAt -lt (Get-Date).AddMinutes(-15)) {
		return 'idle'
	}
	return 'running'
}

function Get-LaneBenchmarkSummary {
	param(
		[Parameter(Mandatory = $true)]
		[string]$RunDir
	)

	$summaryPath = Join-Path $RunDir 'benchmark\summary.json'
	if (-not (Test-Path -LiteralPath $summaryPath)) {
		return [ordered]@{
			has_summary = $false
			parse_error = ''
			gate = ''
			wins = ''
			win_rate = ''
			total_matches = 0
			pairings = 0
			timeouts = 0
			failures = 0
		}
	}

	try {
		$summary = Read-JsonFileUtf8 -Path $summaryPath
	} catch {
		return [ordered]@{
			has_summary = $true
			parse_error = $_.Exception.Message
			gate = 'parse_error'
			wins = '?'
			win_rate = '?'
			total_matches = 0
			pairings = 0
			timeouts = 0
			failures = 0
		}
	}
	$totalMatches = [int]($summary.total_matches)
	$winsA = [int]($summary.version_a_wins)
	$winsB = [int]($summary.version_b_wins)
	$winRate = [double]($summary.version_a_win_rate)
	$pairings = 0
	if ($null -ne $summary.pairing_results) {
		$pairings = @($summary.pairing_results).Count
	}
	return [ordered]@{
		has_summary = $true
		parse_error = ''
		gate = if ([bool]$summary.gate_passed) { 'pass' } else { 'fail' }
		wins = ('{0}-{1}' -f $winsA, $winsB)
		win_rate = ('{0:N1}%' -f ($winRate * 100.0))
		total_matches = $totalMatches
		pairings = $pairings
		timeouts = [int]($summary.timeouts)
		failures = [int]($summary.failures)
	}
}

function Get-LaneProgressSnapshot {
	param(
		[Parameter(Mandatory = $true)]
		[string]$RunDir
	)

	$statusPath = Join-Path $RunDir 'status.json'
	if (-not (Test-Path -LiteralPath $statusPath)) {
		return [ordered]@{
			has_progress = $false
			parse_error = ''
			generation = ''
			wins = ''
			win_rate = ''
			last_generation = ''
			accepted_generations = 0
		}
	}

	try {
		$status = Read-JsonFileUtf8 -Path $statusPath
	} catch {
		return [ordered]@{
			has_progress = $false
			parse_error = $_.Exception.Message
			generation = ''
			wins = ''
			win_rate = ''
			last_generation = ''
			accepted_generations = 0
		}
	}
	$generationCurrent = [int]($status.generation_current)
	$generationTotal = [int]($status.generation_total)
	$cumulativeAgentAWins = [int]($status.cumulative_agent_a_wins)
	$cumulativeAgentBWins = [int]($status.cumulative_agent_b_wins)
	$cumulativeWinRate = [double]($status.cumulative_agent_a_win_rate)
	$lastAgentAWins = [int]($status.last_generation_agent_a_wins)
	$lastAgentBWins = [int]($status.last_generation_agent_b_wins)
	$lastWinRate = [double]($status.last_generation_win_rate)
	return [ordered]@{
		has_progress = $true
		parse_error = ''
		generation = ('{0}/{1}' -f $generationCurrent, $generationTotal)
		wins = ('{0}-{1}' -f $cumulativeAgentAWins, $cumulativeAgentBWins)
		win_rate = ('{0:N1}%' -f ($cumulativeWinRate * 100.0))
		last_generation = ('{0}-{1} ({2:N1}%)' -f $lastAgentAWins, $lastAgentBWins, ($lastWinRate * 100.0))
		accepted_generations = [int]($status.accepted_generations)
	}
}

function Get-ParallelTrainingLaneStatus {
	param(
		[Parameter(Mandatory = $true)]
		$LaneProcess
	)

	$laneRoot = Split-Path -Parent ([string]$LaneProcess.launch_script_path)
	$stdoutPath = [string]$LaneProcess.stdout_log
	$stderrPath = [string]$LaneProcess.stderr_log
	$stdoutItem = Get-Item -LiteralPath $stdoutPath -ErrorAction SilentlyContinue
	$stderrText = ''
	$stderrBytes = 0
	if (Test-Path -LiteralPath $stderrPath) {
		$stderrItem = Get-Item -LiteralPath $stderrPath -ErrorAction SilentlyContinue
		if ($stderrItem) {
			$stderrBytes = [int64]$stderrItem.Length
		}
		$stderrText = Get-Content -Path $stderrPath -Raw -ErrorAction SilentlyContinue
	}

	$phase = Get-LanePhaseFromLog -LogPath $stdoutPath
	$latestRunDir = Get-LaneLatestRunDir -LaneRoot $laneRoot
	$sampleCount = 0
	$hasValueNet = $false
	$hasBenchmark = $false
	$runId = ''
	$benchmarkSummary = [ordered]@{
		has_summary = $false
		gate = ''
		wins = ''
		win_rate = ''
		total_matches = 0
		pairings = 0
		timeouts = 0
		failures = 0
	}
	$progressSnapshot = [ordered]@{
		has_progress = $false
		generation = ''
		wins = ''
		win_rate = ''
		last_generation = ''
		accepted_generations = 0
	}
	if ($latestRunDir) {
		$runId = $latestRunDir.Name
		$selfPlayDir = Join-Path $latestRunDir.FullName 'self_play'
		$modelsDir = Join-Path $latestRunDir.FullName 'models'
		$benchmarkDir = Join-Path $latestRunDir.FullName 'benchmark'
		if (Test-Path -LiteralPath $selfPlayDir) {
			$sampleCount = @(
				Get-ChildItem -Path $selfPlayDir -Filter 'game_*.json' -File -ErrorAction SilentlyContinue
			).Count
		}
		if (Test-Path -LiteralPath $modelsDir) {
			$hasValueNet = @(
				Get-ChildItem -Path $modelsDir -Filter 'value_net*.json' -File -ErrorAction SilentlyContinue
			).Count -gt 0
		}
		$hasBenchmark = Test-Path -LiteralPath (Join-Path $benchmarkDir 'summary.json')
		$benchmarkSummary = Get-LaneBenchmarkSummary -RunDir $latestRunDir.FullName
		$progressSnapshot = Get-LaneProgressSnapshot -RunDir $latestRunDir.FullName
	}

	$lastProgressAt = [datetime]::MinValue
	$stdoutBytes = 0
	if ($stdoutItem) {
		$stdoutBytes = [int64]$stdoutItem.Length
		$lastProgressAt = [datetime]$stdoutItem.LastWriteTime
	}
	$status = Get-LaneStatusLabel -Phase $phase -StdErrText $stderrText -LastProgressAt $lastProgressAt

	return [ordered]@{
		lane_id = [string]$LaneProcess.lane_id
		group = [string]$LaneProcess.group
		recipe_id = [string]$LaneProcess.recipe_id
		pid = [int]$LaneProcess.pid
		run_id = $runId
		phase = $phase
		status = $status
		last_progress_at = if ($lastProgressAt -eq [datetime]::MinValue) { '' } else { $lastProgressAt.ToString('MM-dd HH:mm:ss') }
		stdout_bytes = $stdoutBytes
		stderr_bytes = $stderrBytes
		sample_count = $sampleCount
		has_value_net = $hasValueNet
		has_benchmark = $hasBenchmark
		has_progress = [bool]$progressSnapshot.has_progress
		progress_generation = [string]$progressSnapshot.generation
		progress_wins = [string]$progressSnapshot.wins
		progress_win_rate = [string]$progressSnapshot.win_rate
		progress_last_gen = [string]$progressSnapshot.last_generation
		accepted_generations = [int]$progressSnapshot.accepted_generations
		benchmark_gate = [string]$benchmarkSummary.gate
		benchmark_wins = [string]$benchmarkSummary.wins
		benchmark_win_rate = [string]$benchmarkSummary.win_rate
		benchmark_total_matches = [int]$benchmarkSummary.total_matches
		benchmark_pairings = [int]$benchmarkSummary.pairings
		benchmark_timeouts = [int]$benchmarkSummary.timeouts
		benchmark_failures = [int]$benchmarkSummary.failures
		stdout_log = $stdoutPath
		stderr_log = $stderrPath
	}
}

function Get-ParallelTrainingDashboardData {
	param(
		[Parameter(Mandatory = $true)]
		[string]$WorkspaceRoot
	)

	$manifest = Read-ParallelTrainingManifest -WorkspaceRoot $WorkspaceRoot
	$laneStatuses = @($manifest.processes | ForEach-Object {
		[pscustomobject](Get-ParallelTrainingLaneStatus -LaneProcess $_)
	})

	$summary = [ordered]@{
		total_lanes = $laneStatuses.Count
		running_lanes = @($laneStatuses | Where-Object { $_.status -eq 'running' -or $_.status -eq 'idle' }).Count
		completed_lanes = @($laneStatuses | Where-Object { $_.phase -eq 'complete' }).Count
		warning_lanes = @($laneStatuses | Where-Object { $_.status -eq 'warning' }).Count
		progress_lanes = @($laneStatuses | Where-Object { $_.has_progress }).Count
		benchmark_lanes = @($laneStatuses | Where-Object { $_.has_benchmark }).Count
		benchmark_passed_lanes = @($laneStatuses | Where-Object { $_.benchmark_gate -eq 'pass' }).Count
		phase1_lanes = @($laneStatuses | Where-Object { $_.phase -eq 'phase1' }).Count
		phase2_lanes = @($laneStatuses | Where-Object { $_.phase -eq 'phase2' }).Count
		phase3_lanes = @($laneStatuses | Where-Object { $_.phase -eq 'phase3' }).Count
		best_benchmark_win_rate = ''
		last_refreshed = (Get-Date).ToString('MM-dd HH:mm:ss')
	}
	$bestLane = @($laneStatuses | Where-Object { $_.benchmark_total_matches -gt 0 } | Sort-Object benchmark_total_matches, benchmark_win_rate -Descending | Select-Object -First 1)
	if ($bestLane.Count -gt 0) {
		$summary.best_benchmark_win_rate = [string]$bestLane[0].benchmark_win_rate
	}

	return [ordered]@{
		workspace_root = [string]$manifest.workspace_root
		approved_baseline = $manifest.approved_baseline
		summary = $summary
		lanes = $laneStatuses
	}
}

function Format-ByteSize {
	param(
		[int64]$Bytes
	)

	if ($Bytes -ge 1MB) {
		return ('{0:N1}M' -f ($Bytes / 1MB))
	}
	if ($Bytes -ge 1KB) {
		return ('{0:N1}K' -f ($Bytes / 1KB))
	}
	return ("{0}B" -f $Bytes)
}

function Show-ParallelTrainingDashboard {
	param(
		[Parameter(Mandatory = $true)]
		[string]$WorkspaceRoot,

		[int]$RefreshSeconds = 5
	)

	while ($true) {
		$data = Get-ParallelTrainingDashboardData -WorkspaceRoot $WorkspaceRoot
		Clear-Host
		Write-Host "PTCG Parallel Training Dashboard"
		Write-Host "Workspace: $($data.workspace_root)"
		Write-Host "Baseline:  $($data.approved_baseline.version_id) | $($data.approved_baseline.display_name)"
		Write-Host ("Summary:   total={0} running={1} complete={2} warning={3} p1={4} p2={5} p3={6} refreshed={7}" -f `
			$data.summary.total_lanes,
			$data.summary.running_lanes,
			$data.summary.completed_lanes,
			$data.summary.warning_lanes,
			$data.summary.phase1_lanes,
			$data.summary.phase2_lanes,
			$data.summary.phase3_lanes,
			$data.summary.last_refreshed)
		Write-Host ("Benchmark: lanes={0} passed={1} best={2}" -f `
			$data.summary.benchmark_lanes,
			$data.summary.benchmark_passed_lanes,
			$(if ([string]::IsNullOrWhiteSpace($data.summary.best_benchmark_win_rate)) { '-' } else { $data.summary.best_benchmark_win_rate }))
		Write-Host ("Progress:  lanes={0}" -f $data.summary.progress_lanes)
		Write-Host ''

		$rows = $data.lanes | Sort-Object lane_id | ForEach-Object {
			[pscustomobject]@{
				Lane = $_.lane_id
				Group = $_.group
				Recipe = $_.recipe_id
				Status = $_.status
				Phase = $_.phase
				Gen = if ($_.has_progress) { $_.progress_generation } else { '-' }
				PhaseWL = if ($_.has_progress) { $_.progress_wins } else { '-' }
				PhaseWR = if ($_.has_progress) { $_.progress_win_rate } else { '-' }
				LastGen = if ($_.has_progress) { $_.progress_last_gen } else { '-' }
				Acc = if ($_.has_progress) { $_.accepted_generations } else { '-' }
				Samples = $_.sample_count
				ValueNet = if ($_.has_value_net) { 'yes' } else { 'no' }
				Bench = if ($_.has_benchmark) { $_.benchmark_gate } else { 'no' }
				BenchWL = if ($_.has_benchmark) { $_.benchmark_wins } else { '-' }
				BenchWR = if ($_.has_benchmark) { $_.benchmark_win_rate } else { '-' }
				Stdout = Format-ByteSize -Bytes $_.stdout_bytes
				StdErr = Format-ByteSize -Bytes $_.stderr_bytes
				Updated = $_.last_progress_at
				Run = $_.run_id
			}
		}

		$rows | Format-Table -AutoSize

		$warnings = @($data.lanes | Where-Object { $_.status -eq 'warning' -or $_.status -eq 'idle' })
		if ($warnings.Count -gt 0) {
			Write-Host ''
			Write-Host 'Attention:'
			$warnings | Sort-Object lane_id | ForEach-Object {
				Write-Host ("  {0} status={1} stderr={2} updated={3}" -f $_.lane_id, $_.status, (Format-ByteSize -Bytes $_.stderr_bytes), $_.last_progress_at)
			}
		}

		Start-Sleep -Seconds $RefreshSeconds
	}
}
