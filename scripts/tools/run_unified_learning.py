from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


DEFAULT_WORK_DIR = "tmp/unified_learning_run"
DEFAULT_MATCH_RECORDS_ROOT = "user://match_records"
DEFAULT_GODOT_CANDIDATES = [
    r"D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe",
    r"D:\ai\godot\Godot_v4.6.1-stable_win64_console.x86_64.exe",
]


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run the full scenario-driven learning pipeline for marked human-vs-human matches.",
    )
    parser.add_argument("--user-root", required=True, help="Godot user:// root, e.g. app_userdata/PTCG Train.")
    parser.add_argument("--match-records-root", default=DEFAULT_MATCH_RECORDS_ROOT)
    parser.add_argument("--work-dir", default=DEFAULT_WORK_DIR)
    parser.add_argument("--godot-bin", help="Path to headless Godot binary.")
    parser.add_argument(
        "--run-llm-judge",
        action="store_true",
        help="Run developer-side llm_judge.py after packet export. This stage reads explicit args, env vars, or a developer config file.",
    )
    parser.add_argument("--llm-output-path", help="Optional explicit judgments JSONL output path.")
    parser.add_argument("--import-judgments", action="store_true", help="Import generated judgments back into pending review.")
    parser.add_argument("--allow-human-resolution", action="store_true")
    return parser.parse_args(argv)


def run_unified_learning(args: argparse.Namespace) -> dict[str, Any]:
    repo_root = Path(__file__).resolve().parents[2]
    python_exe = sys.executable
    work_root = (repo_root / args.work_dir).resolve()
    work_root.mkdir(parents=True, exist_ok=True)
    godot_bin = resolve_godot_bin(args.godot_bin)

    scenarios_dir = work_root / "scenarios"
    review_queue_dir = work_root / "review_queue"
    packets_dir = work_root / "review_packets"
    judgments_path = Path(args.llm_output_path).resolve() if args.llm_output_path else packets_dir / "judgments.jsonl"

    stages: list[dict[str, Any]] = []

    stages.append(
        _run_json_command(
            "extract",
            [
                python_exe,
                str(repo_root / "scripts" / "tools" / "extract_learning_pool_scenarios.py"),
                "--match-records-root",
                args.match_records_root,
                "--user-root",
                args.user_root,
                "--output-dir",
                str(scenarios_dir),
            ],
            repo_root,
        )
    )
    stages.append(
        _run_json_command(
            "populate_expected",
            [
                godot_bin,
                "--headless",
                "--path",
                str(repo_root),
                "-s",
                "res://scripts/tools/populate_scenario_expected_states.gd",
                "--",
                f"--scenarios-dir={_to_res_path(repo_root, scenarios_dir)}",
            ],
            repo_root,
        )
    )
    stages.append(
        _run_json_command(
            "build_review_queue",
            [
                python_exe,
                str(repo_root / "scripts" / "tools" / "build_scenario_review_queue.py"),
                "--scenarios-dir",
                str(scenarios_dir),
                "--output-dir",
                str(review_queue_dir),
            ],
            repo_root,
        )
    )
    stages.append(
        _run_json_command(
            "hydrate_review_queue",
            [
                godot_bin,
                "--headless",
                "--path",
                str(repo_root),
                "-s",
                "res://scripts/tools/hydrate_scenario_review_queue.gd",
                "--",
                f"--review-queue-dir={_to_res_path(repo_root, review_queue_dir)}",
                f"--scenarios-root={_to_res_path(repo_root, scenarios_dir)}",
                "--runtime-mode=rules_only",
            ],
            repo_root,
        )
    )
    stages.append(
        _run_json_command(
            "export_review_packets",
            [
                python_exe,
                str(repo_root / "scripts" / "tools" / "scenario_review" / "export_review_packets.py"),
                "--scenarios-dir",
                str(scenarios_dir),
                "--review-queue-dir",
                str(review_queue_dir),
                "--output-dir",
                str(packets_dir),
            ],
            repo_root,
        )
    )

    if args.run_llm_judge:
        stages.append(
            _run_json_command(
                "llm_judge",
                [
                    python_exe,
                    str(repo_root / "scripts" / "tools" / "scenario_review" / "llm_judge.py"),
                    "--packets-path",
                    str(packets_dir / "packets.jsonl"),
                    "--output-path",
                    str(judgments_path),
                ],
                repo_root,
            )
        )
        if args.import_judgments:
            import_cmd = [
                python_exe,
                str(repo_root / "scripts" / "tools" / "scenario_review" / "import_review_judgments.py"),
                "--scenarios-dir",
                str(scenarios_dir),
                "--review-queue-dir",
                str(review_queue_dir),
                "--judgments-path",
                str(judgments_path),
            ]
            if args.allow_human_resolution:
                import_cmd.append("--allow-human-resolution")
            stages.append(_run_json_command("import_judgments", import_cmd, repo_root))

    summary = {
        "work_root": str(work_root),
        "scenarios_dir": str(scenarios_dir),
        "review_queue_dir": str(review_queue_dir),
        "packets_dir": str(packets_dir),
        "judgments_path": str(judgments_path),
        "stages": stages,
    }
    return summary


def resolve_godot_bin(explicit_path: str | None) -> str:
    if explicit_path:
        return explicit_path
    env_value = os.environ.get("GODOT_BIN", "").strip()
    if env_value:
        return env_value
    for candidate in DEFAULT_GODOT_CANDIDATES:
        if Path(candidate).exists():
            return candidate
    raise FileNotFoundError("Unable to resolve Godot binary. Pass --godot-bin or set GODOT_BIN.")


def _run_json_command(stage_name: str, command: list[str], cwd: Path) -> dict[str, Any]:
    completed = subprocess.run(command, cwd=cwd, capture_output=True, text=True, encoding="utf-8")
    stdout = completed.stdout.strip()
    payload: dict[str, Any]
    try:
        payload = json.loads(stdout) if stdout else {}
    except json.JSONDecodeError:
        payload = {"raw_stdout": stdout}
    return {
        "stage": stage_name,
        "command": command,
        "returncode": completed.returncode,
        "stdout": payload,
        "stderr": completed.stderr.strip(),
    }


def _to_res_path(repo_root: Path, target: Path) -> str:
    resolved_target = target.resolve()
    resolved_repo = repo_root.resolve()
    try:
        relative = resolved_target.relative_to(resolved_repo)
    except ValueError:
        return str(resolved_target)
    return "res://" + str(relative).replace("\\", "/")


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    summary = run_unified_learning(args)
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
