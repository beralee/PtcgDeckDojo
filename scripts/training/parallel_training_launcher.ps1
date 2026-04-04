$ErrorActionPreference = 'Stop'

function ConvertTo-PsSingleQuotedLiteral {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Value
	)
	return "'" + ($Value -replace "'", "''") + "'"
}

function Get-RepoRoot {
	return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
}

function ConvertTo-InvariantString {
	param(
		[Parameter(Mandatory = $true)]
		[double]$Value
	)
	return [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.###}', $Value)
}

function Get-ParallelLaneRecipes {
	$recipes = @()
	for ($i = 1; $i -le 5; $i++) {
		$recipes += [ordered]@{
			group = 'conservative'
			recipe_id = ('conservative-{0:D2}' -f $i)
			generations = 10 + $i
			epochs = 60 + ($i * 5)
			sigma_weights = [math]::Round(0.08 + ($i * 0.005), 3)
			sigma_mcts = [math]::Round(0.05 + ($i * 0.005), 3)
		}
	}
	for ($i = 1; $i -le 5; $i++) {
		$recipes += [ordered]@{
			group = 'standard'
			recipe_id = ('standard-{0:D2}' -f $i)
			generations = 12 + $i
			epochs = 80 + ($i * 5)
			sigma_weights = [math]::Round(0.12 + ($i * 0.005), 3)
			sigma_mcts = [math]::Round(0.08 + ($i * 0.005), 3)
		}
	}
	for ($i = 1; $i -le 5; $i++) {
		$recipes += [ordered]@{
			group = 'aggressive'
			recipe_id = ('aggressive-{0:D2}' -f $i)
			generations = 10 + ($i * 2)
			epochs = 70 + ($i * 5)
			sigma_weights = [math]::Round(0.18 + ($i * 0.01), 3)
			sigma_mcts = [math]::Round(0.12 + ($i * 0.01), 3)
		}
	}
	for ($i = 1; $i -le 5; $i++) {
		$recipes += [ordered]@{
			group = 'deep'
			recipe_id = ('deep-{0:D2}' -f $i)
			generations = 18 + ($i * 2)
			epochs = 120 + ($i * 10)
			sigma_weights = [math]::Round(0.10 + ($i * 0.004), 3)
			sigma_mcts = [math]::Round(0.07 + ($i * 0.004), 3)
		}
	}
	return $recipes
}

function New-ParallelTrainingPlan {
	param(
		[Parameter(Mandatory = $true)]
		[string]$WorkspaceRoot,

		[Parameter(Mandatory = $true)]
		[hashtable]$ApprovedBaseline,

		[string]$PipelineName = 'fixed_three_deck_training'
	)

	$workspaceRootAbsolute = [System.IO.Path]::GetFullPath($WorkspaceRoot)
	New-Item -ItemType Directory -Force -Path $workspaceRootAbsolute | Out-Null

	$plan = [ordered]@{
		generated_at = (Get-Date).ToString('s')
		workspace_root = $workspaceRootAbsolute
		pipeline_name = [string]$PipelineName
		approved_baseline = [ordered]@{
			version_id = [string]$ApprovedBaseline.version_id
			display_name = [string]$ApprovedBaseline.display_name
			agent_config_path = [string]$ApprovedBaseline.agent_config_path
			value_net_path = [string]$ApprovedBaseline.value_net_path
			action_scorer_path = [string]$ApprovedBaseline.action_scorer_path
			source = [string]$ApprovedBaseline.source
		}
		lanes = @()
	}

	$recipes = Get-ParallelLaneRecipes
	for ($index = 0; $index -lt $recipes.Count; $index++) {
		$recipe = $recipes[$index]
		$laneId = 'lane_{0:D2}' -f ($index + 1)
		$laneRoot = Join-Path $workspaceRootAbsolute $laneId
		$dataRoot = Join-Path $laneRoot 'training_data'
		$modelRoot = Join-Path $laneRoot 'models'
		$appDataRoot = Join-Path $laneRoot 'appdata'
		$logRoot = Join-Path $laneRoot 'logs'

		foreach ($path in @($laneRoot, $dataRoot, $modelRoot, $appDataRoot, $logRoot)) {
			New-Item -ItemType Directory -Force -Path $path | Out-Null
		}

		$lane = [ordered]@{
			lane_id = $laneId
			group = [string]$recipe.group
			recipe_id = [string]$recipe.recipe_id
			lane_root = $laneRoot
			data_root = $dataRoot
			model_root = $modelRoot
			appdata_root = $appDataRoot
			log_root = $logRoot
			generations = [int]$recipe.generations
			epochs = [int]$recipe.epochs
			sigma_weights = [double]$recipe.sigma_weights
			sigma_mcts = [double]$recipe.sigma_mcts
			baseline = [ordered]@{
				version_id = [string]$plan.approved_baseline.version_id
				display_name = [string]$plan.approved_baseline.display_name
				agent_config_path = [string]$plan.approved_baseline.agent_config_path
				value_net_path = [string]$plan.approved_baseline.value_net_path
				action_scorer_path = [string]$plan.approved_baseline.action_scorer_path
				source = [string]$plan.approved_baseline.source
			}
			train_loop_args = @(
				'--iterations', '1',
				'--pipeline-name', [string]$PipelineName,
				'--generations', [string]$recipe.generations,
				'--epochs', [string]$recipe.epochs,
				'--sigma-weights', (ConvertTo-InvariantString -Value ([double]$recipe.sigma_weights)),
				'--sigma-mcts', (ConvertTo-InvariantString -Value ([double]$recipe.sigma_mcts)),
				'--data-dir', $dataRoot,
				'--model-dir', $modelRoot,
				'--lane-recipe-id', [string]$recipe.recipe_id,
				'--lane-id', $laneId
			)
		}

		$plan.lanes += $lane
	}

	return $plan
}

function Export-ParallelTrainingPlan {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$Plan,

		[Parameter(Mandatory = $true)]
		[string]$OutputPath
	)

	$outputAbsolute = [System.IO.Path]::GetFullPath($OutputPath)
	$outputDir = Split-Path -Parent $outputAbsolute
	New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
	$Plan | ConvertTo-Json -Depth 8 | Set-Content -Path $outputAbsolute -Encoding UTF8
	return $outputAbsolute
}

