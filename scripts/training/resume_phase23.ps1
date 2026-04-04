param(
	[string]$ScriptWorkspaceRoot = '',
	[string]$ScriptGodotPath = '',
	[string[]]$ScriptLaneIds = @(),
	[switch]$LaunchParallel,
	[int]$ScriptMaxParallelValueNets = 2,
	[string]$ScriptValueNetDevice = 'auto',
	[int]$ScriptValueNetNumThreads = 1,
	[int]$ScriptValueNetInteropThreads = 1,
	[int]$ScriptActionScorerEpochs = 20
)

$ErrorActionPreference = 'Stop'

function Get-ResumeRepoRoot {
	return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
}

function ConvertTo-ResumeSingleQuotedLiteral {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Value
	)
	return "'" + ($Value -replace "'", "''") + "'"
}

function Get-ValueNetSemaphoreRoot {
	param(
		[Parameter(Mandatory = $true)]
		[string]$WorkspaceRoot
	)
	$root = Join-Path ([System.IO.Path]::GetFullPath($WorkspaceRoot)) '.phase2_slots'
	New-Item -ItemType Directory -Force -Path $root | Out-Null
	return $root
}

function Acquire-ValueNetTrainingSlot {
	param(
		[Parameter(Mandatory = $true)]
		[string]$WorkspaceRoot,

		[int]$MaxParallelValueNets = 2
	)

	$slotCount = [Math]::Max(1, $MaxParallelValueNets)
	$slotRoot = Get-ValueNetSemaphoreRoot -WorkspaceRoot $WorkspaceRoot
	while ($true) {
		for ($slotIndex = 0; $slotIndex -lt $slotCount; $slotIndex += 1) {
			$slotPath = Join-Path $slotRoot ("slot_{0:D2}" -f $slotIndex)
			try {
				New-Item -ItemType Directory -Path $slotPath -ErrorAction Stop | Out-Null
				return $slotPath
			} catch {
				continue
			}
		}
		Start-Sleep -Seconds 2
	}
}

function Release-ValueNetTrainingSlot {
	param(
		[string]$SlotPath
	)
	if (-not [string]::IsNullOrWhiteSpace($SlotPath) -and (Test-Path $SlotPath)) {
		Remove-Item -LiteralPath $SlotPath -Recurse -Force
	}
}

function Resolve-ResumePythonCommand {
	$candidates = @(
		@{ FilePath = 'py'; Arguments = @('-3.13') },
		@{ FilePath = 'py'; Arguments = @('-3.10') },
		@{ FilePath = 'python'; Arguments = @() }
	)

	foreach ($candidate in $candidates) {
		try {
			& $candidate.FilePath @($candidate.Arguments + @('-c', 'import numpy, torch')) *> $null
			if ($LASTEXITCODE -eq 0) {
				return $candidate
			}
		} catch {
			continue
		}
	}

	throw 'Unable to resolve a Python interpreter with numpy and torch.'
}

