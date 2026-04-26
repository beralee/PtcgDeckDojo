from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any


SCRIPTS_TOOLS_ROOT = Path(__file__).resolve().parents[1]
if str(SCRIPTS_TOOLS_ROOT) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_TOOLS_ROOT))

from shared.scenario_schema import (  # noqa: E402
    REVIEW_QUEUE_DIRNAME,
    REVIEW_QUEUE_PENDING_DIRNAME,
    is_scenario_payload,
    resolve_path,
    scenario_relative_path,
    write_json,
)


DEFAULT_SCENARIOS_DIR = "tests/scenarios"
APPROVAL_APPLIER_NAME = "scenario_review_apply_approvals"
APPROVAL_APPLIER_VERSION = 1
APPROVED_HUMAN_RESOLUTIONS = frozenset({"equivalent", "dominant"})


@dataclass(frozen=True)
class ApprovalCandidate:
    request_path: Path
    request_relative_path: str
    review_request_id: str
    scenario_path: Path
    scenario_relative_path: str
    scenario_id: str
    resolution: str
    alternative: dict[str, Any]


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Scan hydrated scenario review requests and write approved divergent end states "
            "back into their source scenario files."
        ),
    )
    parser.add_argument(
        "--scenarios-dir",
        default=DEFAULT_SCENARIOS_DIR,
        help="Scenario root directory that contains scenario JSON files.",
    )
    parser.add_argument(
        "--review-queue-dir",
        help="Review queue root. Defaults to <scenarios-dir>/review_queue.",
    )
    parser.add_argument(
        "--user-root",
        help="Filesystem root that should back user:// paths.",
    )
    return parser.parse_args(argv)


