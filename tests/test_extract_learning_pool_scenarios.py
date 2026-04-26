from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_TOOLS_ROOT = REPO_ROOT / "scripts" / "tools"
if str(SCRIPTS_TOOLS_ROOT) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_TOOLS_ROOT))

import extract_learning_pool_scenarios as extractor  # noqa: E402


class ExtractLearningPoolScenariosTests(unittest.TestCase):
    def test_extracts_marked_two_player_match_into_scenario_and_review_seed(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            match_records_root = tmp_path / "match_records"
            output_root = tmp_path / "scenarios"
            self._write_marked_match(
                match_records_root=match_records_root,
                match_id="match_alpha",
                mode="two_player",
            )

            args = extractor.parse_args(
                [
                    "--match-records-root",
                    str(match_records_root),
                    "--output-dir",
                    str(output_root),
                ]
            )
            report = extractor.extract_learning_pool_scenarios(args)

            self.assertEqual(report["summary"]["scenario_count"], 1)
            scenario_name = "match_alpha_turn3_p0"
            scenario_path = output_root / "deck_578647" / f"{scenario_name}.json"
            review_seed_path = output_root / "review_queue" / "pending" / f"{scenario_name}.json"
            self.assertTrue(scenario_path.exists())
            self.assertTrue(review_seed_path.exists())

            scenario_payload = json.loads(scenario_path.read_text(encoding="utf-8"))
            self.assertEqual(scenario_payload["scenario_id"], scenario_name)
            self.assertEqual(scenario_payload["tracked_player_index"], 0)
            self.assertEqual(scenario_payload["deck_id"], 578647)
            self.assertEqual(scenario_payload["expected_end_state"], {"primary": {}, "secondary": {}})
            self.assertEqual(scenario_payload["runtime_oracles"], {"hidden_zone_overrides": []})
            self.assertEqual(scenario_payload["state_at_turn_start"]["current_player_index"], 0)
            self.assertEqual(
                scenario_payload["expected_end_state_source"]["snapshot_reason"],
                "post_action",
            )
            self.assertIn("choice", scenario_payload["tags"])
            self.assertIn("search", scenario_payload["tags"])
            self.assertIn("deterministic_seed", scenario_payload["tags"])

            review_seed = json.loads(review_seed_path.read_text(encoding="utf-8"))
            self.assertEqual(review_seed["scenario_id"], scenario_name)
            self.assertEqual(review_seed["status"], "pending_review")
            self.assertEqual(
                review_seed["seed_metadata"]["scenario_path"],
                "deck_578647/match_alpha_turn3_p0.json",
            )

    def test_skips_unmarked_and_non_human_matches(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            match_records_root = tmp_path / "match_records"
            output_root = tmp_path / "scenarios"
            self._write_marked_match(
                match_records_root=match_records_root,
                match_id="match_ai",
                mode="vs_ai",
            )
            self._write_match_without_learning_marker(
                match_records_root=match_records_root,
                match_id="match_unmarked",
            )

            args = extractor.parse_args(
                [
                    "--match-records-root",
                    str(match_records_root),
                    "--output-dir",
                    str(output_root),
                ]
            )
            report = extractor.extract_learning_pool_scenarios(args)

            self.assertEqual(report["summary"]["scenario_count"], 0)
            self.assertEqual(report["summary"]["skipped_match_count"], 2)
            reasons = {entry["reason"] for entry in report["skipped_matches"]}
            self.assertIn("Unsupported match mode: vs_ai", reasons)
            self.assertIn("Missing learning/learning_request.json", reasons)

    def test_learning_pool_manifest_with_user_root_filters_matches(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            user_root = tmp_path / "godot_user"
            match_records_root = user_root / "match_records"
            output_root = tmp_path / "scenarios"
            self._write_marked_match(
                match_records_root=match_records_root,
                match_id="match_alpha",
                mode="local_human_vs_human",
            )
            self._write_marked_match(
                match_records_root=match_records_root,
                match_id="match_beta",
                mode="two_player",
            )
            manifest_path = tmp_path / "learning_pool.json"
            self._write_json(
                manifest_path,
                {
                    "schema_version": 1,
                    "matches": [
                        {
                            "match_id": "match_beta",
                            "source_dir": "user://match_records/match_beta",
                            "status": "pending_extraction",
                        }
                    ],
                },
            )

            args = extractor.parse_args(
                [
                    "--match-records-root",
                    "user://match_records",
                    "--learning-pool",
                    str(manifest_path),
                    "--user-root",
                    str(user_root),
                    "--output-dir",
                    str(output_root),
                ]
            )
            report = extractor.extract_learning_pool_scenarios(args)

            self.assertEqual(report["summary"]["scenario_count"], 1)
            self.assertTrue((output_root / "deck_578647" / "match_beta_turn3_p0.json").exists())
            self.assertFalse((output_root / "deck_578647" / "match_alpha_turn3_p0.json").exists())

    def test_extracts_hidden_zone_runtime_oracle_for_shuffle_draw_trainer(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            match_records_root = tmp_path / "match_records"
            output_root = tmp_path / "scenarios"
            self._write_marked_match_with_judge_oracle(
                match_records_root=match_records_root,
                match_id="match_judge",
            )

            args = extractor.parse_args(
                [
                    "--match-records-root",
                    str(match_records_root),
                    "--output-dir",
                    str(output_root),
                ]
            )
            report = extractor.extract_learning_pool_scenarios(args)

            self.assertEqual(report["summary"]["scenario_count"], 1)
            scenario_path = output_root / "deck_569061" / "match_judge_turn3_p1.json"
            scenario_payload = json.loads(scenario_path.read_text(encoding="utf-8"))
            overrides = scenario_payload["runtime_oracles"]["hidden_zone_overrides"]
            self.assertEqual(len(overrides), 1)
            self.assertEqual(overrides[0]["trigger"]["card_name"], "裁判")
            self.assertEqual(overrides[0]["trigger"]["action_type"], 12)
            self.assertEqual(overrides[0]["players"][1]["hand"][0]["card_name"], "骑拉帝纳V")
            self.assertEqual(overrides[0]["players"][1]["deck"][0]["card_name"], "基本草能量")

    def _write_marked_match(self, *, match_records_root: Path, match_id: str, mode: str) -> None:
        match_dir = match_records_root / match_id
        self._write_json(
            match_dir / "match.json",
            {
                "meta": {
                    "match_id": match_id,
                    "mode": mode,
                    "selected_deck_ids": [578647, 575720],
                    "player_labels": ["Alpha", "Beta"],
                    "first_player_index": 0,
                },
                "result": {
                    "winner_index": 0,
                    "reason": "prize_out",
                    "turn_count": 5,
                },
            },
        )
        self._write_json(
            match_dir / "turns.json",
            {
                "turns": [
                    {
                        "turn_number": 3,
                        "phase_sequence": ["main", "attack"],
                        "snapshot_reasons": ["turn_start", "post_action"],
                        "key_choices": [
                            {
                                "event_type": "action_selected",
                                "player_index": 0,
                                "prompt_type": "choose_card",
                                "title": "Ultra Ball",
                                "selected_labels": ["Pidgeot ex"],
                            }
                        ],
                        "key_actions": [
                            {
                                "event_type": "action_resolved",
                                "player_index": 0,
                                "description": "Player 0 searched with Ultra Ball",
                            }
                        ],
                        "event_count": 4,
                    }
                ]
            },
        )
        self._write_jsonl(
            match_dir / "detail.jsonl",
            [
                {
                    "event_index": 0,
                    "event_type": "state_snapshot",
                    "match_id": match_id,
                    "turn_number": 3,
                    "phase": "main",
                    "player_index": 0,
                    "snapshot_reason": "turn_start",
                    "state": {
                        "turn_number": 3,
                        "current_player_index": 0,
                        "players": [
                            {"player_index": 0, "hand_count": 4},
                            {"player_index": 1, "hand_count": 5},
                        ],
                    },
                },
                {
                    "event_index": 1,
                    "event_type": "choice_context",
                    "match_id": match_id,
                    "turn_number": 3,
                    "phase": "main",
                    "player_index": 0,
                    "prompt_type": "choose_card",
                    "title": "Ultra Ball",
                },
                {
                    "event_index": 2,
                    "event_type": "action_selected",
                    "match_id": match_id,
                    "turn_number": 3,
                    "phase": "main",
                    "player_index": 0,
                    "prompt_type": "choose_card",
                    "title": "Ultra Ball",
                    "selected_labels": ["Pidgeot ex"],
                },
                {
                    "event_index": 3,
                    "event_type": "action_resolved",
                    "match_id": match_id,
                    "turn_number": 3,
                    "phase": "attack",
                    "player_index": 0,
                    "description": "Player 0 searched with Ultra Ball",
                },
                {
                    "event_index": 4,
                    "event_type": "state_snapshot",
                    "match_id": match_id,
                    "turn_number": 3,
                    "phase": "attack",
                    "player_index": 0,
                    "snapshot_reason": "post_action",
                    "state": {
                        "turn_number": 3,
                        "current_player_index": 0,
                        "players": [
                            {"player_index": 0, "hand_count": 3},
                            {"player_index": 1, "hand_count": 5},
                        ],
                    },
                },
            ],
        )
        self._write_json(
            match_dir / "learning" / "learning_request.json",
            {
                "version": 1,
                "status": "marked",
                "both_players": True,
            },
        )

    def _write_marked_match_with_judge_oracle(self, *, match_records_root: Path, match_id: str) -> None:
        match_dir = match_records_root / match_id
        self._write_json(
            match_dir / "match.json",
            {
                "meta": {
                    "match_id": match_id,
                    "mode": "two_player",
                    "selected_deck_ids": [575720, 569061],
                    "player_labels": ["Miraidon", "Arceus"],
                    "first_player_index": 1,
                },
            },
        )
        self._write_json(
            match_dir / "turns.json",
            {
                "turns": [
                    {
                        "turn_number": 3,
                        "phase_sequence": ["main"],
                        "snapshot_reasons": ["turn_start", "after_action_resolved"],
                        "key_choices": [{"event_type": "choice_context", "player_index": 1, "prompt_type": "pokemon_action", "title": "Judge"}],
                        "key_actions": [{"event_type": "action_resolved", "player_index": 1, "description": "玩家2使用 裁判"}],
                        "event_count": 6,
                    }
                ]
            },
        )
        self._write_jsonl(
            match_dir / "detail.jsonl",
            [
                {
                    "event_index": 0,
                    "event_type": "state_snapshot",
                    "match_id": match_id,
                    "turn_number": 3,
                    "phase": "main",
                    "player_index": 1,
                    "snapshot_reason": "turn_start",
                    "state": {
                        "turn_number": 3,
                        "current_player_index": 1,
                        "players": [
                            {
                                "player_index": 0,
                                "hand": [{"card_name": "Peony"}],
                                "deck": [{"card_name": "Basic Lightning Energy"}],
                                "shuffle_count": 0,
                            },
                            {
                                "player_index": 1,
                                "hand": [{"card_name": "Judge"}],
                                "deck": [{"card_name": "Basic Grass Energy"}, {"card_name": "Maximum Belt"}],
                                "shuffle_count": 1,
                            },
                        ],
                    },
                },
                {
                    "event_index": 1,
                    "event_type": "action_resolved",
                    "match_id": match_id,
                    "turn_number": 3,
                    "phase": "main",
                    "player_index": 1,
                    "action_type": 12,
                    "data": {"card_name": "裁判"},
                    "description": "玩家2使用 裁判",
                },
                {
                    "event_index": 2,
                    "event_type": "state_snapshot",
                    "match_id": match_id,
                    "turn_number": 3,
                    "phase": "main",
                    "player_index": 1,
                    "snapshot_reason": "after_action_resolved",
                    "state": {
                        "turn_number": 3,
                        "current_player_index": 1,
                        "players": [
                            {
                                "player_index": 0,
                                "hand": [{"card_name": "Peony New"}],
                                "deck": [{"card_name": "Electric Generator"}],
                                "shuffle_count": 2,
                            },
                            {
                                "player_index": 1,
                                "hand": [{"card_name": "骑拉帝纳V"}, {"card_name": "基本草能量"}],
                                "deck": [{"card_name": "基本草能量"}, {"card_name": "极限腰带"}],
                                "shuffle_count": 3,
                            },
                        ],
                    },
                },
                {
                    "event_index": 3,
                    "event_type": "state_snapshot",
                    "match_id": match_id,
                    "turn_number": 3,
                    "phase": "main",
                    "player_index": 1,
                    "snapshot_reason": "after_action_resolved",
                    "state": {
                        "turn_number": 3,
                        "current_player_index": 1,
                        "players": [
                            {"player_index": 0, "hand": [{"card_name": "Peony New"}], "deck": [{"card_name": "Electric Generator"}], "shuffle_count": 2},
                            {"player_index": 1, "hand": [{"card_name": "骑拉帝纳V"}, {"card_name": "基本草能量"}], "deck": [{"card_name": "基本草能量"}, {"card_name": "极限腰带"}], "shuffle_count": 3},
                        ],
                    },
                },
            ],
        )
        self._write_json(
            match_dir / "learning" / "learning_request.json",
            {
                "version": 1,
                "status": "marked",
                "both_players": True,
            },
        )

    def _write_match_without_learning_marker(self, *, match_records_root: Path, match_id: str) -> None:
        match_dir = match_records_root / match_id
        self._write_json(
            match_dir / "match.json",
            {
                "meta": {
                    "match_id": match_id,
                    "mode": "two_player",
                    "selected_deck_ids": [578647, 575720],
                }
            },
        )
        self._write_json(match_dir / "turns.json", {"turns": []})
        self._write_jsonl(match_dir / "detail.jsonl", [])

    def _write_json(self, path: Path, payload: dict) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    def _write_jsonl(self, path: Path, payloads: list[dict]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            "\n".join(json.dumps(payload, ensure_ascii=False) for payload in payloads) + ("\n" if payloads else ""),
            encoding="utf-8",
        )


if __name__ == "__main__":
    unittest.main()