function Get-ResumePhase23LaneSpecs {
	param(
		[Parameter(Mandatory = $true)]
		[string]$WorkspaceRoot
	)

	$workspaceRootAbsolute = [System.IO.Path]::GetFullPath($WorkspaceRoot)
	$planPath = Join-Path $workspaceRootAbsolute 'parallel_training_plan.json'
	if (-not (Test-Path $planPath)) {
		throw "Missing parallel training plan: $planPath"
	}

	$plan = Get-Content -Path $planPath -Raw | ConvertFrom-Json
	$laneSpecs = @()
	foreach ($lane in $plan.lanes) {
		$laneRoot = [string]$lane.lane_root
		$runRoot = Join-Path $laneRoot 'training_data\runs'
		if (-not (Test-Path $runRoot)) {
			continue
		}

		$latestRun = Get-ChildItem -Path $runRoot -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
		if ($null -eq $latestRun) {
			continue
		}

		$laneUserRoot = Join-Path ([string]$lane.appdata_root) 'Godot\app_userdata\PTCG Train'
		$sampleSourceDir = Join-Path $laneUserRoot 'training_data'
		$candidateAgentDir = Join-Path $laneUserRoot 'ai_agents'
		$candidateAgent = Get-ChildItem -Path $candidateAgentDir -Filter 'agent_*.json' -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1

		$runDataDir = Join-Path $latestRun.FullName 'self_play'
		$runModelDir = Join-Path $latestRun.FullName 'models'
		$runActionDataDir = Join-Path $latestRun.FullName 'action_decisions'
		$benchmarkDir = Join-Path $latestRun.FullName 'benchmark'
		$actionSampleSourceDir = Join-Path $sampleSourceDir 'action_decisions'
		$sampleSourceCount = 0
		if (Test-Path $sampleSourceDir) {
			$sampleSourceCount = (Get-ChildItem -Path $sampleSourceDir -File -Filter 'game_*.json' -ErrorAction SilentlyContinue | Measure-Object).Count
		}
		$runDataCount = 0
		if (Test-Path $runDataDir) {
			$runDataCount = (Get-ChildItem -Path $runDataDir -File -Filter 'game_*.json' -ErrorAction SilentlyContinue | Measure-Object).Count
		}
		$actionSampleSourceCount = 0
		if (Test-Path $actionSampleSourceDir) {
			$actionSampleSourceCount = (Get-ChildItem -Path $actionSampleSourceDir -File -Filter '*.json' -ErrorAction SilentlyContinue | Measure-Object).Count
		}
		$runActionDataCount = 0
		if (Test-Path $runActionDataDir) {
			$runActionDataCount = (Get-ChildItem -Path $runActionDataDir -File -Filter '*.json' -ErrorAction SilentlyContinue | Measure-Object).Count
		}

		$laneSpecs += [pscustomobject]@{
			workspace_root = $workspaceRootAbsolute
			pipeline_name = [string]$plan.pipeline_name
			lane_id = [string]$lane.lane_id
			group = [string]$lane.group
			recipe_id = [string]$lane.recipe_id
			lane_root = $laneRoot
			appdata_root = [string]$lane.appdata_root
			run_id = [string]$latestRun.Name
			run_dir = [string]$latestRun.FullName
			run_data_dir = $runDataDir
			run_model_dir = $runModelDir
			run_action_data_dir = $runActionDataDir
			benchmark_dir = $benchmarkDir
			status_path = (Join-Path $latestRun.FullName 'status.json')
			phase1_anomaly_path = (Join-Path $latestRun.FullName 'phase1_anomalies.json')
			run_anomaly_path = (Join-Path $latestRun.FullName 'anomaly_summary.json')
			benchmark_summary_path = (Join-Path $benchmarkDir 'summary.json')
			candidate_value_net_path = (Join-Path $runModelDir 'value_net_resumed.json')
			candidate_action_scorer_path = (Join-Path $runModelDir 'action_scorer_resumed.json')
			sample_source_dir = $sampleSourceDir
			sample_source_count = $sampleSourceCount
			run_data_count = $runDataCount
			action_sample_source_dir = $actionSampleSourceDir
			action_sample_source_count = $actionSampleSourceCount
			run_action_data_count = $runActionDataCount
			candidate_agent_config_path = if ($null -ne $candidateAgent) { $candidateAgent.FullName } else { '' }
			baseline_agent_config_path = [string]$lane.baseline.agent_config_path
			baseline_value_net_path = [string]$lane.baseline.value_net_path
			baseline_action_scorer_path = [string]$lane.baseline.action_scorer_path
			baseline_source = [string]$lane.baseline.source
			baseline_version_id = [string]$lane.baseline.version_id
			baseline_display_name = [string]$lane.baseline.display_name
			epochs = [int]$lane.epochs
		}
	}

	return @($laneSpecs)
}

function Move-ResumeLaneSamples {
	param(
		[Parameter(Mandatory = $true)]
		$LaneSpec
	)

	New-Item -ItemType Directory -Force -Path $LaneSpec.run_data_dir | Out-Null
	if (-not (Test-Path $LaneSpec.sample_source_dir)) {
		return 0
	}

	$movedCount = 0
	foreach ($file in (Get-ChildItem -Path $LaneSpec.sample_source_dir -File -Filter 'game_*.json' -ErrorAction SilentlyContinue)) {
		Move-Item -LiteralPath $file.FullName -Destination (Join-Path $LaneSpec.run_data_dir $file.Name) -Force
		$movedCount += 1
	}
	return $movedCount
}

function Move-ResumeLaneActionSamples {
	param(
		[Parameter(Mandatory = $true)]
		$LaneSpec
	)

	New-Item -ItemType Directory -Force -Path $LaneSpec.run_action_data_dir | Out-Null
	if (-not (Test-Path $LaneSpec.action_sample_source_dir)) {
		return 0
	}

	$movedCount = 0
	foreach ($file in (Get-ChildItem -Path $LaneSpec.action_sample_source_dir -File -Filter '*.json' -ErrorAction SilentlyContinue)) {
		Move-Item -LiteralPath $file.FullName -Destination (Join-Path $LaneSpec.run_action_data_dir $file.Name) -Force
		$movedCount += 1
	}
	return $movedCount
}