def apply_scenario_review_approvals(args: argparse.Namespace) -> dict[str, Any]:
    project_root = Path(__file__).resolve().parents[3]
    user_root = resolve_path(args.user_root, project_root=project_root) if args.user_root else None
    scenarios_root = resolve_path(args.scenarios_dir, project_root=project_root, user_root=user_root)
    review_queue_root = (
        resolve_path(args.review_queue_dir, project_root=project_root, user_root=user_root)
        if args.review_queue_dir
        else (scenarios_root / REVIEW_QUEUE_DIRNAME).resolve()
    )

    report: dict[str, Any] = {
        "applier": APPROVAL_APPLIER_NAME,
        "applier_version": APPROVAL_APPLIER_VERSION,
        "scenarios_root": str(scenarios_root),
        "review_queue_root": str(review_queue_root),
        "applied_requests": [],
        "updated_scenarios": [],
        "skipped_requests": [],
        "warnings": [],
    }

    request_files = discover_review_request_files(review_queue_root)
    candidates_by_scenario: dict[Path, list[ApprovalCandidate]] = defaultdict(list)

    for request_path in request_files:
        candidate, skipped_entry = _build_approval_candidate(
            request_path=request_path,
            review_queue_root=review_queue_root,
            scenarios_root=scenarios_root,
        )
        if skipped_entry is not None:
            report["skipped_requests"].append(skipped_entry)
            continue
        candidates_by_scenario[candidate.scenario_path].append(candidate)

    for scenario_path in sorted(candidates_by_scenario, key=lambda path: scenario_relative_path(path, root=scenarios_root)):
        scenario_candidates = candidates_by_scenario[scenario_path]
        scenario_payload = _read_json_file(scenario_path)
        if not scenario_payload:
            report["skipped_requests"].extend(
                _skip_candidates(
                    scenario_candidates,
                    reason="invalid_scenario_json",
                )
            )
            continue
        if not is_scenario_payload(scenario_payload):
            report["skipped_requests"].extend(
                _skip_candidates(
                    scenario_candidates,
                    reason="non_scenario_target",
                )
            )
            continue

        approved_alternatives = scenario_payload.get("approved_divergent_end_states", [])
        if not isinstance(approved_alternatives, list):
            report["skipped_requests"].extend(
                _skip_candidates(
                    scenario_candidates,
                    reason="invalid_approved_divergent_end_states",
                )
            )
            continue

        existing_alternatives = list(approved_alternatives)
        existing_ids = {
            _alternative_id_value(alternative, index): alternative
            for index, alternative in enumerate(existing_alternatives)
            if isinstance(alternative, dict)
        }
        existing_end_state_keys = {
            _canonical_json(end_state)
            for alternative in existing_alternatives
            for end_state in [_alternative_end_state(alternative)]
            if end_state
        }
        applied_for_scenario: list[str] = []

        for candidate in scenario_candidates:
            alternative = candidate.alternative
            alternative_id = str(alternative["alternative_id"])
            end_state_key = _canonical_json(_alternative_end_state(alternative))
            existing_with_same_id = existing_ids.get(alternative_id)
            if existing_with_same_id is not None:
                if _canonical_json(existing_with_same_id) == _canonical_json(alternative) or (
                    _alternative_end_state(existing_with_same_id) and _canonical_json(_alternative_end_state(existing_with_same_id)) == end_state_key
                ):
                    report["skipped_requests"].append(
                        _skip_request_entry(candidate, reason="already_approved")
                    )
                else:
                    report["skipped_requests"].append(
                        _skip_request_entry(candidate, reason="conflicting_alternative_id")
                    )
                continue
            if end_state_key in existing_end_state_keys:
                report["skipped_requests"].append(
                    _skip_request_entry(candidate, reason="duplicate_approved_end_state")
                )
                continue

            existing_alternatives.append(alternative)
            existing_ids[alternative_id] = alternative
            existing_end_state_keys.add(end_state_key)
            applied_for_scenario.append(alternative_id)
            report["applied_requests"].append(
                {
                    "review_request_id": candidate.review_request_id,
                    "request_path": candidate.request_relative_path,
                    "scenario_id": str(scenario_payload.get("scenario_id", candidate.scenario_id)),
                    "scenario_path": candidate.scenario_relative_path,
                    "alternative_id": alternative_id,
                    "resolution": candidate.resolution,
                }
            )

        if not applied_for_scenario:
            continue

        scenario_payload["approved_divergent_end_states"] = existing_alternatives
        write_json(scenario_path, scenario_payload)
        report["updated_scenarios"].append(
            {
                "scenario_id": str(scenario_payload.get("scenario_id", "")),
                "scenario_path": scenario_relative_path(scenario_path, root=scenarios_root),
                "applied_approval_count": len(applied_for_scenario),
                "alternative_ids": applied_for_scenario,
            }
        )

    if not request_files:
        report["warnings"].append({"reason": "no_review_requests_found"})

    report["summary"] = {
        "request_count": len(request_files),
        "applied_request_count": len(report["applied_requests"]),
        "updated_scenario_count": len(report["updated_scenarios"]),
        "skipped_request_count": len(report["skipped_requests"]),
        "warning_count": len(report["warnings"]),
    }
    return report


def discover_review_request_files(review_queue_root: Path) -> list[Path]:
    pending_dir = review_queue_root / REVIEW_QUEUE_PENDING_DIRNAME
    if not pending_dir.exists():
        return []
    return sorted(
        [path for path in pending_dir.rglob("*.json") if path.is_file()],
        key=lambda path: path.relative_to(review_queue_root).as_posix(),
    )


