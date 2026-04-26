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

import import_review_judgments as importer  # noqa: E402


class ImportScenarioReviewJudgmentsTests(unittest.TestCase):
    def test_imports_llm_suggestion_into_pending_request(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            scenarios_root = tmp_path / "scenarios"
            request_path = scenarios_root / "review_queue" / "pending" / "alpha.json"
            judgments_path = tmp_path / "judgments.jsonl"

            self._write_request(request_path, review_request_id="alpha")
            judgments_path.write_text(
                json.dumps(
                    {
                        "review_request_id": "alpha",
                        "resolution": "equivalent",
                        "confidence": 0.91,
                        "reason": "Board delta is equivalent.",
                    },
                    ensure_ascii=False,
                )
                + "\n",
                encoding="utf-8",
            )

            report = importer.import_review_judgments(
                importer.parse_args(
                    [
                        "--scenarios-dir",
                        str(scenarios_root),
                        "--judgments-path",
                        str(judgments_path),
                    ]
                )
            )

            updated_request = json.loads(request_path.read_text(encoding="utf-8"))
            self.assertEqual(report["updated_count"], 1)
            self.assertEqual(updated_request["llm_suggestion"]["resolution"], "equivalent")
            self.assertEqual(updated_request["llm_suggestion"]["confidence"], 0.91)
            self.assertEqual(updated_request["llm_suggestion"]["reason"], "Board delta is equivalent.")
            self.assertEqual(updated_request["human_resolution"], "")

    def test_human_resolution_requires_explicit_flag(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            scenarios_root = tmp_path / "scenarios"
            request_path = scenarios_root / "review_queue" / "pending" / "alpha.json"
            judgments_path = tmp_path / "judgments.jsonl"

            self._write_request(request_path, review_request_id="alpha")
            judgments_path.write_text(
                json.dumps(
                    {
                        "review_request_id": "alpha",
                        "resolution": "dominant",
                        "confidence": 0.88,
                        "reason": "Strictly better.",
                        "human_resolution": "dominant",
                    },
                    ensure_ascii=False,
                )
                + "\n",
                encoding="utf-8",
            )

            report = importer.import_review_judgments(
                importer.parse_args(
                    [
                        "--scenarios-dir",
                        str(scenarios_root),
                        "--judgments-path",
                        str(judgments_path),
                    ]
                )
            )
            self.assertEqual(report["updated_count"], 0)
            self.assertEqual(report["skipped"][0]["reason"], "human_resolution_not_allowed")

            report_allowed = importer.import_review_judgments(
                importer.parse_args(
                    [
                        "--scenarios-dir",
                        str(scenarios_root),
                        "--judgments-path",
                        str(judgments_path),
                        "--allow-human-resolution",
                        "--overwrite-llm-suggestion",
                    ]
                )
            )
            updated_request = json.loads(request_path.read_text(encoding="utf-8"))
            self.assertEqual(report_allowed["updated_count"], 1)
            self.assertEqual(updated_request["human_resolution"], "dominant")

    def test_skips_missing_requests_and_existing_suggestions_without_overwrite(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            scenarios_root = tmp_path / "scenarios"
            request_path = scenarios_root / "review_queue" / "pending" / "alpha.json"
            judgments_path = tmp_path / "judgments.jsonl"

            self._write_request(
                request_path,
                review_request_id="alpha",
                llm_suggestion={
                    "resolution": "equivalent",
                    "confidence": 0.7,
                    "reason": "Existing",
                },
            )
            judgments_path.write_text(
                "\n".join(
                    [
                        json.dumps(
                            {
                                "review_request_id": "alpha",
                                "resolution": "dominant",
                                "confidence": 0.95,
                                "reason": "Overwrite attempt",
                            },
                            ensure_ascii=False,
                        ),
                        json.dumps(
                            {
                                "review_request_id": "missing",
                                "resolution": "equivalent",
                                "confidence": 0.6,
                                "reason": "Unknown request",
                            },
                            ensure_ascii=False,
                        ),
                    ]
                )
                + "\n",
                encoding="utf-8",
            )

            report = importer.import_review_judgments(
                importer.parse_args(
                    [
                        "--scenarios-dir",
                        str(scenarios_root),
                        "--judgments-path",
                        str(judgments_path),
                    ]
                )
            )

            self.assertEqual(report["updated_count"], 0)
            self.assertEqual(report["skipped_count"], 2)
            self.assertEqual(
                {entry["reason"] for entry in report["skipped"]},
                {"llm_suggestion_already_present", "review_request_not_found"},
            )

    def _write_request(
        self,
        path: Path,
        *,
        review_request_id: str,
        llm_suggestion: dict | None = None,
    ) -> None:
        payload = {
            "review_request_id": review_request_id,
            "scenario_id": review_request_id,
            "status": "pending_review",
            "scenario_path": f"deck_1/{review_request_id}.json",
            "expected_end_state": {"primary": {}, "secondary": {}},
            "ai_end_state": {"scenario_id": review_request_id, "primary": {}, "secondary": {}},
            "diff": [{"kind": "hand_mismatch", "path": "primary.tracked_player.hand"}],
            "runner_verdict": {"status": "FAIL", "reason": "needs review"},
            "llm_suggestion": llm_suggestion or {"resolution": "", "confidence": 0.0, "reason": ""},
            "human_resolution": "",
        }
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    unittest.main()
