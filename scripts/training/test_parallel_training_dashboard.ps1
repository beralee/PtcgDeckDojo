$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'parallel_training_dashboard.ps1'
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

$workspaceRoot = Join-Path $env:TEMP 'ptcg_parallel_dashboard_test'
if (Test-Path $workspaceRoot) {
	Remove-Item -LiteralPath $workspaceRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $workspaceRoot | Out-Null

$manifest = [ordered]@{
	generated_at = '2026-03-29T14:00:00'
	workspace_root = $workspaceRoot
	approved_baseline = @{
		version_id = 'bootstrap-latest-agent'
		display_name = 'bootstrap latest agent'
		agent_config_path = 'C:\fake\agent.json'
		value_net_path = ''
	}
	processes = @(
		[ordered]@{
			pid = 1111
			lane_id = 'lane_01'
			recipe_id = 'conservative-01'
			group = 'conservative'
			appdata_root = (Join-Path $workspaceRoot 'lane_01\appdata')
			launch_script_path = (Join-Path $workspaceRoot 'lane_01\launch_lane.ps1')
			stdout_log = (Join-Path $workspaceRoot 'lane_01\logs\train.stdout.log')
			stderr_log = (Join-Path $workspaceRoot 'lane_01\logs\train.stderr.log')
		},
		[ordered]@{
			pid = 2222
			lane_id = 'lane_02'
			recipe_id = 'deep-01'
			group = 'deep'
			appdata_root = (Join-Path $workspaceRoot 'lane_02\appdata')
			launch_script_path = (Join-Path $workspaceRoot 'lane_02\launch_lane.ps1')
			stdout_log = (Join-Path $workspaceRoot 'lane_02\logs\train.stdout.log')
			stderr_log = (Join-Path $workspaceRoot 'lane_02\logs\train.stderr.log')
		}
	)
}

$manifestPath = Join-Path $workspaceRoot 'parallel_training_launch_manifest.json'
$manifest | ConvertTo-Json -Depth 8 | Set-Content -Path $manifestPath -Encoding UTF8

foreach ($lane in $manifest.processes) {
	$stdoutDir = Split-Path -Parent $lane.stdout_log
	$stderrDir = Split-Path -Parent $lane.stderr_log
	New-Item -ItemType Directory -Force -Path $stdoutDir | Out-Null
	New-Item -ItemType Directory -Force -Path $stderrDir | Out-Null
	New-Item -ItemType Directory -Force -Path (Join-Path $workspaceRoot $lane.lane_id) | Out-Null
}

$lane01RunDir = Join-Path $workspaceRoot 'lane_01\training_data\runs\run_20260329_140001_01'
$lane02RunDir = Join-Path $workspaceRoot 'lane_02\training_data\runs\run_20260329_140002_01'
New-Item -ItemType Directory -Force -Path (Join-Path $lane01RunDir 'self_play') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $lane01RunDir 'models') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $lane02RunDir 'self_play') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $lane02RunDir 'benchmark') | Out-Null

$secretBox = ([string][char]0x79D8) + ([string][char]0x5BC6) + ([string][char]0x7BB1)

1..3 | ForEach-Object {
	Set-Content -Path (Join-Path $lane01RunDir "self_play\game_$_.json") -Value '{}' -Encoding UTF8
}
Set-Content -Path (Join-Path $lane01RunDir 'models\value_net_v1.json') -Value '{}' -Encoding UTF8
@'
{
  "phase": "phase1",
  "generation_current": 3,
  "generation_total": 11,
  "total_matches_completed": 72,
  "cumulative_agent_a_wins": 41,
  "cumulative_agent_b_wins": 31,
  "cumulative_agent_a_win_rate": 0.5694,
  "last_generation_matches": 24,
  "last_generation_agent_a_wins": 15,
  "last_generation_agent_b_wins": 9,
  "last_generation_win_rate": 0.625,
  "accepted_generations": 2
}
'@ | Set-Content -Path (Join-Path $lane01RunDir 'status.json') -Encoding UTF8
$lane02Summary = @'
{
  "gate_passed": false,
  "total_matches": 24,
  "version_a_wins": 9,
  "version_b_wins": 15,
  "version_a_win_rate": 0.375,
  "timeouts": 2,
  "failures": 1,
  "pairing_results": [
    {
      "pairing_name": "miraidon_vs_gardevoir",
      "gate_passed": true,
      "summary": {
        "version_a_wins": 3,
        "version_b_wins": 5,
        "version_a_win_rate": 0.375
      }
    }
  ],
  "anomaly_summary": {
    "schema_version": 3,
    "total_anomalies": 1,
    "failure_reason_counts": {
      "stalled_no_progress": 1
    },
    "mcts_failure_category_counts": {
      "headless_interaction_required": 1
    },
    "mcts_failure_kind_counts": {
      "play_trainer": 1
    },
    "pairing_counts": {
      "miraidon_vs_gardevoir": {
        "total": 1,
        "failure_reason_counts": {
          "stalled_no_progress": 1
        }
      }
    },
    "samples": {
      "stalled_no_progress": {
        "miraidon_vs_gardevoir": [
          {
            "card_name": "__SECRET_BOX__"
          }
        ]
      }
    }
  }
}
'@
$lane02Summary = $lane02Summary.Replace('__SECRET_BOX__', $secretBox)
$lane02Summary | Set-Content -Path (Join-Path $lane02RunDir 'benchmark\summary.json') -Encoding UTF8

