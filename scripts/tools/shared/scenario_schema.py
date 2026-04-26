from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EXTRACTOR_VERSION = 1
EXTRACTOR_NAME = "deterministic_v1"
REVIEW_QUEUE_BUILDER_VERSION = 1
REVIEW_QUEUE_BUILDER_NAME = "scenario_review_queue_v1"
SUPPORTED_HUMAN_MATCH_MODES = frozenset({"two_player", "local_human_vs_human"})
LEARNING_REQUEST_RELATIVE_PATH = Path("learning") / "learning_request.json"
REVIEW_QUEUE_DIRNAME = "review_queue"
REVIEW_QUEUE_PENDING_DIRNAME = "pending"


def resolve_path(raw_path: str | Path, *, project_root: Path, user_root: Path | None = None) -> Path:
    raw_text = str(raw_path).strip()
    if not raw_text:
        raise ValueError("Path must not be empty.")
    if raw_text.startswith("user://"):
        if user_root is None:
            raise ValueError(f"user:// path requires --user-root: {raw_text}")
        suffix = raw_text.removeprefix("user://").replace("\\", "/")
        return (user_root / Path(suffix)).resolve()
    candidate = Path(raw_text)
    if not candidate.is_absolute():
        candidate = project_root / candidate
    return candidate.resolve()


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def deck_directory_name(deck_id: int) -> str:
    return f"deck_{deck_id}" if deck_id > 0 else "deck_unknown"


def scenario_id(match_id: str, turn_number: int, tracked_player_index: int) -> str:
    normalized_match_id = _slug(match_id) or "match_unknown"
    return f"{normalized_match_id}_turn{turn_number}_p{tracked_player_index}"


def scenario_output_path(output_root: Path, deck_id: int, scenario_name: str) -> Path:
    return output_root / deck_directory_name(deck_id) / f"{scenario_name}.json"


def review_seed_output_path(output_root: Path, scenario_name: str) -> Path:
    return output_root / REVIEW_QUEUE_DIRNAME / REVIEW_QUEUE_PENDING_DIRNAME / f"{scenario_name}.json"


def review_request_output_path(review_queue_root: Path, scenario_name: str) -> Path:
    return review_queue_root / REVIEW_QUEUE_PENDING_DIRNAME / f"{scenario_name}.json"


@dataclass(frozen=True)
class ScenarioSeed:
    scenario_id: str
    deck_id: int
    tracked_player_index: int
    source_match_id: str
    source_turn_number: int
    tags: tuple[str, ...]
    notes: str
    state_at_turn_start: dict[str, Any]
    expected_end_state_source: dict[str, Any]
    extraction_metadata: dict[str, Any]
    runtime_oracles: dict[str, Any]


def build_scenario_payload(seed: ScenarioSeed) -> dict[str, Any]:
    return {
        "scenario_id": seed.scenario_id,
        "schema_version": SCHEMA_VERSION,
        "deck_id": seed.deck_id,
        "tracked_player_index": seed.tracked_player_index,
        "source_match_id": seed.source_match_id,
        "source_turn_number": seed.source_turn_number,
        "tags": list(seed.tags),
        "notes": seed.notes,
        "state_at_turn_start": seed.state_at_turn_start,
        "expected_end_state": {
            "primary": {},
            "secondary": {},
        },
        "approved_divergent_end_states": [],
        "runtime_oracles": seed.runtime_oracles,
        "expected_end_state_source": seed.expected_end_state_source,
        "extraction_metadata": seed.extraction_metadata,
    }


def build_review_seed_payload(
    *,
    scenario_name: str,
    expected_end_state: dict[str, Any],
    source_match_id: str,
    source_turn_number: int,
    tracked_player_index: int,
    scenario_path: Path,
    output_root: Path,
) -> dict[str, Any]:
    return {
        "scenario_id": scenario_name,
        "status": "pending_review",
        "expected_end_state": expected_end_state,
        "ai_end_state": {},
        "diff": [],
        "llm_suggestion": {
            "resolution": "",
            "confidence": 0.0,
            "reason": "Seed artifact only. No runner/comparator review has been executed yet.",
        },
        "human_resolution": "",
        "seed_metadata": {
            "source_match_id": source_match_id,
            "source_turn_number": source_turn_number,
            "tracked_player_index": tracked_player_index,
            "scenario_path": str(scenario_path.relative_to(output_root)).replace("\\", "/"),
            "extractor": EXTRACTOR_NAME,
            "extractor_version": EXTRACTOR_VERSION,
        },
    }


def is_review_queue_artifact_path(path: Path, *, root: Path) -> bool:
    try:
        relative_parts = path.relative_to(root).parts
    except ValueError:
        relative_parts = path.parts
    return REVIEW_QUEUE_DIRNAME in relative_parts


def is_scenario_payload(payload: dict[str, Any]) -> bool:
    scenario_name = payload.get("scenario_id")
    if not isinstance(scenario_name, str) or not scenario_name.strip():
        return False
    if not isinstance(payload.get("state_at_turn_start"), dict):
        return False
    if not isinstance(payload.get("expected_end_state"), dict):
        return False
    return "tracked_player_index" in payload and "deck_id" in payload


def scenario_relative_path(scenario_path: Path, *, root: Path) -> str:
    return str(scenario_path.relative_to(root)).replace("\\", "/")


def build_review_request_payload_from_scenario(
    *,
    scenario_payload: dict[str, Any],
    scenario_path: Path,
    scenarios_root: Path,
) -> dict[str, Any]:
    scenario_name = str(scenario_payload.get("scenario_id", "")).strip()
    scenario_reference = scenario_relative_path(scenario_path, root=scenarios_root)
    payload = build_review_seed_payload(
        scenario_name=scenario_name,
        expected_end_state=_dict_or_empty(scenario_payload.get("expected_end_state")),
        source_match_id=str(scenario_payload.get("source_match_id", "")),
        source_turn_number=_int_or_default(scenario_payload.get("source_turn_number"), 0),
        tracked_player_index=_int_or_default(scenario_payload.get("tracked_player_index"), -1),
        scenario_path=scenario_path,
        output_root=scenarios_root,
    )
    payload["review_request_id"] = scenario_name
    payload["scenario_path"] = scenario_reference
    payload["builder_metadata"] = {
        "builder": REVIEW_QUEUE_BUILDER_NAME,
        "builder_version": REVIEW_QUEUE_BUILDER_VERSION,
    }
    return payload


def _slug(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "_", value.strip()).strip("_")


def _dict_or_empty(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def _int_or_default(value: Any, default: int) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default