function Resolve-GitBashPath {
	$candidates = @(
		'D:\Program Files\Git\bin\bash.exe',
		'C:\Program Files\Git\bin\bash.exe'
	)
	foreach ($candidate in $candidates) {
		if (Test-Path $candidate) {
			return $candidate
		}
	}

	$command = Get-Command bash.exe -ErrorAction SilentlyContinue
	if ($null -ne $command -and -not [string]::IsNullOrWhiteSpace($command.Source)) {
		return $command.Source
	}

	throw 'Unable to resolve Git Bash executable path.'
}

function Get-TrainingBaselineSnapshot {
	param(
		[string]$AppDataRoot = $env:APPDATA,
		[switch]$AllowBootstrap
	)

	$userRoot = Join-Path $AppDataRoot 'Godot/app_userdata/PTCG Train'
	$indexPath = Join-Path $userRoot 'ai_versions/index.json'
	if (Test-Path $indexPath) {
		$data = Get-Content -Path $indexPath -Raw | ConvertFrom-Json -AsHashtable
		$playable = @(
			$data.Values |
				Where-Object { $_ -is [hashtable] -and [string]$_.status -eq 'playable' } |
				Sort-Object @{Expression = { $_.created_at } }, @{Expression = { $_.save_order } }, @{Expression = { $_.version_id } }
		)
		if ($playable.Count -gt 0) {
			$latest = $playable[-1]
			return [ordered]@{
				version_id = [string]$latest.version_id
				display_name = [string]$latest.display_name
				agent_config_path = [string]$latest.agent_config_path
				value_net_path = [string]$latest.value_net_path
				action_scorer_path = [string]$latest.action_scorer_path
				source = 'approved-playable'
			}
		}
	}

	if (-not $AllowBootstrap) {
		throw 'No approved/playable AI version exists yet. Re-run with -AllowBootstrap to fall back to the latest raw agent.'
	}

	$agentDir = Join-Path $userRoot 'ai_agents'
	$latestAgent = Get-ChildItem -Path $agentDir -Filter 'agent_*.json' -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
	if ($null -eq $latestAgent) {
		throw 'No bootstrap agent config found in ai_agents.'
	}

	return [ordered]@{
		version_id = 'bootstrap-latest-agent'
		display_name = 'bootstrap latest agent'
		agent_config_path = $latestAgent.FullName
		value_net_path = ''
		action_scorer_path = ''
		source = 'bootstrap-latest-agent'
	}
}