@'
===== PTCG Train Iterative Training =====
[phase 1] self-play evolution (11 generations)
  run training samples: 3
[phase 2] train value net (80 epochs)
'@ | Set-Content -Path $manifest.processes[0].stdout_log -Encoding UTF8
Set-Content -Path $manifest.processes[0].stderr_log -Value '' -Encoding UTF8

@'
===== PTCG Train Iterative Training =====
[phase 3] fixed benchmark gate
  benchmark decision: benchmark_failed
===== Training Complete =====
Promoted agent config: foo
Promoted value net:    bar
Last published run:    <none>
'@ | Set-Content -Path $manifest.processes[1].stdout_log -Encoding UTF8
Set-Content -Path $manifest.processes[1].stderr_log -Value 'warning' -Encoding UTF8

Assert-Equal (Get-LanePhaseFromLog -LogPath $manifest.processes[0].stdout_log) 'phase2' 'phase parser should identify training stage'
Assert-Equal (Get-LanePhaseFromLog -LogPath $manifest.processes[1].stdout_log) 'complete' 'phase parser should identify completed stage'

$lane01Status = Get-ParallelTrainingLaneStatus -LaneProcess $manifest.processes[0]
Assert-Equal $lane01Status.sample_count 3 'lane status should count self-play samples'
Assert-Equal $lane01Status.has_value_net $true 'lane status should detect value net output'
Assert-Equal $lane01Status.has_benchmark $false 'lane status should not report missing benchmark output'
Assert-Equal $lane01Status.phase 'phase2' 'lane status should preserve parsed phase'
Assert-Equal $lane01Status.status 'running' 'lane without stderr should be running'
Assert-Equal $lane01Status.progress_generation '3/11' 'lane status should expose current generation progress'
Assert-Equal $lane01Status.progress_wins '41-31' 'lane status should expose cumulative phase1 wins'
Assert-Equal $lane01Status.progress_win_rate '56.9%' 'lane status should expose cumulative phase1 win rate'
Assert-Equal $lane01Status.progress_last_gen '15-9 (62.5%)' 'lane status should expose last generation result'
Assert-Equal $lane01Status.accepted_generations 2 'lane status should expose accepted generation count'

$lane02Status = Get-ParallelTrainingLaneStatus -LaneProcess $manifest.processes[1]
Assert-Equal $lane02Status.has_benchmark $true 'lane status should detect benchmark summary'
Assert-Equal $lane02Status.phase 'complete' 'completed lane should report complete phase'
Assert-Equal $lane02Status.status 'warning' 'lane with stderr content should be flagged as warning'
Assert-Equal $lane02Status.benchmark_wins '9-15' 'lane status should expose benchmark wins and losses'
Assert-Equal $lane02Status.benchmark_win_rate '37.5%' 'lane status should expose benchmark win rate'
Assert-Equal $lane02Status.benchmark_gate 'fail' 'lane status should expose benchmark gate result'
Assert-Equal $lane02Status.benchmark_pairings 1 'lane status should count benchmark pairings'
Assert-Equal $lane02Status.benchmark_failures 1 'lane status should preserve benchmark failure counts'

$dashboard = Get-ParallelTrainingDashboardData -WorkspaceRoot $workspaceRoot
Assert-Equal $dashboard.summary.total_lanes 2 'dashboard should summarize all lanes'
Assert-Equal $dashboard.summary.completed_lanes 1 'dashboard should count completed lanes'
Assert-Equal $dashboard.summary.warning_lanes 1 'dashboard should count warning lanes'
Assert-Equal $dashboard.summary.running_lanes 1 'dashboard should count running lanes'
Assert-Equal $dashboard.summary.benchmark_lanes 1 'dashboard should count lanes with benchmark outputs'
Assert-Equal $dashboard.summary.benchmark_passed_lanes 0 'dashboard should count passed benchmark lanes'
Assert-Equal $dashboard.summary.best_benchmark_win_rate '37.5%' 'dashboard should summarize best visible benchmark win rate'
Assert-Equal $dashboard.summary.progress_lanes 1 'dashboard should count lanes with phase1 progress snapshots'
Assert-Equal $dashboard.lanes.Count 2 'dashboard should return lane details'

Write-Output 'parallel_training_dashboard tests passed'