def _build_approval_candidate(
    *,
    request_path: Path,
    review_queue_root: Path,
    scenarios_root: Path,
) -> tuple[ApprovalCandidate | None, dict[str, Any] | None]:
    request_relative_path = request_path.relative_to(review_queue_root).as_posix()
    request_payload = _read_json_file(request_path)
    if not request_payload:
        return None, {
            "request_path": request_relative_path,
            "reason": "invalid_request_json",
        }

    resolution = _normalize_human_resolution(request_payload.get("human_resolution", ""))
    if resolution not in APPROVED_HUMAN_RESOLUTIONS:
        return None, {
            "request_path": request_relative_path,
            "review_request_id": _review_request_id(request_payload, request_path),
            "reason": "human_resolution_not_approved",
        }

    if not _is_hydrated_review_request(request_payload):
        return None, {
            "request_path": request_relative_path,
            "review_request_id": _review_request_id(request_payload, request_path),
            "reason": "request_not_hydrated",
        }

    ai_end_state = request_payload.get("ai_end_state", {})
    if not isinstance(ai_end_state, dict) or not ai_end_state:
        return None, {
            "request_path": request_relative_path,
            "review_request_id": _review_request_id(request_payload, request_path),
            "reason": "missing_ai_end_state",
        }

    raw_scenario_path = str(request_payload.get("scenario_path", "")).strip()
    if not raw_scenario_path:
        return None, {
            "request_path": request_relative_path,
            "review_request_id": _review_request_id(request_payload, request_path),
            "reason": "missing_scenario_path",
        }

    scenario_path = (scenarios_root / Path(raw_scenario_path)).resolve()
    try:
        scenario_path.relative_to(scenarios_root)
    except ValueError:
        return None, {
            "request_path": request_relative_path,
            "review_request_id": _review_request_id(request_payload, request_path),
            "scenario_path": raw_scenario_path.replace("\\", "/"),
            "reason": "scenario_path_outside_root",
        }

    review_request_id = _review_request_id(request_payload, request_path)
    scenario_relative = scenario_relative_path(scenario_path, root=scenarios_root)
    scenario_id = str(request_payload.get("scenario_id", "")).strip() or scenario_path.stem
    alternative = {
        "alternative_id": review_request_id,
        "resolution": resolution,
        "source_review_request_id": review_request_id,
        "source_review_request_path": request_relative_path,
        "end_state": ai_end_state,
    }
    return (
        ApprovalCandidate(
            request_path=request_path,
            request_relative_path=request_relative_path,
            review_request_id=review_request_id,
            scenario_path=scenario_path,
            scenario_relative_path=scenario_relative,
            scenario_id=scenario_id,
            resolution=resolution,
            alternative=alternative,
        ),
        None,
    )


def _skip_candidates(candidates: list[ApprovalCandidate], *, reason: str) -> list[dict[str, Any]]:
    return [_skip_request_entry(candidate, reason=reason) for candidate in candidates]


def _skip_request_entry(candidate: ApprovalCandidate, *, reason: str) -> dict[str, Any]:
    return {
        "review_request_id": candidate.review_request_id,
        "request_path": candidate.request_relative_path,
        "scenario_id": candidate.scenario_id,
        "scenario_path": candidate.scenario_relative_path,
        "reason": reason,
    }


def _read_json_file(path: Path) -> dict[str, Any]:
    try:
        parsed = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _normalize_human_resolution(value: Any) -> str:
    return str(value).strip().lower()


def _is_hydrated_review_request(request_payload: dict[str, Any]) -> bool:
    runner_verdict = request_payload.get("runner_verdict", {})
    if isinstance(runner_verdict, dict) and runner_verdict:
        return True
    ai_end_state = request_payload.get("ai_end_state", {})
    if isinstance(ai_end_state, dict) and ai_end_state:
        return True
    diff = request_payload.get("diff", [])
    return isinstance(diff, list) and bool(diff)


def _review_request_id(request_payload: dict[str, Any], request_path: Path) -> str:
    raw_id = str(request_payload.get("review_request_id", "")).strip()
    if raw_id:
        return raw_id
    scenario_id = str(request_payload.get("scenario_id", "")).strip()
    if scenario_id:
        return scenario_id
    return request_path.stem


def _alternative_id_value(alternative: Any, index: int) -> str:
    if not isinstance(alternative, dict):
        return f"approved_alt_{index}"
    raw_id = str(alternative.get("alternative_id", alternative.get("id", ""))).strip()
    return raw_id or f"approved_alt_{index}"


def _alternative_end_state(alternative: Any) -> dict[str, Any]:
    if not isinstance(alternative, dict):
        return {}
    end_state = alternative.get("end_state", alternative)
    return end_state if isinstance(end_state, dict) else {}


def _canonical_json(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    report = apply_scenario_review_approvals(args)
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