function Invoke-ResumePhase23Lane {
	param(
		[Parameter(Mandatory = $true)]
		$LaneSpec,

		[Parameter(Mandatory = $true)]
		[string]$GodotPath,

		[Parameter(Mandatory = $true)]
		$PythonCommand,

		[int]$MaxParallelValueNets = 2,

		[string]$ValueNetDevice = 'auto',

		[int]$ValueNetNumThreads = 1,

		[int]$ValueNetInteropThreads = 1,

		[int]$ActionScorerEpochs = 20
	)

	$movedCount = Move-ResumeLaneSamples -LaneSpec $LaneSpec
	$movedActionCount = Move-ResumeLaneActionSamples -LaneSpec $LaneSpec
	$sampleCount = (Get-ChildItem -Path $LaneSpec.run_data_dir -File -Filter 'game_*.json' -ErrorAction SilentlyContinue | Measure-Object).Count
	$actionSampleCount = (Get-ChildItem -Path $LaneSpec.run_action_data_dir -File -Filter '*.json' -ErrorAction SilentlyContinue | Measure-Object).Count
	if ($sampleCount -le 0) {
		return [pscustomobject]@{
			lane_id = $LaneSpec.lane_id
			run_id = $LaneSpec.run_id
			moved_samples = $movedCount
			moved_action_samples = $movedActionCount
			sample_count = $sampleCount
			action_sample_count = $actionSampleCount
			phase2 = 'skipped'
			action_scorer = 'skipped'
			phase3 = 'skipped'
			reason = 'no_training_samples'
		}
	}
	if ([string]::IsNullOrWhiteSpace([string]$LaneSpec.candidate_agent_config_path)) {
		return [pscustomobject]@{
			lane_id = $LaneSpec.lane_id
			run_id = $LaneSpec.run_id
			moved_samples = $movedCount
			moved_action_samples = $movedActionCount
			sample_count = $sampleCount
			action_sample_count = $actionSampleCount
			phase2 = 'skipped'
			action_scorer = 'skipped'
			phase3 = 'skipped'
			reason = 'missing_candidate_agent_config'
		}
	}

	New-Item -ItemType Directory -Force -Path $LaneSpec.run_model_dir | Out-Null
	New-Item -ItemType Directory -Force -Path $LaneSpec.benchmark_dir | Out-Null

	$phase2Status = 'completed'
	$actionScorerStatus = 'completed'
	if (-not (Test-Path $LaneSpec.candidate_value_net_path)) {
		$slotPath = Acquire-ValueNetTrainingSlot -WorkspaceRoot $LaneSpec.workspace_root -MaxParallelValueNets $MaxParallelValueNets
		try {
			$trainArgs = @($PythonCommand.Arguments) + @(
				(Join-Path (Get-ResumeRepoRoot) 'scripts\training\train_value_net.py'),
				'--data-dir', $LaneSpec.run_data_dir,
				'--output', $LaneSpec.candidate_value_net_path,
				'--epochs', [string]$LaneSpec.epochs,
				'--batch-size', '256',
				'--lr', '0.001',
				'--device', $ValueNetDevice,
				'--num-threads', [string]$ValueNetNumThreads,
				'--interop-threads', [string]$ValueNetInteropThreads
			)
			& $PythonCommand.FilePath @trainArgs
			if ($LASTEXITCODE -ne 0 -or -not (Test-Path $LaneSpec.candidate_value_net_path)) {
				return [pscustomobject]@{
					lane_id = $LaneSpec.lane_id
					run_id = $LaneSpec.run_id
					moved_samples = $movedCount
					moved_action_samples = $movedActionCount
					sample_count = $sampleCount
					action_sample_count = $actionSampleCount
					phase2 = 'failed'
					action_scorer = 'skipped'
					phase3 = 'skipped'
					reason = 'value_net_training_failed'
				}
			}
		} finally {
			Release-ValueNetTrainingSlot -SlotPath $slotPath
		}
	} else {
		$phase2Status = 'existing'
	}

	if ($actionSampleCount -le 0) {
		$actionScorerStatus = 'skipped'
	} elseif (-not (Test-Path $LaneSpec.candidate_action_scorer_path)) {
		$actionArgs = @($PythonCommand.Arguments) + @(
			(Join-Path (Get-ResumeRepoRoot) 'scripts\training\train_action_scorer.py'),
			'--data-dir', $LaneSpec.run_action_data_dir,
			'--output', $LaneSpec.candidate_action_scorer_path,
			'--epochs', [string]$ActionScorerEpochs,
			'--batch-size', '256',
			'--lr', '0.001',
			'--device', $ValueNetDevice,
			'--num-threads', [string]$ValueNetNumThreads,
			'--interop-threads', [string]$ValueNetInteropThreads
		)
		& $PythonCommand.FilePath @actionArgs
		if ($LASTEXITCODE -ne 0 -or -not (Test-Path $LaneSpec.candidate_action_scorer_path)) {
			return [pscustomobject]@{
				lane_id = $LaneSpec.lane_id
				run_id = $LaneSpec.run_id
				moved_samples = $movedCount
				moved_action_samples = $movedActionCount
				sample_count = $sampleCount
				action_sample_count = $actionSampleCount
				phase2 = $phase2Status
				action_scorer = 'failed'
				phase3 = 'skipped'
				reason = 'action_scorer_training_failed'
			}
		}
	} else {
		$actionScorerStatus = 'existing'
	}

	$benchmarkCandidateActionScorerPath = ''
	if (Test-Path $LaneSpec.candidate_action_scorer_path) {
		$benchmarkCandidateActionScorerPath = $LaneSpec.candidate_action_scorer_path
	}

	$previousAppData = $env:APPDATA
	try {
		$env:APPDATA = $LaneSpec.appdata_root
		$benchmarkArgs = @(
			'--headless',
			'--path', (Get-ResumeRepoRoot),
			'res://scenes/tuner/BenchmarkRunner.tscn',
			'--',
			"--agent-a-config=$($LaneSpec.candidate_agent_config_path)",
			"--agent-b-config=$($LaneSpec.baseline_agent_config_path)",
			"--value-net-a=$($LaneSpec.candidate_value_net_path)",
			"--value-net-b=$($LaneSpec.baseline_value_net_path)",
			"--action-scorer-a=$($benchmarkCandidateActionScorerPath)",
			"--action-scorer-b=$($LaneSpec.baseline_action_scorer_path)",
			"--summary-output=$($LaneSpec.benchmark_summary_path)",
			"--anomaly-output=$($LaneSpec.run_anomaly_path)",
			"--phase1-anomaly-input=$($LaneSpec.phase1_anomaly_path)",
			"--run-id=$($LaneSpec.run_id)",
			"--pipeline-name=$($LaneSpec.pipeline_name)",
			"--run-dir=$($LaneSpec.run_dir)",
			'--run-registry-dir=user://training_runs',
			'--version-registry-dir=user://ai_versions',
			"--publish-display-name=resumed-$($LaneSpec.lane_id)",
			"--lane-recipe-id=$($LaneSpec.recipe_id)",
			"--lane-id=$($LaneSpec.lane_id)",
			"--baseline-source=$($LaneSpec.baseline_source)",
			"--baseline-version-id=$($LaneSpec.baseline_version_id)",
			"--baseline-display-name=$($LaneSpec.baseline_display_name)",
			"--baseline-agent-config=$($LaneSpec.baseline_agent_config_path)",
			"--baseline-value-net=$($LaneSpec.baseline_value_net_path)"
		)
		& $GodotPath @benchmarkArgs
		$benchmarkExitCode = $LASTEXITCODE
	} finally {
		$env:APPDATA = $previousAppData
	}

	return [pscustomobject]@{
		lane_id = $LaneSpec.lane_id
		run_id = $LaneSpec.run_id
		moved_samples = $movedCount
		moved_action_samples = $movedActionCount
		sample_count = $sampleCount
		action_sample_count = $actionSampleCount
		phase2 = $phase2Status
		action_scorer = $actionScorerStatus
		phase3 = if ($benchmarkExitCode -eq 0) { 'completed' } else { 'failed' }
		benchmark_summary_path = $LaneSpec.benchmark_summary_path
		value_net_path = $LaneSpec.candidate_value_net_path
		action_scorer_path = $benchmarkCandidateActionScorerPath
	}
}