function New-ParallelLaneLaunchSpec {
	param(
		[Parameter(Mandatory = $true)]
		$Lane,

		[Parameter(Mandatory = $true)]
		[string]$GodotPath,

		[Parameter(Mandatory = $true)]
		[string]$GitBashPath
	)

	$repoRoot = Get-RepoRoot
	$launchScriptPath = Join-Path $Lane.lane_root 'launch_lane.ps1'
	$stdoutLog = Join-Path $Lane.log_root 'train.stdout.log'
	$stderrLog = Join-Path $Lane.log_root 'train.stderr.log'
	$runtimeRoot = Join-Path $Lane.lane_root 'runtime'
	$trainLoopSourcePath = Join-Path $repoRoot 'scripts\training\train_loop.sh'
	$trainLoopSnapshotPath = Join-Path $runtimeRoot 'train_loop.snapshot.sh'
	New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null
	Copy-Item -LiteralPath $trainLoopSourcePath -Destination $trainLoopSnapshotPath -Force
	$quotedRepoRoot = ConvertTo-PsSingleQuotedLiteral -Value $repoRoot
	$quotedAppData = ConvertTo-PsSingleQuotedLiteral -Value $Lane.appdata_root
	$quotedGitBash = ConvertTo-PsSingleQuotedLiteral -Value $GitBashPath
	$quotedGodot = ConvertTo-PsSingleQuotedLiteral -Value $GodotPath

	$bashArgs = @(
		(ConvertTo-PsSingleQuotedLiteral -Value $trainLoopSnapshotPath),
		'--godot', $quotedGodot,
		'--project-dir', $quotedRepoRoot
	)
	if (-not [string]::IsNullOrWhiteSpace([string]$Lane.baseline.agent_config_path)) {
		$bashArgs += @('--baseline-agent-config', (ConvertTo-PsSingleQuotedLiteral -Value ([string]$Lane.baseline.agent_config_path)))
	}
	if (-not [string]::IsNullOrWhiteSpace([string]$Lane.baseline.value_net_path)) {
		$bashArgs += @('--baseline-value-net', (ConvertTo-PsSingleQuotedLiteral -Value ([string]$Lane.baseline.value_net_path)))
	}
	if (-not [string]::IsNullOrWhiteSpace([string]$Lane.baseline.action_scorer_path)) {
		$bashArgs += @('--baseline-action-scorer', (ConvertTo-PsSingleQuotedLiteral -Value ([string]$Lane.baseline.action_scorer_path)))
	}
	if (-not [string]::IsNullOrWhiteSpace([string]$Lane.baseline.source)) {
		$bashArgs += @('--baseline-source', (ConvertTo-PsSingleQuotedLiteral -Value ([string]$Lane.baseline.source)))
	}
	if (-not [string]::IsNullOrWhiteSpace([string]$Lane.baseline.version_id)) {
		$bashArgs += @('--baseline-version-id', (ConvertTo-PsSingleQuotedLiteral -Value ([string]$Lane.baseline.version_id)))
	}
	if (-not [string]::IsNullOrWhiteSpace([string]$Lane.baseline.display_name)) {
		$bashArgs += @('--baseline-display-name', (ConvertTo-PsSingleQuotedLiteral -Value ([string]$Lane.baseline.display_name)))
	}
	foreach ($arg in $Lane.train_loop_args) {
		$bashArgs += (ConvertTo-PsSingleQuotedLiteral -Value ([string]$arg))
	}

	$launchScript = @(
		'$ErrorActionPreference = ''Stop'''
		('$env:APPDATA = {0}' -f $quotedAppData)
		('Set-Location -LiteralPath {0}' -f $quotedRepoRoot)
		('& {0} {1}' -f $quotedGitBash, ($bashArgs -join ' '))
	) -join [Environment]::NewLine
	Set-Content -Path $launchScriptPath -Value $launchScript -Encoding UTF8

	return [ordered]@{
		lane_id = [string]$Lane.lane_id
		recipe_id = [string]$Lane.recipe_id
		group = [string]$Lane.group
		lane_root = [string]$Lane.lane_root
		appdata_root = [string]$Lane.appdata_root
		train_loop_snapshot_path = $trainLoopSnapshotPath
		launch_script_path = $launchScriptPath
		stdout_log = $stdoutLog
		stderr_log = $stderrLog
		command_path = (Join-Path $PSHOME 'powershell.exe')
		argument_list = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $launchScriptPath)
		working_directory = $repoRoot
	}
}

