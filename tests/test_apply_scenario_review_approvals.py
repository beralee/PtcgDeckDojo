from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_TOOLS_ROOT = REPO_ROOT / "scripts" / "tools"
SCENARIO_REVIEW_ROOT = SCRIPTS_TOOLS_ROOT / "scenario_review"
if str(SCRIPTS_TOOLS_ROOT) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_TOOLS_ROOT))
if str(SCENARIO_REVIEW_ROOT) not in sys.path:
    sys.path.insert(0, str(SCENARIO_REVIEW_ROOT))

import apply_approvals as approvals  # noqa: E402


class ApplyScenarioReviewApprovalsTests(unittest.TestCase):
    def test_applies_human_approved_request_without_mutating_review_payload(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            scenarios_root = tmp_path / "scenarios"
            scenario_path = scenarios_root / "deck_1" / "alpha.json"
            request_path = scenarios_root / "review_queue" / "pending" / "alpha_review.json"
            ai_end_state = self._make_end_state("alpha", ["Rare Candy"])

            self._write_scenario(scenario_path, scenario_id="alpha")
            self._write_review_request(
                request_path,
                review_request_id="alpha_review",
                scenario_id="alpha",
                scenario_path="deck_1/alpha.json",
                human_resolution="Equivalent",
                ai_end_state=ai_end_state,
            )
            original_request_text = request_path.read_text(encoding="utf-8")

            report = approvals.apply_scenario_review_approvals(
                approvals.parse_args(["--scenarios-dir", str(scenarios_root)])
            )

            updated_scenario = json.loads(scenario_path.read_text(encoding="utf-8"))
            alternatives = updated_scenario["approved_divergent_end_states"]
            self.assertEqual(report["summary"]["request_count"], 1)
            self.assertEqual(report["summary"]["applied_request_count"], 1)
            self.assertEqual(report["summary"]["updated_scenario_count"], 1)
            self.assertEqual(report["summary"]["skipped_request_count"], 0)
            self.assertEqual(len(alternatives), 1)
            self.assertEqual(alternatives[0]["alternative_id"], "alpha_review")
            self.assertEqual(alternatives[0]["resolution"], "equivalent")
            self.assertEqual(alternatives[0]["source_review_request_path"], "pending/alpha_review.json")
            self.assertEqual(alternatives[0]["end_state"], ai_end_state)
            self.assertEqual(request_path.read_text(encoding="utf-8"), original_request_text)

    def test_preserves_existing_order_and_skips_duplicate_end_states(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            scenarios_root = tmp_path / "scenarios"
            scenario_path = scenarios_root / "deck_1" / "alpha.json"
            existing_alt = {
                "alternative_id": "existing_alt",
                "end_state": self._make_end_state("alpha", ["Existing"]),
            }
            self._write_scenario(
                scenario_path,
                scenario_id="alpha",
                approved_divergent_end_states=[existing_alt],
            )

            first_state = self._make_end_state("alpha", ["A"])
            second_state = self._make_end_state("alpha", ["B"])
            self._write_review_request(
                scenarios_root / "review_queue" / "pending" / "b_second.json",
                review_request_id="b_review",
                scenario_id="alpha",
                scenario_path="deck_1/alpha.json",
                human_resolution="dominant",
                ai_end_state=second_state,
            )
            self._write_review_request(
                scenarios_root / "review_queue" / "pending" / "c_duplicate.json",
                review_request_id="dup_review",
                scenario_id="alpha",
                scenario_path="deck_1/alpha.json",
                human_resolution="equivalent",
                ai_end_state=second_state,
            )
            self._write_review_request(
                scenarios_root / "review_queue" / "pending" / "a_first.json",
                review_request_id="a_review",
                scenario_id="alpha",
                scenario_path="deck_1/alpha.json",
                human_resolution="equivalent",
                ai_end_state=first_state,
            )

            report = approvals.apply_scenario_review_approvals(
                approvals.parse_args(["--scenarios-dir", str(scenarios_root)])
            )

            updated_scenario = json.loads(scenario_path.read_text(encoding="utf-8"))
            alternative_ids = [
                alternative["alternative_id"]
                for alternative in updated_scenario["approved_divergent_end_states"]
            ]
            self.assertEqual(alternative_ids, ["existing_alt", "a_review", "b_review"])
            self.assertEqual(report["summary"]["applied_request_count"], 2)
            self.assertEqual(report["summary"]["updated_scenario_count"], 1)
            self.assertEqual(report["summary"]["skipped_request_count"], 1)
            self.assertEqual(
                {entry["reason"] for entry in report["skipped_requests"]},
                {"duplicate_approved_end_state"},
            )

    def test_skips_unapproved_unhydrated_and_non_scenario_targets(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            scenarios_root = tmp_path / "scenarios"
            scenario_path = scenarios_root / "deck_1" / "alpha.json"
            manifest_path = scenarios_root / "manifest.json"
            manifest_payload = {"matches": []}

            self._write_scenario(scenario_path, scenario_id="alpha")
            self._write_json(manifest_path, manifest_payload)
            original_manifest_text = manifest_path.read_text(encoding="utf-8")

            self._write_review_request(
                scenarios_root / "review_queue" / "pending" / "reject.json",
                review_request_id="reject_review",
                scenario_id="alpha",
                scenario_path="deck_1/alpha.json",
                human_resolution="reject",
                ai_end_state=self._make_end_state("alpha", ["Rejected"]),
            )
            self._write_review_request(
                scenarios_root / "review_queue" / "pending" / "unhydrated.json",
                review_request_id="unhydrated_review",
                scenario_id="alpha",
                scenario_path="deck_1/alpha.json",
                human_resolution="equivalent",
                ai_end_state={},
                runner_verdict={},
                diff=[],
            )
            self._write_review_request(
                scenarios_root / "review_queue" / "pending" / "manifest_target.json",
                review_request_id="manifest_review",
                scenario_id="alpha",
                scenario_path="manifest.json",
                human_resolution="dominant",
                ai_end_state=self._make_end_state("alpha", ["Manifest"]),
            )

            report = approvals.apply_scenario_review_approvals(
                approvals.parse_args(["--scenarios-dir", str(scenarios_root)])
            )

            updated_scenario = json.loads(scenario_path.read_text(encoding="utf-8"))
            self.assertEqual(report["summary"]["request_count"], 3)
            self.assertEqual(report["summary"]["applied_request_count"], 0)
            self.assertEqual(report["summary"]["updated_scenario_count"], 0)
            self.assertEqual(report["summary"]["skipped_request_count"], 3)
            self.assertEqual(updated_scenario["approved_divergent_end_states"], [])
            self.assertEqual(manifest_path.read_text(encoding="utf-8"), original_manifest_text)
            self.assertEqual(
                {entry["reason"] for entry in report["skipped_requests"]},
                {
                    "human_resolution_not_approved",
                    "request_not_hydrated",
                    "non_scenario_target",
                },
            )

    def _write_scenario(
        self,
        path: Path,
        *,
        scenario_id: str,
        approved_divergent_end_states: list[dict] | None = None,
    ) -> None:
        self._write_json(
            path,
            {
                "scenario_id": scenario_id,
                "schema_version": 1,
                "deck_id": 1,
                "tracked_player_index": 0,
                "source_match_id": "match_alpha",
                "source_turn_number": 3,
                "tags": ["deterministic_seed"],
                "notes": "Test scenario fixture.",
                "state_at_turn_start": {
                    "turn_number": 3,
                    "current_player_index": 0,
                },
                "expected_end_state": {
                    "primary": {},
                    "secondary": {},
                },
                "approved_divergent_end_states": approved_divergent_end_states or [],
            },
        )

    def _write_review_request(
        self,
        path: Path,
        *,
        review_request_id: str,
        scenario_id: str,
        scenario_path: str,
        human_resolution: str,
        ai_end_state: dict,
        runner_verdict: dict | None = None,
        diff: list | None = None,
    ) -> None:
        self._write_json(
            path,
            {
                "review_request_id": review_request_id,
                "scenario_id": scenario_id,
                "status": "pending_review",
                "scenario_path": scenario_path,
                "expected_end_state": {
                    "primary": {},
                    "secondary": {},
                },
                "ai_end_state": ai_end_state,
                "diff": [] if diff is None else diff,
                "llm_suggestion": {
                    "resolution": human_resolution,
                    "confidence": 0.91,
                    "reason": "Test fixture",
                },
                "human_resolution": human_resolution,
                "runner_verdict": {"status": "DIVERGE"} if runner_verdict is None else runner_verdict,
            },
        )

    def _make_end_state(self, scenario_id: str, hand: list[str]) -> dict:
        return {
            "scenario_id": scenario_id,
            "primary": {
                "tracked_player": {
                    "active": {},
                    "bench": [],
                    "hand": hand,
                    "prize_count": 4,
                },
                "opponent": {
                    "active": {},
                    "bench": [],
                    "hand": [],
                    "prize_count": 4,
                },
            },
            "secondary": {
                "tracked_player": {
                    "total_remaining_hp": 90,
                    "total_energy": 1,
                    "discard_card_names": [],
                },
                "opponent": {
                    "total_remaining_hp": 120,
                    "total_energy": 1,
                    "discard_card_names": [],
                },
            },
        }

    def _write_json(self, path: Path, payload: dict) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    unittest.main()