function Resume-ParallelTrainingPhase23 {
	param(
		[Parameter(Mandatory = $true)]
		[string]$WorkspaceRoot,

		[Parameter(Mandatory = $true)]
		[string]$GodotPath,

		[string[]]$LaneIds = @(),

		[int]$MaxParallelValueNets = 2,

		[string]$ValueNetDevice = 'auto',

		[int]$ValueNetNumThreads = 1,

		[int]$ValueNetInteropThreads = 1,

		[int]$ActionScorerEpochs = 20
	)

	$pythonCommand = Resolve-ResumePythonCommand
	$laneSpecs = Get-ResumePhase23LaneSpecs -WorkspaceRoot $WorkspaceRoot
	if ($LaneIds.Count -gt 0) {
		$selected = @{}
		foreach ($laneId in $LaneIds) {
			$selected[$laneId] = $true
		}
		$laneSpecs = @($laneSpecs | Where-Object { $selected.ContainsKey($_.lane_id) })
	}

	$results = @()
	foreach ($laneSpec in $laneSpecs) {
		$results += Invoke-ResumePhase23Lane `
			-LaneSpec $laneSpec `
			-GodotPath $GodotPath `
			-PythonCommand $pythonCommand `
			-MaxParallelValueNets $MaxParallelValueNets `
			-ValueNetDevice $ValueNetDevice `
			-ValueNetNumThreads $ValueNetNumThreads `
			-ValueNetInteropThreads $ValueNetInteropThreads `
			-ActionScorerEpochs $ActionScorerEpochs
	}
	return $results
}

