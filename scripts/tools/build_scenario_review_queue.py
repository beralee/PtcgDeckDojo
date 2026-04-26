from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from shared.scenario_schema import (
    REVIEW_QUEUE_BUILDER_NAME,
    REVIEW_QUEUE_BUILDER_VERSION,
    REVIEW_QUEUE_DIRNAME,
    build_review_request_payload_from_scenario,
    is_review_queue_artifact_path,
    is_scenario_payload,
    resolve_path,
    review_request_output_path,
    scenario_relative_path,
    write_json,
)


DEFAULT_SCENARIOS_DIR = "tests/scenarios"


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Build a deterministic review queue payload directory from extracted scenario JSON files. "
            "Only scenario payloads are transformed; runnable scenario files are not copied."
        ),
    )
    parser.add_argument(
        "--scenarios-dir",
        default=DEFAULT_SCENARIOS_DIR,
        help="Directory containing extracted scenario JSON files.",
    )
    parser.add_argument(
        "--output-dir",
        help="Review queue output root. Review request JSONs are written to <output>/pending/. Defaults to <scenarios-dir>/review_queue.",
    )
    parser.add_argument(
        "--user-root",
        help="Filesystem root that should back user:// paths.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite existing pending review request payloads.",
    )
    return parser.parse_args(argv)


def build_scenario_review_queue(args: argparse.Namespace) -> dict[str, Any]:
    project_root = Path(__file__).resolve().parents[2]
    user_root = resolve_path(args.user_root, project_root=project_root) if args.user_root else None
    scenarios_root = resolve_path(args.scenarios_dir, project_root=project_root, user_root=user_root)
    output_root = (
        resolve_path(args.output_dir, project_root=project_root, user_root=user_root)
        if args.output_dir
        else (scenarios_root / REVIEW_QUEUE_DIRNAME).resolve()
    )

    report: dict[str, Any] = {
        "builder": REVIEW_QUEUE_BUILDER_NAME,
        "builder_version": REVIEW_QUEUE_BUILDER_VERSION,
        "scenarios_root": str(scenarios_root),
        "output_root": str(output_root),
        "generated_requests": [],
        "skipped_files": [],
        "warnings": [],
    }

    scenario_files = discover_scenario_files(scenarios_root)
    seen_scenario_ids: dict[str, Path] = {}

    for scenario_path in scenario_files:
        relative_path = scenario_relative_path(scenario_path, root=scenarios_root)
        payload = _read_json_file(scenario_path)
        if not payload:
            report["skipped_files"].append(
                {
                    "path": relative_path,
                    "reason": "invalid_json",
                }
            )
            continue
        if not is_scenario_payload(payload):
            report["skipped_files"].append(
                {
                    "path": relative_path,
                    "reason": "non_scenario_json",
                }
            )
            continue

        scenario_name = str(payload.get("scenario_id", "")).strip()
        duplicate_path = seen_scenario_ids.get(scenario_name)
        if duplicate_path is not None:
            report["skipped_files"].append(
                {
                    "path": relative_path,
                    "scenario_id": scenario_name,
                    "reason": "duplicate_scenario_id",
                    "first_path": scenario_relative_path(duplicate_path, root=scenarios_root),
                }
            )
            continue

        request_path = review_request_output_path(output_root, scenario_name)
        if not args.overwrite and request_path.exists():
            report["skipped_files"].append(
                {
                    "path": relative_path,
                    "scenario_id": scenario_name,
                    "reason": "review_request_exists",
                }
            )
            seen_scenario_ids[scenario_name] = scenario_path
            continue

        request_payload = build_review_request_payload_from_scenario(
            scenario_payload=payload,
            scenario_path=scenario_path,
            scenarios_root=scenarios_root,
        )
        write_json(request_path, request_payload)
        seen_scenario_ids[scenario_name] = scenario_path
        report["generated_requests"].append(
            {
                "scenario_id": scenario_name,
                "scenario_path": relative_path,
                "review_request_path": str(request_path),
            }
        )

    if not report["generated_requests"] and scenario_files:
        report["warnings"].append({"reason": "no_review_requests_generated"})

    report["summary"] = {
        "source_json_count": len(scenario_files),
        "generated_request_count": len(report["generated_requests"]),
        "skipped_file_count": len(report["skipped_files"]),
        "warning_count": len(report["warnings"]),
    }
    return report


def discover_scenario_files(scenarios_root: Path) -> list[Path]:
    if not scenarios_root.exists():
        return []
    return sorted(
        [
            path
            for path in scenarios_root.rglob("*.json")
            if path.is_file() and not is_review_queue_artifact_path(path, root=scenarios_root)
        ],
        key=lambda path: scenario_relative_path(path, root=scenarios_root),
    )


def _read_json_file(path: Path) -> dict[str, Any]:
    try:
        parsed = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return parsed if isinstance(parsed, dict) else {}


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    report = build_scenario_review_queue(args)
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
