from __future__ import annotations

import argparse
import json
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from shared.scenario_schema import (
    EXTRACTOR_NAME,
    EXTRACTOR_VERSION,
    LEARNING_REQUEST_RELATIVE_PATH,
    SUPPORTED_HUMAN_MATCH_MODES,
    ScenarioSeed,
    build_review_seed_payload,
    build_scenario_payload,
    resolve_path,
    review_seed_output_path,
    scenario_id,
    scenario_output_path,
    write_json,
)


DEFAULT_MATCH_RECORDS_ROOT = "user://match_records"
DEFAULT_OUTPUT_DIR = "tests/scenarios"
HIDDEN_ZONE_ORACLE_TRAINERS = frozenset({"裁判", "奇树", "洛兹安", "反常邮票"})


@dataclass(frozen=True)
class MatchArtifacts:
    match_dir: Path
    learning_request: dict[str, Any]
    match_data: dict[str, Any]
    turns_data: dict[str, Any]
    detail_events: list[dict[str, Any]]

    @property
    def match_id(self) -> str:
        meta = self.match_data.get("meta", {})
        return str(meta.get("match_id", "")).strip() or self.match_dir.name

    @property
    def match_mode(self) -> str:
        meta = self.match_data.get("meta", {})
        return str(meta.get("mode", "")).strip()


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Scan marked human-vs-human match records and emit deterministic scenario skeletons.",
    )
    parser.add_argument(
        "--match-records-root",
        default=DEFAULT_MATCH_RECORDS_ROOT,
        help="Directory containing match record subdirectories. Supports user:// paths when --user-root is provided.",
    )
    parser.add_argument(
        "--learning-pool",
        help="Optional learning pool manifest. When provided, only listed matches are considered.",
    )
    parser.add_argument(
        "--output-dir",
        default=DEFAULT_OUTPUT_DIR,
        help="Scenario output root. Scenarios are written to <output>/<deck_dir>/ and review seeds to <output>/review_queue/pending/.",
    )
    parser.add_argument(
        "--user-root",
        help="Filesystem root that should back user:// paths during extraction.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite existing scenario or review seed artifacts.",
    )
    parser.add_argument(
        "--match-id",
        action="append",
        default=[],
        help="Optional specific match_id to process. May be provided more than once.",
    )
    return parser.parse_args(argv)


def extract_learning_pool_scenarios(args: argparse.Namespace) -> dict[str, Any]:
    project_root = Path(__file__).resolve().parents[2]
    user_root = resolve_path(args.user_root, project_root=project_root) if args.user_root else None
    match_records_root = resolve_path(args.match_records_root, project_root=project_root, user_root=user_root)
    output_root = resolve_path(args.output_dir, project_root=project_root, user_root=user_root)
    learning_pool_path = (
        resolve_path(args.learning_pool, project_root=project_root, user_root=user_root)
        if args.learning_pool
        else None
    )
    requested_match_ids = {match_id.strip() for match_id in args.match_id if match_id.strip()}

    report: dict[str, Any] = {
        "extractor": EXTRACTOR_NAME,
        "extractor_version": EXTRACTOR_VERSION,
        "match_records_root": str(match_records_root),
        "output_root": str(output_root),
        "processed_matches": [],
        "generated_scenarios": [],
        "skipped_matches": [],
        "warnings": [],
    }

    output_root.mkdir(parents=True, exist_ok=True)
    match_dirs = discover_match_dirs(
        match_records_root=match_records_root,
        learning_pool_path=learning_pool_path,
        requested_match_ids=requested_match_ids,
        project_root=project_root,
        user_root=user_root,
    )

    for match_dir in match_dirs:
        match_report = {"match_dir": str(match_dir), "scenarios": [], "skips": []}
        try:
            artifacts = load_match_artifacts(match_dir)
        except ValueError as exc:
            report["skipped_matches"].append({"match_dir": str(match_dir), "reason": str(exc)})
            continue

        if artifacts.match_mode not in SUPPORTED_HUMAN_MATCH_MODES:
            report["skipped_matches"].append(
                {
                    "match_dir": str(match_dir),
                    "match_id": artifacts.match_id,
                    "reason": f"Unsupported match mode: {artifacts.match_mode or 'unknown'}",
                }
            )
            continue
        if requested_match_ids and artifacts.match_id not in requested_match_ids:
            report["skipped_matches"].append(
                {
                    "match_dir": str(match_dir),
                    "match_id": artifacts.match_id,
                    "reason": "Filtered out by --match-id",
                }
            )
            continue

        generated = generate_match_scenarios(artifacts=artifacts, output_root=output_root, overwrite=args.overwrite)
        match_report["scenarios"] = generated["generated"]
        match_report["skips"] = generated["skipped"]
        report["generated_scenarios"].extend(generated["generated"])
        report["warnings"].extend(generated["warnings"])
        report["processed_matches"].append(match_report)

    report["summary"] = {
        "match_count": len(report["processed_matches"]),
        "scenario_count": len(report["generated_scenarios"]),
        "skipped_match_count": len(report["skipped_matches"]),
        "warning_count": len(report["warnings"]),
    }
    return report


