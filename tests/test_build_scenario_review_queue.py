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

import build_scenario_review_queue as builder  # noqa: E402


class BuildScenarioReviewQueueTests(unittest.TestCase):
    def test_builds_pending_review_requests_from_scenario_jsons_only(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            scenarios_root = tmp_path / "scenarios"
            output_root = tmp_path / "review_payloads"
            self._write_scenario(
                scenarios_root / "deck_569061" / "match_alpha_turn2_p1.json",
                scenario_id="match_alpha_turn2_p1",
                deck_id=569061,
                tracked_player_index=1,
                source_match_id="match_alpha",
                source_turn_number=2,
            )
            self._write_scenario(
                scenarios_root / "deck_578647" / "match_beta_turn3_p0.json",
                scenario_id="match_beta_turn3_p0",
                deck_id=578647,
                tracked_player_index=0,
                source_match_id="match_beta",
                source_turn_number=3,
            )
            self._write_json(
                scenarios_root / "review_queue" / "pending" / "ignored_review_seed.json",
                {
                    "review_request_id": "ignored_review_seed",
                    "scenario_path": "deck_569061/example.json",
                    "notes": "Bookkeeping fixture should be ignored as input.",
                },
            )
            self._write_json(
                scenarios_root / "manifest.json",
                {
                    "matches": [],
                },
            )

            args = builder.parse_args(
                [
                    "--scenarios-dir",
                    str(scenarios_root),
                    "--output-dir",
                    str(output_root),
                ]
            )
            report = builder.build_scenario_review_queue(args)

            self.assertEqual(report["summary"]["source_json_count"], 3)
            self.assertEqual(report["summary"]["generated_request_count"], 2)
            self.assertEqual(report["summary"]["skipped_file_count"], 1)
            self.assertEqual(
                [entry["scenario_id"] for entry in report["generated_requests"]],
                ["match_alpha_turn2_p1", "match_beta_turn3_p0"],
            )

            pending_dir = output_root / "pending"
            generated_files = sorted(path.name for path in pending_dir.glob("*.json"))
            self.assertEqual(
                generated_files,
                ["match_alpha_turn2_p1.json", "match_beta_turn3_p0.json"],
            )
            self.assertFalse((output_root / "deck_569061").exists())

            alpha_request = json.loads((pending_dir / "match_alpha_turn2_p1.json").read_text(encoding="utf-8"))
            self.assertEqual(alpha_request["review_request_id"], "match_alpha_turn2_p1")
            self.assertEqual(alpha_request["scenario_id"], "match_alpha_turn2_p1")
            self.assertEqual(alpha_request["scenario_path"], "deck_569061/match_alpha_turn2_p1.json")
            self.assertEqual(
                alpha_request["seed_metadata"]["scenario_path"],
                "deck_569061/match_alpha_turn2_p1.json",
            )
            self.assertEqual(alpha_request["seed_metadata"]["source_match_id"], "match_alpha")
            self.assertEqual(alpha_request["seed_metadata"]["source_turn_number"], 2)
            self.assertEqual(alpha_request["seed_metadata"]["tracked_player_index"], 1)
            self.assertEqual(alpha_request["status"], "pending_review")
            self.assertEqual(alpha_request["expected_end_state"]["primary"]["turn_number"], 2)

            skipped_reasons = {entry["reason"] for entry in report["skipped_files"]}
            self.assertEqual(skipped_reasons, {"non_scenario_json"})

    def test_second_run_skips_existing_requests_and_ignores_generated_review_queue_input(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            scenarios_root = tmp_path / "scenarios"
            scenario_path = scenarios_root / "deck_578647" / "match_beta_turn3_p0.json"
            self._write_scenario(
                scenario_path,
                scenario_id="match_beta_turn3_p0",
                deck_id=578647,
                tracked_player_index=0,
                source_match_id="match_beta",
                source_turn_number=3,
            )

            first_args = builder.parse_args(["--scenarios-dir", str(scenarios_root)])
            first_report = builder.build_scenario_review_queue(first_args)
            self.assertEqual(first_report["summary"]["generated_request_count"], 1)

            second_args = builder.parse_args(["--scenarios-dir", str(scenarios_root)])
            second_report = builder.build_scenario_review_queue(second_args)

            self.assertEqual(second_report["summary"]["source_json_count"], 1)
            self.assertEqual(second_report["summary"]["generated_request_count"], 0)
            self.assertEqual(second_report["summary"]["skipped_file_count"], 1)
            self.assertEqual(second_report["skipped_files"][0]["reason"], "review_request_exists")

            pending_path = scenarios_root / "review_queue" / "pending" / "match_beta_turn3_p0.json"
            self.assertTrue(pending_path.exists())
            request_payload = json.loads(pending_path.read_text(encoding="utf-8"))
            self.assertEqual(request_payload["scenario_path"], "deck_578647/match_beta_turn3_p0.json")

    def _write_scenario(
        self,
        path: Path,
        *,
        scenario_id: str,
        deck_id: int,
        tracked_player_index: int,
        source_match_id: str,
        source_turn_number: int,
    ) -> None:
        self._write_json(
            path,
            {
                "scenario_id": scenario_id,
                "schema_version": 1,
                "deck_id": deck_id,
                "tracked_player_index": tracked_player_index,
                "source_match_id": source_match_id,
                "source_turn_number": source_turn_number,
                "tags": ["deterministic_seed"],
                "notes": "Test scenario fixture.",
                "state_at_turn_start": {
                    "turn_number": source_turn_number,
                    "current_player_index": tracked_player_index,
                },
                "expected_end_state": {
                    "primary": {
                        "turn_number": source_turn_number,
                    },
                    "secondary": {},
                },
                "approved_divergent_end_states": [],
            },
        )

    def _write_json(self, path: Path, payload: dict) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    unittest.main()
