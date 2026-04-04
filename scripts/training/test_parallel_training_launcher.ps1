$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'parallel_training_launcher.ps1'
. $scriptPath

function Assert-Equal {
	param(
		$Actual,
		$Expected,
		[string]$Message
	)
	if ($Actual -ne $Expected) {
		throw "Assert-Equal failed: $Message. Expected=[$Expected] Actual=[$Actual]"
	}
}

function Assert-True {
	param(
		[bool]$Condition,
		[string]$Message
	)
	if (-not $Condition) {
		throw "Assert-True failed: $Message"
	}
}

$workspaceRoot = Join-Path $env:TEMP 'ptcg_parallel_launcher_test'
if (Test-Path $workspaceRoot) {
	Remove-Item -LiteralPath $workspaceRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $workspaceRoot | Out-Null

$approvedBaseline = @{
	version_id = 'AI-20260329-01'
	display_name = 'approved best'
	agent_config_path = 'user://ai_agents/approved.json'
	value_net_path = 'user://ai_models/approved.json'
	action_scorer_path = 'user://ai_models/action_scorer.json'
}

$plan = New-ParallelTrainingPlan -WorkspaceRoot $workspaceRoot -ApprovedBaseline $approvedBaseline -PipelineName 'miraidon_focus_training'

Assert-Equal $plan.lanes.Count 20 'launcher should build 20 lane configs'
Assert-Equal $plan.pipeline_name 'miraidon_focus_training' 'launcher should record the requested pipeline name'

$groupCounts = @{}
$laneRoots = @{}
$dataRoots = @{}
$modelRoots = @{}
foreach ($lane in $plan.lanes) {
	if ($groupCounts.ContainsKey($lane.group)) {
		$groupCounts[$lane.group] = 1 + $groupCounts[$lane.group]
	} else {
		$groupCounts[$lane.group] = 1
	}
	$laneRoots[$lane.lane_root] = $true
	$dataRoots[$lane.data_root] = $true
	$modelRoots[$lane.model_root] = $true

	Assert-Equal $lane.baseline.version_id 'AI-20260329-01' 'every lane should reference the shared approved baseline snapshot'
	Assert-True ($lane.train_loop_args -contains '--pipeline-name') 'each lane should pass pipeline-name through to train_loop.sh'
	Assert-True ($lane.train_loop_args -contains 'miraidon_focus_training') 'each lane should use the requested training pipeline'
	Assert-True (Test-Path $lane.lane_root) 'each lane root should be materialized'
	Assert-True (Test-Path $lane.data_root) 'each lane data root should be materialized'
	Assert-True (Test-Path $lane.model_root) 'each lane model root should be materialized'
}

Assert-Equal $groupCounts['conservative'] 5 'conservative group should get 5 lanes'
Assert-Equal $groupCounts['standard'] 5 'standard group should get 5 lanes'
Assert-Equal $groupCounts['aggressive'] 5 'aggressive group should get 5 lanes'
Assert-Equal $groupCounts['deep'] 5 'deep group should get 5 lanes'
Assert-Equal $laneRoots.Count 20 'lane roots should be unique per lane'
Assert-Equal $dataRoots.Count 20 'data roots should be unique per lane'
Assert-Equal $modelRoots.Count 20 'model roots should be unique per lane'

$recipeIds = @($plan.lanes | ForEach-Object { $_.recipe_id } | Sort-Object -Unique)
Assert-True ($recipeIds.Count -ge 4) 'launcher should assign heterogeneous recipes across the lane groups'

$planFile = Join-Path $workspaceRoot 'parallel_training_plan.json'
Export-ParallelTrainingPlan -Plan $plan -OutputPath $planFile
Assert-True (Test-Path $planFile) 'launcher should export a machine-readable plan file'

$planJson = Get-Content -Path $planFile -Raw | ConvertFrom-Json
Assert-Equal $planJson.lanes.Count 20 'exported JSON plan should contain every lane'
Assert-Equal $planJson.approved_baseline.version_id 'AI-20260329-01' 'exported JSON should preserve the approved baseline snapshot'
Assert-Equal $planJson.approved_baseline.action_scorer_path 'user://ai_models/action_scorer.json' 'exported JSON should preserve the approved baseline action scorer'
Assert-Equal $planJson.pipeline_name 'miraidon_focus_training' 'exported JSON should preserve the requested pipeline name'

$resolvedGitBash = Resolve-GitBashPath
Assert-Equal $resolvedGitBash 'D:\Program Files\Git\bin\bash.exe' 'launcher should prefer the installed Git Bash over system bash.exe'

$godotPath = 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe'
$gitBashPath = 'D:/Program Files/Git/bin/bash.exe'
$firstLane = $plan.lanes[0]
$launchSpec = New-ParallelLaneLaunchSpec -Lane $firstLane -GodotPath $godotPath -GitBashPath $gitBashPath

Assert-Equal $launchSpec.lane_id $firstLane.lane_id 'launch spec should preserve lane id'
Assert-Equal $launchSpec.appdata_root $firstLane.appdata_root 'launch spec should preserve lane-local APPDATA root'
Assert-True (Test-Path $launchSpec.launch_script_path) 'launch spec should materialize a lane launch script'
Assert-True (Test-Path $launchSpec.train_loop_snapshot_path) 'launch spec should snapshot train_loop.sh into the lane workspace'
Assert-True ($launchSpec.stdout_log -like '*.stdout.log') 'launch spec should define a stdout log'
Assert-True ($launchSpec.stderr_log -like '*.stderr.log') 'launch spec should define a stderr log'

$launchScriptText = Get-Content -Path $launchSpec.launch_script_path -Raw
Assert-True ($launchScriptText.Contains($firstLane.appdata_root)) 'lane launch script should pin APPDATA to the lane-local root'
Assert-True ($launchScriptText.Contains($godotPath)) 'lane launch script should embed the Godot executable path'
Assert-True ($launchScriptText.Contains($gitBashPath)) 'lane launch script should embed the Git Bash path'
Assert-True ($launchScriptText.Contains($firstLane.recipe_id)) 'lane launch script should pass the lane recipe id through to train_loop.sh'
Assert-True ($launchScriptText.Contains($launchSpec.train_loop_snapshot_path)) 'lane launch script should execute the lane-local train_loop snapshot'
Assert-True ($launchScriptText.Contains('--sigma-weights')) 'lane launch script should pass sigma-weights through to train_loop.sh'
Assert-True ($launchScriptText.Contains([string]$firstLane.sigma_weights)) 'lane launch script should embed the lane sigma_weights value'
Assert-True ($launchScriptText.Contains('--sigma-mcts')) 'lane launch script should pass sigma-mcts through to train_loop.sh'
Assert-True ($launchScriptText.Contains([string]$firstLane.sigma_mcts)) 'lane launch script should embed the lane sigma_mcts value'
Assert-True ($launchScriptText.Contains('--project-dir')) 'lane launch script should pass the repo root through to train_loop.sh'
Assert-True ($launchScriptText.Contains('D:\ai\code\ptcgtrain')) 'lane launch script should embed the repo root'
Assert-True ($launchScriptText.Contains('--baseline-agent-config')) 'lane launch script should pass the baseline agent config through to train_loop.sh'
Assert-True ($launchScriptText.Contains($approvedBaseline.agent_config_path)) 'lane launch script should embed the baseline agent config path'
Assert-True ($launchScriptText.Contains('--baseline-action-scorer')) 'lane launch script should pass the baseline action scorer through to train_loop.sh'
Assert-True ($launchScriptText.Contains($approvedBaseline.action_scorer_path)) 'lane launch script should embed the baseline action scorer path'
Assert-True ($launchScriptText.Contains('--pipeline-name')) 'lane launch script should pass pipeline-name through to train_loop.sh'
Assert-True ($launchScriptText.Contains('miraidon_focus_training')) 'lane launch script should embed the requested pipeline name'

$started = @()
$starter = {
	param($LaunchSpec)
	$script:started += $LaunchSpec
	return [pscustomobject]@{
		Id = 5000 + $script:started.Count
	}
}

$manifestPath = Start-ParallelTrainingPlan -Plan $plan -GodotPath $godotPath -GitBashPath $gitBashPath -StartProcessFn $starter
Assert-True (Test-Path $manifestPath) 'starting the plan should export a launch manifest'
Assert-Equal $started.Count 20 'starting the plan should attempt to launch every lane'

$manifestJson = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
Assert-Equal $manifestJson.processes.Count 20 'launch manifest should record every lane process'
Assert-Equal $manifestJson.processes[0].pid 5001 'launch manifest should record returned process ids'
Assert-Equal $manifestJson.processes[0].lane_id 'lane_01' 'launch manifest should record lane ids'
Assert-Equal $manifestJson.processes[0].appdata_root $plan.lanes[0].appdata_root 'launch manifest should record lane-local APPDATA roots'

Write-Output 'parallel_training_launcher tests passed'