def discover_match_dirs(
    *,
    match_records_root: Path,
    learning_pool_path: Path | None,
    requested_match_ids: set[str],
    project_root: Path,
    user_root: Path | None,
) -> list[Path]:
    explicit_dirs: list[Path] = []
    if learning_pool_path is not None:
        payload = _read_json_file(learning_pool_path)
        matches = payload.get("matches", [])
        if not isinstance(matches, list):
            raise ValueError(f"Invalid learning pool manifest: {learning_pool_path}")
        for match_entry in matches:
            if not isinstance(match_entry, dict):
                continue
            match_id = str(match_entry.get("match_id", "")).strip()
            if requested_match_ids and match_id and match_id not in requested_match_ids:
                continue
            source_dir = str(match_entry.get("source_dir", "")).strip()
            if source_dir:
                candidate = resolve_path(source_dir, project_root=project_root, user_root=user_root)
            elif match_id:
                candidate = match_records_root / match_id
            else:
                continue
            explicit_dirs.append(candidate.resolve())

    if explicit_dirs:
        return sorted({path for path in explicit_dirs if path.exists()}, key=lambda path: path.name)

    if not match_records_root.exists():
        return []
    discovered_dirs = [path for path in match_records_root.iterdir() if path.is_dir()]
    if requested_match_ids:
        discovered_dirs = [path for path in discovered_dirs if path.name in requested_match_ids]
    return sorted(discovered_dirs, key=lambda path: path.name)


def load_match_artifacts(match_dir: Path) -> MatchArtifacts:
    request_path = match_dir / LEARNING_REQUEST_RELATIVE_PATH
    if not request_path.exists():
        raise ValueError("Missing learning/learning_request.json")
    learning_request = _read_json_file(request_path)
    if not learning_request:
        raise ValueError("Empty or invalid learning/learning_request.json")

    match_path = match_dir / "match.json"
    turns_path = match_dir / "turns.json"
    detail_path = match_dir / "detail.jsonl"
    if not match_path.exists() or not turns_path.exists() or not detail_path.exists():
        raise ValueError("Missing match.json, turns.json, or detail.jsonl")

    match_data = _read_json_file(match_path)
    turns_data = _read_json_file(turns_path)
    detail_events = _read_jsonl_file(detail_path)
    if not match_data:
        raise ValueError("Invalid match.json")
    if not turns_data.get("turns"):
        raise ValueError("turns.json does not contain turns")
    if not detail_events:
        raise ValueError("detail.jsonl does not contain events")

    return MatchArtifacts(
        match_dir=match_dir,
        learning_request=learning_request,
        match_data=match_data,
        turns_data=turns_data,
        detail_events=detail_events,
    )


