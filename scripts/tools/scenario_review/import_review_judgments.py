from __future__ import annotations

import argparse
import json
import sys
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


IMPORTER_NAME = "scenario_review_judgment_importer"
IMPORTER_VERSION = 1
DEFAULT_SCENARIOS_DIR = "tests/scenarios"
SEED_PLACEHOLDER_REASON = "Seed artifact only. No runner/comparator review has been executed yet."


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Import LLM or human review judgments into hydrated pending review requests. "
            "Judgments update llm_suggestion and may optionally set human_resolution."
        ),
    )
    parser.add_argument(
        "--judgments-path",
        required=True,
        help="JSONL file containing one judgment object per line.",
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
        "--allow-human-resolution",
        action="store_true",
        help="Allow imported judgments to set human_resolution when present.",
    )
    parser.add_argument(
        "--overwrite-llm-suggestion",
        action="store_true",
        help="Overwrite non-empty llm_suggestion fields on existing requests.",
    )
    parser.add_argument(
        "--user-root",
        help="Filesystem root that should back user:// paths.",
    )
    return parser.parse_args(argv)


def import_review_judgments(args: argparse.Namespace) -> dict[str, Any]:
    project_root = Path(__file__).resolve().parents[3]
    user_root = resolve_path(args.user_root, project_root=project_root) if args.user_root else None
    scenarios_root = resolve_path(args.scenarios_dir, project_root=project_root, user_root=user_root)
    review_queue_root = (
        resolve_path(args.review_queue_dir, project_root=project_root, user_root=user_root)
        if args.review_queue_dir
        else (scenarios_root / REVIEW_QUEUE_DIRNAME).resolve()
    )
    judgments_path = resolve_path(args.judgments_path, project_root=project_root, user_root=user_root)

    request_index = build_request_index(review_queue_root)
    judgments = load_judgments(judgments_path)

    updated: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []
    errors: list[dict[str, Any]] = []

    for line_number, judgment in judgments:
        review_request_id = str(judgment.get("review_request_id", "")).strip()
        if not review_request_id:
            errors.append({"line_number": line_number, "reason": "missing_review_request_id"})
            continue

        request_path = request_index.get(review_request_id)
        if request_path is None:
            skipped.append(
                {
                    "line_number": line_number,
                    "review_request_id": review_request_id,
                    "reason": "review_request_not_found",
                }
            )
            continue

        request_payload = _read_json_file(request_path)
        if not request_payload:
            errors.append(
                {
                    "line_number": line_number,
                    "review_request_id": review_request_id,
                    "request_path": str(request_path),
                    "reason": "invalid_request_json",
                }
            )
            continue

        apply_result = _apply_judgment_to_request(
            request_payload=request_payload,
            judgment=judgment,
            allow_human_resolution=bool(args.allow_human_resolution),
            overwrite_llm_suggestion=bool(args.overwrite_llm_suggestion),
        )
        if apply_result["status"] == "skipped":
            skipped.append(
                {
                    "line_number": line_number,
                    "review_request_id": review_request_id,
                    "request_path": str(request_path),
                    "reason": apply_result["reason"],
                }
            )
            continue
        if apply_result["status"] == "error":
            errors.append(
                {
                    "line_number": line_number,
                    "review_request_id": review_request_id,
                    "request_path": str(request_path),
                    "reason": apply_result["reason"],
                }
            )
            continue

        write_json(request_path, request_payload)
        updated.append(
            {
                "line_number": line_number,
                "review_request_id": review_request_id,
                "request_path": str(request_path),
                "updated_fields": apply_result["updated_fields"],
            }
        )

    report = {
        "importer": IMPORTER_NAME,
        "importer_version": IMPORTER_VERSION,
        "judgments_path": str(judgments_path),
        "review_queue_root": str(review_queue_root),
        "updated": updated,
        "skipped": skipped,
        "errors": errors,
        "updated_count": len(updated),
        "skipped_count": len(skipped),
        "error_count": len(errors),
    }
    return report