function New-ResumePhase23LaunchSpec {
	param(
		[Parameter(Mandatory = $true)]
		$LaneSpec,

		[Parameter(Mandatory = $true)]
		[string]$GodotPath,

		[int]$MaxParallelValueNets = 2,

		[string]$ValueNetDevice = 'auto',

		[int]$ValueNetNumThreads = 1,

		[int]$ValueNetInteropThreads = 1,

		[int]$ActionScorerEpochs = 20
	)

	$repoRoot = Get-ResumeRepoRoot
	$logRoot = Join-Path $LaneSpec.lane_root 'logs'
	New-Item -ItemType Directory -Force -Path $logRoot | Out-Null

	$launchScriptPath = Join-Path $LaneSpec.lane_root 'resume_phase23_lane.ps1'
	$stdoutLog = Join-Path $logRoot 'resume_phase23.stdout.log'
	$stderrLog = Join-Path $logRoot 'resume_phase23.stderr.log'
	$quotedRepoRoot = ConvertTo-ResumeSingleQuotedLiteral -Value $repoRoot
	$quotedWorkspaceRoot = ConvertTo-ResumeSingleQuotedLiteral -Value ([string]$LaneSpec.workspace_root)
	$quotedGodot = ConvertTo-ResumeSingleQuotedLiteral -Value $GodotPath
	$quotedLaneId = ConvertTo-ResumeSingleQuotedLiteral -Value ([string]$LaneSpec.lane_id)
	$quotedScriptPath = ConvertTo-ResumeSingleQuotedLiteral -Value (Join-Path $repoRoot 'scripts\training\resume_phase23.ps1')

	$launchScript = @(
		'$ErrorActionPreference = ''Stop'''
		('Set-Location -LiteralPath {0}' -f $quotedRepoRoot)
		('& {0} -ExecutionPolicy Bypass -File {1} -ScriptWorkspaceRoot {2} -ScriptGodotPath {3} -ScriptLaneIds {4} -ScriptMaxParallelValueNets {5} -ScriptValueNetDevice {6} -ScriptValueNetNumThreads {7} -ScriptValueNetInteropThreads {8} -ScriptActionScorerEpochs {9}' -f (ConvertTo-ResumeSingleQuotedLiteral -Value (Join-Path $PSHOME 'powershell.exe')), $quotedScriptPath, $quotedWorkspaceRoot, $quotedGodot, $quotedLaneId, $MaxParallelValueNets, (ConvertTo-ResumeSingleQuotedLiteral -Value $ValueNetDevice), $ValueNetNumThreads, $ValueNetInteropThreads, $ActionScorerEpochs)
	) -join [Environment]::NewLine
	Set-Content -Path $launchScriptPath -Value $launchScript -Encoding UTF8

	return [pscustomobject]@{
		lane_id = [string]$LaneSpec.lane_id
		launch_script_path = $launchScriptPath
		command_path = (Join-Path $PSHOME 'powershell.exe')
		argument_list = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $launchScriptPath)
		working_directory = $repoRoot
		stdout_log = $stdoutLog
		stderr_log = $stderrLog
	}
}