def generate_match_scenarios(*, artifacts: MatchArtifacts, output_root: Path, overwrite: bool) -> dict[str, list[Any]]:
    generated: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []
    turns = artifacts.turns_data.get("turns", [])
    events_by_turn = _group_events_by_turn(artifacts.detail_events)

    for turn_entry in turns:
        if not isinstance(turn_entry, dict):
            continue
        turn_number = _int(turn_entry.get("turn_number", 0))
        if turn_number <= 0:
            continue
        turn_events = events_by_turn.get(turn_number, [])
        candidate = _build_candidate_seed(artifacts=artifacts, turn_entry=turn_entry, turn_events=turn_events)
        if candidate is None:
            skipped.append(
                {
                    "match_id": artifacts.match_id,
                    "turn_number": turn_number,
                    "reason": "Turn does not meet deterministic extraction rules",
                }
            )
            continue

        scenario_payload = build_scenario_payload(candidate)
        scenario_path = scenario_output_path(output_root, candidate.deck_id, candidate.scenario_id)
        review_path = review_seed_output_path(output_root, candidate.scenario_id)
        if not overwrite and (scenario_path.exists() or review_path.exists()):
            skipped.append(
                {
                    "match_id": artifacts.match_id,
                    "turn_number": turn_number,
                    "scenario_id": candidate.scenario_id,
                    "reason": "Scenario or review seed already exists",
                }
            )
            continue

        write_json(scenario_path, scenario_payload)
        write_json(
            review_path,
            build_review_seed_payload(
                scenario_name=candidate.scenario_id,
                expected_end_state=scenario_payload["expected_end_state"],
                source_match_id=artifacts.match_id,
                source_turn_number=turn_number,
                tracked_player_index=candidate.tracked_player_index,
                scenario_path=scenario_path,
                output_root=output_root,
            ),
        )
        generated.append(
            {
                "scenario_id": candidate.scenario_id,
                "scenario_path": str(scenario_path),
                "review_seed_path": str(review_path),
                "match_id": artifacts.match_id,
                "turn_number": turn_number,
                "tracked_player_index": candidate.tracked_player_index,
            }
        )

    if not generated:
        warnings.append(
            {
                "match_id": artifacts.match_id,
                "match_dir": str(artifacts.match_dir),
                "reason": "No turns produced deterministic scenario seeds",
            }
        )
    return {"generated": generated, "skipped": skipped, "warnings": warnings}


def _build_candidate_seed(
    *,
    artifacts: MatchArtifacts,
    turn_entry: dict[str, Any],
    turn_events: list[dict[str, Any]],
) -> ScenarioSeed | None:
    turn_number = _int(turn_entry.get("turn_number", 0))
    start_snapshot = _find_turn_start_snapshot(turn_events)
    if start_snapshot is None:
        return None
    end_snapshot = _find_turn_end_snapshot(artifacts.detail_events, turn_number)
    if end_snapshot is None:
        return None
    if not _is_interesting_turn(turn_entry, turn_events):
        return None

    tracked_player_index = _infer_tracked_player_index(turn_entry, turn_events, start_snapshot, end_snapshot)
    if tracked_player_index < 0:
        return None
    deck_id = _deck_id_for_player(artifacts.match_data, tracked_player_index)
    scenario_name = scenario_id(artifacts.match_id, turn_number, tracked_player_index)
    selection_reasons = _selection_reasons(turn_entry, turn_events, start_snapshot, end_snapshot)
    tags = _build_tags(turn_number, turn_entry, turn_events)
    notes = (
        "Deterministic extraction seed from a marked human-vs-human match. "
        "This first batch preserves turn-start and turn-end snapshots for later end-state integration."
    )

    return ScenarioSeed(
        scenario_id=scenario_name,
        deck_id=deck_id,
        tracked_player_index=tracked_player_index,
        source_match_id=artifacts.match_id,
        source_turn_number=turn_number,
        tags=tuple(tags),
        notes=notes,
        state_at_turn_start=_snapshot_state_payload(start_snapshot),
        expected_end_state_source=_snapshot_descriptor(end_snapshot),
        extraction_metadata={
            "extractor": EXTRACTOR_NAME,
            "extractor_version": EXTRACTOR_VERSION,
            "match_dir": str(artifacts.match_dir),
            "learning_request_status": str(artifacts.learning_request.get("status", "")),
            "selection_reasons": selection_reasons,
            "turn_start_event_index": _int(start_snapshot.get("event_index", -1)),
            "turn_end_event_index": _int(end_snapshot.get("event_index", -1)),
            "source_artifacts": {
                "match_json": "match.json",
                "turns_json": "turns.json",
                "detail_jsonl": "detail.jsonl",
                "learning_request_json": str(LEARNING_REQUEST_RELATIVE_PATH).replace("\\", "/"),
            },
        },
        runtime_oracles=_build_runtime_oracles(turn_events, tracked_player_index),
    )