def build_request_index(review_queue_root: Path) -> dict[str, Path]:
    pending_dir = review_queue_root / REVIEW_QUEUE_PENDING_DIRNAME
    index: dict[str, Path] = {}
    if not pending_dir.exists():
        return index
    for request_path in sorted(pending_dir.rglob("*.json"), key=lambda path: path.relative_to(review_queue_root).as_posix()):
        payload = _read_json_file(request_path)
        if not payload:
            continue
        review_request_id = str(payload.get("review_request_id", "")).strip()
        if review_request_id and review_request_id not in index:
            index[review_request_id] = request_path
    return index


def load_judgments(path: Path) -> list[tuple[int, dict[str, Any]]]:
    judgments: list[tuple[int, dict[str, Any]]] = []
    if not path.exists():
        return judgments
    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw_line.lstrip("\ufeff").strip()
        if not line:
            continue
        try:
            parsed = json.loads(line)
        except json.JSONDecodeError:
            judgments.append((line_number, {"_parse_error": True}))
            continue
        if isinstance(parsed, dict):
            judgments.append((line_number, parsed))
        else:
            judgments.append((line_number, {"_parse_error": True}))
    return judgments


def _apply_judgment_to_request(
    *,
    request_payload: dict[str, Any],
    judgment: dict[str, Any],
    allow_human_resolution: bool,
    overwrite_llm_suggestion: bool,
) -> dict[str, Any]:
    if judgment.get("_parse_error", False):
        return {"status": "error", "reason": "invalid_judgment_json"}

    llm_suggestion = request_payload.get("llm_suggestion", {})
    if not isinstance(llm_suggestion, dict):
        llm_suggestion = {}

    incoming_resolution = str(judgment.get("resolution", judgment.get("llm_resolution", ""))).strip()
    incoming_confidence = judgment.get("confidence", judgment.get("llm_confidence", 0.0))
    incoming_reason = str(judgment.get("reason", judgment.get("llm_reason", ""))).strip()
    incoming_human_resolution = str(judgment.get("human_resolution", "")).strip()

    updated_fields: list[str] = []

    if incoming_resolution or incoming_reason or _is_number_like(incoming_confidence):
        if not overwrite_llm_suggestion and _llm_suggestion_present(llm_suggestion):
            return {"status": "skipped", "reason": "llm_suggestion_already_present"}
        llm_suggestion["resolution"] = incoming_resolution
        llm_suggestion["confidence"] = _coerce_float(incoming_confidence, 0.0)
        llm_suggestion["reason"] = incoming_reason
        request_payload["llm_suggestion"] = llm_suggestion
        updated_fields.append("llm_suggestion")

    if incoming_human_resolution:
        if not allow_human_resolution:
            return {"status": "skipped", "reason": "human_resolution_not_allowed"}
        if str(request_payload.get("human_resolution", "")).strip():
            return {"status": "skipped", "reason": "human_resolution_already_present"}
        request_payload["human_resolution"] = incoming_human_resolution
        updated_fields.append("human_resolution")

    if not updated_fields:
        return {"status": "skipped", "reason": "no_effective_updates"}
    return {"status": "updated", "updated_fields": updated_fields}


def _read_json_file(path: Path) -> dict[str, Any]:
    try:
        parsed = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _llm_suggestion_present(value: dict[str, Any]) -> bool:
    resolution = str(value.get("resolution", "")).strip()
    reason = str(value.get("reason", "")).strip()
    confidence = _coerce_float(value.get("confidence", 0.0), 0.0)
    if resolution:
        return True
    if confidence > 0.0:
        return True
    if reason and reason != SEED_PLACEHOLDER_REASON:
        return True
    return False


def _is_number_like(value: Any) -> bool:
    try:
        float(value)
        return True
    except (TypeError, ValueError):
        return False


def _coerce_float(value: Any, default: float) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    report = import_review_judgments(args)
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0 if report["error_count"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