function Start-ResumePhase23Workspace {
	param(
		[Parameter(Mandatory = $true)]
		[string]$WorkspaceRoot,

		[Parameter(Mandatory = $true)]
		[string]$GodotPath,

		[string[]]$LaneIds = @(),

		[int]$MaxParallelValueNets = 2,

		[string]$ValueNetDevice = 'auto',

		[int]$ValueNetNumThreads = 1,

		[int]$ValueNetInteropThreads = 1,

		[int]$ActionScorerEpochs = 20,

		[scriptblock]$StartProcessFn
	)

	if ($null -eq $StartProcessFn) {
		$StartProcessFn = {
			param($LaunchSpec)
			Start-Process `
				-FilePath $LaunchSpec.command_path `
				-ArgumentList $LaunchSpec.argument_list `
				-WorkingDirectory $LaunchSpec.working_directory `
				-RedirectStandardOutput $LaunchSpec.stdout_log `
				-RedirectStandardError $LaunchSpec.stderr_log `
				-PassThru `
				-WindowStyle Hidden
		}
	}

	$laneSpecs = @(Get-ResumePhase23LaneSpecs -WorkspaceRoot $WorkspaceRoot)
	if ($LaneIds.Count -gt 0) {
		$selected = @{}
		foreach ($laneId in $LaneIds) {
			$selected[$laneId] = $true
		}
		$laneSpecs = @($laneSpecs | Where-Object { $selected.ContainsKey($_.lane_id) })
	}

	$manifest = [ordered]@{
		generated_at = (Get-Date).ToString('s')
		workspace_root = [System.IO.Path]::GetFullPath($WorkspaceRoot)
		processes = @()
	}

	foreach ($laneSpec in $laneSpecs) {
		$launchSpec = New-ResumePhase23LaunchSpec `
			-LaneSpec $laneSpec `
			-GodotPath $GodotPath `
			-MaxParallelValueNets $MaxParallelValueNets `
			-ValueNetDevice $ValueNetDevice `
			-ValueNetNumThreads $ValueNetNumThreads `
			-ValueNetInteropThreads $ValueNetInteropThreads `
			-ActionScorerEpochs $ActionScorerEpochs
		$process = & $StartProcessFn $launchSpec
		$manifest.processes += [ordered]@{
			pid = [int]$process.Id
			lane_id = [string]$launchSpec.lane_id
			launch_script_path = [string]$launchSpec.launch_script_path
			stdout_log = [string]$launchSpec.stdout_log
			stderr_log = [string]$launchSpec.stderr_log
		}
	}

	$manifestPath = Join-Path ([System.IO.Path]::GetFullPath($WorkspaceRoot)) 'resume_phase23_launch_manifest.json'
	$manifest | ConvertTo-Json -Depth 6 | Set-Content -Path $manifestPath -Encoding UTF8
	return $manifestPath
}

if ($MyInvocation.InvocationName -ne '.' -and -not [string]::IsNullOrWhiteSpace($ScriptWorkspaceRoot) -and -not [string]::IsNullOrWhiteSpace($ScriptGodotPath)) {
	if ($LaunchParallel) {
		$manifestPath = Start-ResumePhase23Workspace `
			-WorkspaceRoot $ScriptWorkspaceRoot `
			-GodotPath $ScriptGodotPath `
			-LaneIds $ScriptLaneIds `
			-MaxParallelValueNets $ScriptMaxParallelValueNets `
			-ValueNetDevice $ScriptValueNetDevice `
			-ValueNetNumThreads $ScriptValueNetNumThreads `
			-ValueNetInteropThreads $ScriptValueNetInteropThreads `
			-ActionScorerEpochs $ScriptActionScorerEpochs
		Write-Output $manifestPath
	} else {
		Resume-ParallelTrainingPhase23 `
			-WorkspaceRoot $ScriptWorkspaceRoot `
			-GodotPath $ScriptGodotPath `
			-LaneIds $ScriptLaneIds `
			-MaxParallelValueNets $ScriptMaxParallelValueNets `
			-ValueNetDevice $ScriptValueNetDevice `
			-ValueNetNumThreads $ScriptValueNetNumThreads `
			-ValueNetInteropThreads $ScriptValueNetInteropThreads `
			-ActionScorerEpochs $ScriptActionScorerEpochs | Format-Table -AutoSize
	}
}