def _build_runtime_oracles(turn_events: list[dict[str, Any]], tracked_player_index: int) -> dict[str, Any]:
    overrides: list[dict[str, Any]] = []
    for index, event in enumerate(turn_events):
        if str(event.get("event_type", "")) != "action_resolved":
            continue
        if _int(event.get("player_index", -1)) != tracked_player_index:
            continue
        if _int(event.get("action_type", -1)) != 12:
            continue
        card_name = str((event.get("data", {}) or {}).get("card_name", "")).strip()
        if card_name not in HIDDEN_ZONE_ORACLE_TRAINERS:
            continue
        snapshot = _find_next_after_action_snapshot(turn_events, index + 1)
        if snapshot is None:
            continue
        players = _hidden_zone_override_players(snapshot)
        if not players:
            continue
        overrides.append(
            {
                "trigger": {
                    "action_type": 12,
                    "player_index": tracked_player_index,
                    "card_name": card_name,
                    "event_index": _int(event.get("event_index", -1)),
                },
                "players": players,
                "source_snapshot_event_index": _int(snapshot.get("event_index", -1)),
            }
        )
    return {"hidden_zone_overrides": overrides}


def _find_next_after_action_snapshot(turn_events: list[dict[str, Any]], start_index: int) -> dict[str, Any] | None:
    for event in turn_events[start_index:]:
        if str(event.get("event_type", "")) != "state_snapshot":
            continue
        if str(event.get("snapshot_reason", "")) != "after_action_resolved":
            continue
        return event
    return None


def _hidden_zone_override_players(snapshot_event: dict[str, Any]) -> list[dict[str, Any]]:
    state = snapshot_event.get("state", {})
    players = state.get("players", [])
    if not isinstance(players, list):
        return []
    overrides: list[dict[str, Any]] = []
    for player_variant in players:
        if not isinstance(player_variant, dict):
            continue
        overrides.append(
            {
                "player_index": _int(player_variant.get("player_index", -1)),
                "hand": player_variant.get("hand", []) if isinstance(player_variant.get("hand", []), list) else [],
                "deck": player_variant.get("deck", []) if isinstance(player_variant.get("deck", []), list) else [],
                "shuffle_count": _int(player_variant.get("shuffle_count", 0)),
            }
        )
    return overrides


def _group_events_by_turn(detail_events: list[dict[str, Any]]) -> dict[int, list[dict[str, Any]]]:
    grouped: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for event in detail_events:
        turn_number = _int(event.get("turn_number", 0))
        if turn_number > 0:
            grouped[turn_number].append(event)
    return grouped


def _find_turn_start_snapshot(turn_events: list[dict[str, Any]]) -> dict[str, Any] | None:
    for event in turn_events:
        if str(event.get("event_type", "")) != "state_snapshot":
            continue
        if str(event.get("snapshot_reason", "")) == "turn_start":
            return event
    return None


def _find_turn_end_snapshot(detail_events: list[dict[str, Any]], turn_number: int) -> dict[str, Any] | None:
    latest_in_turn: dict[str, Any] | None = None
    for event in detail_events:
        if str(event.get("event_type", "")) != "state_snapshot":
            continue
        event_turn = _int(event.get("turn_number", 0))
        if event_turn == turn_number:
            latest_in_turn = event
    if latest_in_turn is not None:
        return latest_in_turn
    for event in detail_events:
        if str(event.get("event_type", "")) != "state_snapshot":
            continue
        if _int(event.get("turn_number", 0)) > turn_number:
            return event
    return None


def _is_interesting_turn(turn_entry: dict[str, Any], turn_events: list[dict[str, Any]]) -> bool:
    key_actions = turn_entry.get("key_actions", [])
    if isinstance(key_actions, list) and key_actions:
        return True
    key_choices = turn_entry.get("key_choices", [])
    if isinstance(key_choices, list) and key_choices:
        return True
    for event in turn_events:
        event_type = str(event.get("event_type", ""))
        if event_type in {"action_resolved", "action_selected", "choice_context"}:
            return True
    return False


def _infer_tracked_player_index(
    turn_entry: dict[str, Any],
    turn_events: list[dict[str, Any]],
    start_snapshot: dict[str, Any],
    end_snapshot: dict[str, Any],
) -> int:
    for source in [turn_events, [start_snapshot], [end_snapshot], turn_entry.get("key_actions", []), turn_entry.get("key_choices", [])]:
        if not isinstance(source, list):
            continue
        for item in source:
            if not isinstance(item, dict):
                continue
            player_index = _int(item.get("player_index", -1))
            if player_index >= 0:
                return player_index
    return -1


def _deck_id_for_player(match_data: dict[str, Any], tracked_player_index: int) -> int:
    deck_ids = match_data.get("meta", {}).get("selected_deck_ids", [])
    if not isinstance(deck_ids, list):
        return 0
    if tracked_player_index < 0 or tracked_player_index >= len(deck_ids):
        return 0
    return _int(deck_ids[tracked_player_index], 0)