function Start-ParallelTrainingPlan {
	param(
		[Parameter(Mandatory = $true)]
		[hashtable]$Plan,

		[Parameter(Mandatory = $true)]
		[string]$GodotPath,

		[string]$GitBashPath = $(Resolve-GitBashPath),

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

	$manifest = [ordered]@{
		generated_at = (Get-Date).ToString('s')
		workspace_root = [string]$Plan.workspace_root
		approved_baseline = $Plan.approved_baseline
		processes = @()
	}

	foreach ($lane in $Plan.lanes) {
		$launchSpec = New-ParallelLaneLaunchSpec -Lane $lane -GodotPath $GodotPath -GitBashPath $GitBashPath
		$process = & $StartProcessFn $launchSpec
		$manifest.processes += [ordered]@{
			pid = [int]$process.Id
			lane_id = [string]$launchSpec.lane_id
			recipe_id = [string]$launchSpec.recipe_id
			group = [string]$launchSpec.group
			appdata_root = [string]$launchSpec.appdata_root
			launch_script_path = [string]$launchSpec.launch_script_path
			stdout_log = [string]$launchSpec.stdout_log
			stderr_log = [string]$launchSpec.stderr_log
		}
	}

	$manifestPath = Join-Path $Plan.workspace_root 'parallel_training_launch_manifest.json'
	$manifest | ConvertTo-Json -Depth 8 | Set-Content -Path $manifestPath -Encoding UTF8
	return $manifestPath
}

function Invoke-ParallelTrainingLauncher {
	param(
		[Parameter(Mandatory = $true)]
		[string]$WorkspaceRoot,

		[Parameter(Mandatory = $true)]
		[string]$GodotPath,

		[string]$PlanPath = '',
		[string]$GitBashPath = $(Resolve-GitBashPath),
		[string]$PipelineName = 'fixed_three_deck_training',
		[switch]$AllowBootstrap,
		[switch]$Launch
	)

	$baseline = Get-TrainingBaselineSnapshot -AllowBootstrap:$AllowBootstrap
	$plan = New-ParallelTrainingPlan -WorkspaceRoot $WorkspaceRoot -ApprovedBaseline $baseline -PipelineName $PipelineName

	if ([string]::IsNullOrWhiteSpace($PlanPath)) {
		$PlanPath = Join-Path $WorkspaceRoot 'parallel_training_plan.json'
	}

	$exportedPlanPath = Export-ParallelTrainingPlan -Plan $plan -OutputPath $PlanPath
	if (-not $Launch) {
		return [ordered]@{
			plan_path = $exportedPlanPath
			manifest_path = ''
		}
	}

	$manifestPath = Start-ParallelTrainingPlan -Plan $plan -GodotPath $GodotPath -GitBashPath $GitBashPath
	return [ordered]@{
		plan_path = $exportedPlanPath
		manifest_path = $manifestPath
	}
}
