from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DECK_CASE_SUITES: dict[int, dict[str, Any]] = {
    575720: {
        "deck_key": "miraidon",
        "deck_name": "密勒顿",
        "fixed_gates": [
            {
                "type": "gdscript_test",
                "path": "res://tests/test_miraidon_fast_setup_t1.gd",
                "tests": [
                    "test_going_second_t1_lightning_attacker_has_at_least_2_energy",
                    "test_going_second_t1_lightning_attacker_multi_seed",
                ],
            },
        ],
    },
    578647: {
        "deck_key": "gardevoir",
        "deck_name": "沙奈朵",
        "fixed_gates": [
            {
                "type": "gdscript_test",
                "path": "res://tests/test_gardevoir_fast_evolution_t1.gd",
                "tests": [
                    "test_going_second_t1_achieves_two_kirlia_via_tm_evolution",
                    "test_going_second_t1_achieves_two_kirlia_multi_seed",
                ],
            },
        ],
    },
    569061: {
        "deck_key": "arceus_giratina",
        "deck_name": "阿尔宙斯骑拉帝纳",
        "fixed_gates": [
            {
                "type": "gdscript_test",
                "path": "res://tests/test_arceus_fast_setup_t1.gd",
                "tests": [
                    "test_going_second_t2_arceus_vstar_evolved",
                    "test_going_second_t2_arceus_vstar_multi_seed",
                ],
            },
            {
                "type": "gdscript_test",
                "path": "res://tests/test_ai_strong_fixed_openings.gd",
                "tests": [
                    "test_arceus_strong_fixed_order_hits_t2_trinity_nova_distribution",
                ],
            },
        ],
    },
    575716: {
        "deck_key": "charizard_ex",
        "deck_name": "喷火龙大比鸟",
        "fixed_gates": [
            {
                "type": "gdscript_test",
                "path": "res://tests/test_ai_strong_fixed_openings.gd",
                "tests": [
                    "test_charizard_strong_fixed_order_hits_t2_charizard_and_pidgeot_board",
                ],
            },
        ],
    },
}


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build per-deck case suite manifests from unified learning outputs and fixed-opening gates.",
    )
    parser.add_argument("--scenarios-dir", required=True)
    parser.add_argument("--review-queue-dir", required=True)
    parser.add_argument("--output-dir", required=True)
    return parser.parse_args(argv)


def build_deck_case_suites(args: argparse.Namespace) -> dict[str, Any]:
    scenarios_dir = Path(args.scenarios_dir).resolve()
    review_queue_dir = Path(args.review_queue_dir).resolve()
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    suites: list[dict[str, Any]] = []
    pending_dir = review_queue_dir / "pending"
    requests = list(sorted(pending_dir.glob("*.json")))

    by_deck: dict[int, list[dict[str, Any]]] = {}
    for request_path in requests:
        request = json.loads(request_path.read_text(encoding="utf-8"))
        scenario_path = str(request.get("scenario_path", "")).replace("\\", "/")
        deck_id = _deck_id_from_scenario_path(scenario_path)
        if deck_id is None or deck_id not in DECK_CASE_SUITES:
            continue
        llm_suggestion = request.get("llm_suggestion", {}) if isinstance(request.get("llm_suggestion", {}), dict) else {}
        entry = {
            "review_request_id": str(request.get("review_request_id", "")),
            "scenario_path": scenario_path,
            "request_path": str(request_path.resolve()),
            "runner_status": str((request.get("runner_verdict", {}) or {}).get("status", "")),
            "llm_resolution": str(llm_suggestion.get("resolution", "")),
            "human_resolution": str(request.get("human_resolution", "")),
        }
        by_deck.setdefault(deck_id, []).append(entry)

    for deck_id, meta in DECK_CASE_SUITES.items():
        deck_entries = by_deck.get(deck_id, [])
        resolution_counts: dict[str, int] = {}
        approved_requests: list[str] = []
        needs_review_requests: list[str] = []
        worse_requests: list[str] = []
        for entry in deck_entries:
            resolution = entry["human_resolution"] or entry["llm_resolution"]
            if resolution == "":
                resolution = "unreviewed"
            resolution_counts[resolution] = resolution_counts.get(resolution, 0) + 1
            if resolution in {"equivalent", "dominant"}:
                approved_requests.append(entry["review_request_id"])
            elif resolution == "needs_review":
                needs_review_requests.append(entry["review_request_id"])
            elif resolution == "worse":
                worse_requests.append(entry["review_request_id"])

        manifest = {
            "suite_version": 1,
            "deck_id": deck_id,
            "deck_key": meta["deck_key"],
            "deck_name": meta["deck_name"],
            "scenarios_dir": str((scenarios_dir / f"deck_{deck_id}").resolve()),
            "fixed_gates": meta["fixed_gates"],
            "live_cases": {
                "total": len(deck_entries),
                "resolution_counts": resolution_counts,
                "approved_request_ids": approved_requests,
                "needs_review_request_ids": needs_review_requests,
                "worse_request_ids": worse_requests,
                "entries": deck_entries,
            },
        }
        output_path = output_dir / f"{meta['deck_key']}.json"
        output_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        suites.append(
            {
                "deck_id": deck_id,
                "deck_key": meta["deck_key"],
                "output_path": str(output_path.resolve()),
                "live_case_count": len(deck_entries),
                "approved_count": len(approved_requests),
            }
        )

    summary = {
        "builder": "deck_case_suite_builder",
        "builder_version": 1,
        "scenarios_dir": str(scenarios_dir),
        "review_queue_dir": str(review_queue_dir),
        "output_dir": str(output_dir),
        "suite_count": len(suites),
        "suites": suites,
    }
    return summary


def _deck_id_from_scenario_path(scenario_path: str) -> int | None:
    if "deck_" not in scenario_path:
        return None
    marker = scenario_path.split("deck_", 1)[1]
    digits = []
    for ch in marker:
        if ch.isdigit():
            digits.append(ch)
        else:
            break
    if not digits:
        return None
    return int("".join(digits))


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    summary = build_deck_case_suites(args)
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