def _selection_reasons(
    turn_entry: dict[str, Any],
    turn_events: list[dict[str, Any]],
    start_snapshot: dict[str, Any],
    end_snapshot: dict[str, Any],
) -> list[str]:
    reasons: list[str] = ["has_turn_start_snapshot", "has_turn_end_snapshot"]
    if isinstance(turn_entry.get("key_actions", []), list) and turn_entry.get("key_actions", []):
        reasons.append("has_key_actions")
    if isinstance(turn_entry.get("key_choices", []), list) and turn_entry.get("key_choices", []):
        reasons.append("has_key_choices")
    if any(str(event.get("event_type", "")) == "action_resolved" for event in turn_events):
        reasons.append("contains_action_resolved")
    if any(str(event.get("event_type", "")) == "choice_context" for event in turn_events):
        reasons.append("contains_choice_context")
    if str(start_snapshot.get("snapshot_reason", "")) == "turn_start":
        reasons.append("exact_turn_start_state_available")
    if _int(end_snapshot.get("turn_number", 0)) > _int(turn_entry.get("turn_number", 0)):
        reasons.append("used_following_snapshot_as_end_state_seed")
    return reasons


def _build_tags(turn_number: int, turn_entry: dict[str, Any], turn_events: list[dict[str, Any]]) -> list[str]:
    tags: list[str] = []
    if turn_number <= 4:
        tags.append("opening")
    if _has_phase(turn_entry, "attack"):
        tags.append("attack")
    if any(str(event.get("event_type", "")) in {"choice_context", "action_selected"} for event in turn_events):
        tags.append("choice")

    text_blob = " ".join(_event_text_fragments(turn_entry, turn_events)).lower()
    keyword_tags = [
        ("search", "search"),
        ("attach", "attach"),
        ("energy", "energy"),
        ("evolve", "evolve"),
        ("evolution", "evolve"),
        ("knockout", "knockout"),
        ("ultra ball", "search"),
        ("buddy-buddy poffin", "search"),
        ("tm evolution", "evolve"),
    ]
    for keyword, tag in keyword_tags:
        if keyword in text_blob and tag not in tags:
            tags.append(tag)
    if "attack" not in tags and any(str(event.get("phase", "")) == "attack" for event in turn_events):
        tags.append("attack")
    if "deterministic_seed" not in tags:
        tags.append("deterministic_seed")
    return tags


def _event_text_fragments(turn_entry: dict[str, Any], turn_events: list[dict[str, Any]]) -> list[str]:
    fragments: list[str] = []
    for key in ("key_actions", "key_choices"):
        values = turn_entry.get(key, [])
        if not isinstance(values, list):
            continue
        for value in values:
            if isinstance(value, dict):
                for subkey in ("description", "title", "prompt_type"):
                    text = str(value.get(subkey, "")).strip()
                    if text:
                        fragments.append(text)
    for event in turn_events:
        for key in ("description", "title", "prompt_type", "snapshot_reason"):
            text = str(event.get(key, "")).strip()
            if text:
                fragments.append(text)
    return fragments


def _has_phase(turn_entry: dict[str, Any], expected_phase: str) -> bool:
    phases = turn_entry.get("phase_sequence", [])
    if not isinstance(phases, list):
        return False
    return any(str(phase) == expected_phase for phase in phases)


def _snapshot_state_payload(snapshot_event: dict[str, Any]) -> dict[str, Any]:
    state = snapshot_event.get("state", {})
    return state if isinstance(state, dict) else {}


def _snapshot_descriptor(snapshot_event: dict[str, Any]) -> dict[str, Any]:
    return {
        "snapshot_event_index": _int(snapshot_event.get("event_index", -1)),
        "snapshot_reason": str(snapshot_event.get("snapshot_reason", "")),
        "turn_number": _int(snapshot_event.get("turn_number", 0)),
        "phase": str(snapshot_event.get("phase", "")),
        "state": _snapshot_state_payload(snapshot_event),
    }


def _read_json_file(path: Path) -> dict[str, Any]:
    try:
        parsed = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return parsed if isinstance(parsed, dict) else {}


def _read_jsonl_file(path: Path) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return events
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            parsed = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(parsed, dict):
            events.append(parsed)
    return events


def _int(value: Any, default: int = -1) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    report = extract_learning_pool_scenarios(args)
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
