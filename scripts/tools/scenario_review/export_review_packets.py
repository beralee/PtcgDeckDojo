from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any


SCRIPTS_TOOLS_ROOT = Path(__file__).resolve().parents[1]
if str(SCRIPTS_TOOLS_ROOT) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_TOOLS_ROOT))

from shared.scenario_schema import (  # noqa: E402
    REVIEW_QUEUE_DIRNAME,
    REVIEW_QUEUE_PENDING_DIRNAME,
    resolve_path,
    write_json,
)


EXPORTER_NAME = "scenario_review_packet_exporter"
EXPORTER_VERSION = 1
DEFAULT_SCENARIOS_DIR = "tests/scenarios"
DEFAULT_INCLUDE_STATUSES = ("FAIL", "DIVERGE")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Export hydrated pending scenario review requests into deterministic review packets "
            "for LLM or human adjudication."
        ),
    )
    parser.add_argument(
        "--scenarios-dir",
        default=DEFAULT_SCENARIOS_DIR,
        help="Scenario root directory. Used to resolve the default review queue path.",
    )
    parser.add_argument(
        "--review-queue-dir",
        help="Review queue root. Defaults to <scenarios-dir>/review_queue.",
    )
    parser.add_argument(
        "--output-dir",
        required=True,
        help="Output directory for manifest.json and packets.jsonl.",
    )
    parser.add_argument(
        "--status",
        action="append",
        default=[],
        help="Runner verdict status to include. May be repeated. Defaults to FAIL and DIVERGE.",
    )
    parser.add_argument(
        "--include-resolved",
        action="store_true",
        help="Include requests that already have non-empty human_resolution.",
    )
    parser.add_argument(
        "--user-root",
        help="Filesystem root that should back user:// paths.",
    )
    return parser.parse_args(argv)


def export_review_packets(args: argparse.Namespace) -> dict[str, Any]:
    project_root = Path(__file__).resolve().parents[3]
    user_root = resolve_path(args.user_root, project_root=project_root) if args.user_root else None
    scenarios_root = resolve_path(args.scenarios_dir, project_root=project_root, user_root=user_root)
    review_queue_root = (
        resolve_path(args.review_queue_dir, project_root=project_root, user_root=user_root)
        if args.review_queue_dir
        else (scenarios_root / REVIEW_QUEUE_DIRNAME).resolve()
    )
    output_root = resolve_path(args.output_dir, project_root=project_root, user_root=user_root)
    included_statuses = _normalize_statuses(args.status)

    pending_requests = discover_pending_requests(review_queue_root)
    exported_packets: list[dict[str, Any]] = []
    skipped_requests: list[dict[str, Any]] = []

    for request_path in pending_requests:
        request_relative_path = request_path.relative_to(review_queue_root).as_posix()
        request_payload = _read_json_file(request_path)
        if not request_payload:
            skipped_requests.append({"request_path": request_relative_path, "reason": "invalid_request_json"})
            continue

        runner_verdict = request_payload.get("runner_verdict", {})
        if not isinstance(runner_verdict, dict) or not runner_verdict:
            skipped_requests.append({"request_path": request_relative_path, "reason": "request_not_hydrated"})
            continue

        runner_status = str(runner_verdict.get("status", "")).strip().upper()
        if runner_status not in included_statuses:
            skipped_requests.append(
                {
                    "request_path": request_relative_path,
                    "review_request_id": _review_request_id(request_payload, request_path),
                    "reason": "runner_status_filtered_out",
                    "runner_status": runner_status,
                }
            )
            continue

        human_resolution = str(request_payload.get("human_resolution", "")).strip()
        if human_resolution and not args.include_resolved:
            skipped_requests.append(
                {
                    "request_path": request_relative_path,
                    "review_request_id": _review_request_id(request_payload, request_path),
                    "reason": "already_human_resolved",
                    "human_resolution": human_resolution,
                }
            )
            continue

        exported_packets.append(
            {
                "review_request_id": _review_request_id(request_payload, request_path),
                "scenario_id": str(request_payload.get("scenario_id", "")).strip(),
                "scenario_path": str(request_payload.get("scenario_path", "")).strip(),
                "request_path": request_relative_path,
                "runner_verdict": runner_verdict,
                "expected_end_state": request_payload.get("expected_end_state", {}),
                "ai_end_state": request_payload.get("ai_end_state", {}),
                "diff": request_payload.get("diff", []),
                "llm_suggestion": request_payload.get("llm_suggestion", {}),
                "human_resolution": human_resolution,
                "seed_metadata": request_payload.get("seed_metadata", {}),
            }
        )

    output_root.mkdir(parents=True, exist_ok=True)
    packets_path = output_root / "packets.jsonl"
    manifest_path = output_root / "manifest.json"

    _write_jsonl(packets_path, exported_packets)

    status_counts = Counter(
        str(packet.get("runner_verdict", {}).get("status", "")).strip().upper()
        for packet in exported_packets
    )
    manifest = {
        "exporter": EXPORTER_NAME,
        "exporter_version": EXPORTER_VERSION,
        "scenarios_root": str(scenarios_root),
        "review_queue_root": str(review_queue_root),
        "output_root": str(output_root),
        "included_statuses": sorted(included_statuses),
        "include_resolved": bool(args.include_resolved),
        "packets_path": str(packets_path),
        "packet_count": len(exported_packets),
        "status_counts": dict(status_counts),
        "skipped_requests": skipped_requests,
        "skipped_request_count": len(skipped_requests),
    }
    write_json(manifest_path, manifest)
    return manifest


def discover_pending_requests(review_queue_root: Path) -> list[Path]:
    pending_dir = review_queue_root / REVIEW_QUEUE_PENDING_DIRNAME
    if not pending_dir.exists():
        return []
    return sorted(
        [path for path in pending_dir.rglob("*.json") if path.is_file()],
        key=lambda path: path.relative_to(review_queue_root).as_posix(),
    )


def _normalize_statuses(raw_statuses: list[str]) -> set[str]:
    normalized = {status.strip().upper() for status in raw_statuses if status.strip()}
    return normalized or set(DEFAULT_INCLUDE_STATUSES)


def _read_json_file(path: Path) -> dict[str, Any]:
    try:
        parsed = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _write_jsonl(path: Path, rows: list[dict[str, Any]]) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False))
            handle.write("\n")


def _review_request_id(request_payload: dict[str, Any], request_path: Path) -> str:
    raw_id = str(request_payload.get("review_request_id", "")).strip()
    if raw_id:
        return raw_id
    scenario_id = str(request_payload.get("scenario_id", "")).strip()
    if scenario_id:
        return scenario_id
    return request_path.stem


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    manifest = export_review_packets(args)
    print(json.dumps(manifest, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
