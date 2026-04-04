$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'resume_phase23.ps1'
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

$workspaceRoot = Join-Path $env:TEMP 'ptcg_resume_phase23_test'
if (Test-Path $workspaceRoot) {
	Remove-Item -LiteralPath $workspaceRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $workspaceRoot | Out-Null

$plan = @{
	pipeline_name = 'miraidon_focus_training'
	approved_baseline = @{
		version_id = 'bootstrap-latest-agent'
		display_name = 'bootstrap latest agent'
		agent_config_path = 'C:\baseline\agent.json'
		value_net_path = 'C:\baseline\value.json'
		action_scorer_path = 'C:\baseline\action.json'
		source = 'bootstrap-latest-agent'
	}
	lanes = @(
		@{
			lane_id = 'lane_01'
			lane_root = (Join-Path $workspaceRoot 'lane_01')
			appdata_root = (Join-Path $workspaceRoot 'lane_01\appdata')
			model_root = (Join-Path $workspaceRoot 'lane_01\models')
			group = 'conservative'
			recipe_id = 'conservative-01'
			epochs = 65
			baseline = @{
				version_id = 'bootstrap-latest-agent'
				display_name = 'bootstrap latest agent'
				agent_config_path = 'C:\baseline\agent.json'
				value_net_path = 'C:\baseline\value.json'
				action_scorer_path = 'C:\baseline\action.json'
				source = 'bootstrap-latest-agent'
			}
		}
	)
}
$planPath = Join-Path $workspaceRoot 'parallel_training_plan.json'
$plan | ConvertTo-Json -Depth 8 | Set-Content -Path $planPath -Encoding UTF8

$laneRoot = Join-Path $workspaceRoot 'lane_01'
$runDir = Join-Path $laneRoot 'training_data\runs\run_20260330_003826_01'
$runDataDir = Join-Path $runDir 'self_play'
$runActionDataDir = Join-Path $runDir 'action_decisions'
$appDataTrainingRoot = Join-Path $laneRoot 'appdata\Godot\app_userdata\PTCG Train\training_data'
$appDataActionRoot = Join-Path $appDataTrainingRoot 'action_decisions'
$agentDir = Join-Path $laneRoot 'appdata\Godot\app_userdata\PTCG Train\ai_agents'

foreach ($path in @($runDataDir, $runActionDataDir, $appDataTrainingRoot, $appDataActionRoot, $agentDir)) {
	New-Item -ItemType Directory -Force -Path $path | Out-Null
}

Set-Content -Path (Join-Path $appDataTrainingRoot 'game_001.json') -Value '{}' -Encoding UTF8
Set-Content -Path (Join-Path $appDataTrainingRoot 'game_002.json') -Value '{}' -Encoding UTF8
Set-Content -Path (Join-Path $appDataActionRoot 'decision_001.json') -Value '{}' -Encoding UTF8
Set-Content -Path (Join-Path $agentDir 'agent_v001.json') -Value '{}' -Encoding UTF8

$laneSpecs = @(Get-ResumePhase23LaneSpecs -WorkspaceRoot $workspaceRoot)
Assert-Equal $laneSpecs.Count 1 'resume script should discover one resumable lane'

$laneSpec = $laneSpecs[0]
Assert-Equal $laneSpec.lane_id 'lane_01' 'resume spec should preserve lane id'
Assert-Equal $laneSpec.pipeline_name 'miraidon_focus_training' 'resume spec should preserve pipeline name'
Assert-Equal $laneSpec.candidate_agent_config_path (Join-Path $agentDir 'agent_v001.json') 'resume spec should resolve candidate agent config from lane-local APPDATA'
Assert-Equal $laneSpec.baseline_agent_config_path 'C:\baseline\agent.json' 'resume spec should preserve baseline agent config'
Assert-Equal $laneSpec.baseline_action_scorer_path 'C:\baseline\action.json' 'resume spec should preserve baseline action scorer path'
Assert-Equal $laneSpec.sample_source_dir $appDataTrainingRoot 'resume spec should point to the lane-local training_data root'
Assert-Equal $laneSpec.run_data_dir $runDataDir 'resume spec should point to the run self_play directory'
Assert-Equal $laneSpec.sample_source_count 2 'resume spec should count lane-local exported games'
Assert-Equal $laneSpec.action_sample_source_dir $appDataActionRoot 'resume spec should point to the lane-local action decision source directory'
Assert-Equal $laneSpec.run_action_data_dir $runActionDataDir 'resume spec should point to the run action decision directory'
Assert-Equal $laneSpec.action_sample_source_count 1 'resume spec should count lane-local action decision samples'

$movedCount = Move-ResumeLaneSamples -LaneSpec $laneSpec
Assert-Equal $movedCount 2 'resume helper should move lane-local games into the run self_play directory'
Assert-Equal ((Get-ChildItem $runDataDir -File -Filter 'game_*.json' | Measure-Object).Count) 2 'run self_play should receive the moved samples'
Assert-Equal ((Get-ChildItem $appDataTrainingRoot -File -Filter 'game_*.json' | Measure-Object).Count) 0 'sample source should be drained after recovery'

$movedActionCount = Move-ResumeLaneActionSamples -LaneSpec $laneSpec
Assert-Equal $movedActionCount 1 'resume helper should move lane-local action samples into the run action decision directory'
Assert-Equal ((Get-ChildItem $runActionDataDir -File -Filter '*.json' | Measure-Object).Count) 1 'run action decision directory should receive the moved samples'
Assert-Equal ((Get-ChildItem $appDataActionRoot -File -Filter '*.json' | Measure-Object).Count) 0 'action sample source should be drained after recovery'

$godotPath = 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe'
$launchSpec = New-ResumePhase23LaunchSpec `
	-LaneSpec $laneSpec `
	-GodotPath $godotPath `
	-MaxParallelValueNets 3 `
	-ValueNetDevice 'cuda' `
	-ValueNetNumThreads 1 `
	-ValueNetInteropThreads 1 `
	-ActionScorerEpochs 25
Assert-Equal $launchSpec.lane_id 'lane_01' 'resume launch spec should preserve lane id'
Assert-True (Test-Path $launchSpec.launch_script_path) 'resume launch spec should materialize a lane launch script'
Assert-True ($launchSpec.stdout_log -like '*.stdout.log') 'resume launch spec should define a stdout log'
Assert-True ($launchSpec.stderr_log -like '*.stderr.log') 'resume launch spec should define a stderr log'

$launchScriptText = Get-Content -Path $launchSpec.launch_script_path -Raw
Assert-True ($launchScriptText.Contains($workspaceRoot)) 'resume launch script should embed the workspace root'
Assert-True ($launchScriptText.Contains($godotPath)) 'resume launch script should embed the Godot path'
Assert-True ($launchScriptText.Contains('lane_01')) 'resume launch script should target the selected lane'
Assert-True ($launchScriptText.Contains('-ScriptMaxParallelValueNets 3')) 'resume launch script should forward the phase2 concurrency limit'
Assert-True ($launchScriptText.Contains("-ScriptValueNetDevice 'cuda'")) 'resume launch script should forward the requested value net device'
Assert-True ($launchScriptText.Contains('-ScriptValueNetNumThreads 1')) 'resume launch script should forward the value net CPU thread cap'
Assert-True ($launchScriptText.Contains('-ScriptValueNetInteropThreads 1')) 'resume launch script should forward the value net interop thread cap'
Assert-True ($launchScriptText.Contains('-ScriptActionScorerEpochs 25')) 'resume launch script should forward the action scorer epoch count'

$started = @()
$starter = {
	param($LaunchSpec)
	$script:started += $LaunchSpec
	return [pscustomobject]@{
		Id = 6000 + $script:started.Count
	}
}

$manifestPath = Start-ResumePhase23Workspace `
	-WorkspaceRoot $workspaceRoot `
	-GodotPath $godotPath `
	-MaxParallelValueNets 3 `
	-ValueNetDevice 'cuda' `
	-ValueNetNumThreads 1 `
	-ValueNetInteropThreads 1 `
	-ActionScorerEpochs 25 `
	-StartProcessFn $starter
Assert-True (Test-Path $manifestPath) 'resume launcher should write a launch manifest'
Assert-Equal $started.Count 1 'resume launcher should start one process per eligible lane'

$manifestJson = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
Assert-Equal $manifestJson.processes.Count 1 'resume launch manifest should record every launched process'
Assert-Equal $manifestJson.processes[0].pid 6001 'resume launch manifest should record returned process ids'
Assert-Equal $manifestJson.processes[0].lane_id 'lane_01' 'resume launch manifest should preserve lane ids'

Write-Output 'resume_phase23 tests passed'
