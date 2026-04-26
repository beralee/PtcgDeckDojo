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

import export_review_packets as exporter  # noqa: E402


class ExportScenarioReviewPacketsTests(unittest.TestCase):
    def test_exports_only_hydrated_unresolved_fail_and_diverge_requests(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            scenarios_root = tmp_path / "scenarios"
            review_pending = scenarios_root / "review_queue" / "pending"
            output_root = tmp_path / "review_packets"

            self._write_request(
                review_pending / "fail_request.json",
                review_request_id="fail_request",
                runner_status="FAIL",
            )
            self._write_request(
                review_pending / "diverge_request.json",
                review_request_id="diverge_request",
                runner_status="DIVERGE",
            )
            self._write_request(
                review_pending / "pass_request.json",
                review_request_id="pass_request",
                runner_status="PASS",
            )
            self._write_request(
                review_pending / "resolved_request.json",
                review_request_id="resolved_request",
                runner_status="FAIL",
                human_resolution="equivalent",
            )
            self._write_json(review_pending / "invalid.json", {"foo": "bar"})

            manifest = exporter.export_review_packets(
                exporter.parse_args(
                    [
                        "--scenarios-dir",
                        str(scenarios_root),
                        "--output-dir",
                        str(output_root),
                    ]
                )
            )

            packets_path = output_root / "packets.jsonl"
            rows = [json.loads(line) for line in packets_path.read_text(encoding="utf-8").splitlines() if line.strip()]
            self.assertEqual(manifest["packet_count"], 2)
            self.assertEqual(manifest["status_counts"], {"DIVERGE": 1, "FAIL": 1})
            self.assertEqual(
                [row["review_request_id"] for row in rows],
                ["diverge_request", "fail_request"],
            )
            self.assertEqual(
                {entry["reason"] for entry in manifest["skipped_requests"]},
                {
                    "runner_status_filtered_out",
                    "already_human_resolved",
                    "request_not_hydrated",
                },
            )

    def test_include_resolved_and_custom_status_filter(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            scenarios_root = tmp_path / "scenarios"
            review_pending = scenarios_root / "review_queue" / "pending"
            output_root = tmp_path / "review_packets"

            self._write_request(
                review_pending / "resolved_diverge.json",
                review_request_id="resolved_diverge",
                runner_status="DIVERGE",
                human_resolution="dominant",
            )
            self._write_request(
                review_pending / "fail_request.json",
                review_request_id="fail_request",
                runner_status="FAIL",
            )

            manifest = exporter.export_review_packets(
                exporter.parse_args(
                    [
                        "--scenarios-dir",
                        str(scenarios_root),
                        "--output-dir",
                        str(output_root),
                        "--status",
                        "DIVERGE",
                        "--include-resolved",
                    ]
                )
            )

            packets_path = output_root / "packets.jsonl"
            rows = [json.loads(line) for line in packets_path.read_text(encoding="utf-8").splitlines() if line.strip()]
            self.assertEqual(manifest["packet_count"], 1)
            self.assertEqual(rows[0]["review_request_id"], "resolved_diverge")
            self.assertEqual(rows[0]["human_resolution"], "dominant")
            self.assertEqual(manifest["included_statuses"], ["DIVERGE"])

    def _write_request(
        self,
        path: Path,
        *,
        review_request_id: str,
        runner_status: str,
        human_resolution: str = "",
    ) -> None:
        self._write_json(
            path,
            {
                "review_request_id": review_request_id,
                "scenario_id": review_request_id,
                "status": "pending_review",
                "scenario_path": f"deck_1/{review_request_id}.json",
                "expected_end_state": {"primary": {}, "secondary": {}},
                "ai_end_state": {
                    "scenario_id": review_request_id,
                    "primary": {"tracked_player": {"hand": ["A"]}, "opponent": {"hand": []}},
                    "secondary": {},
                },
                "diff": [{"path": "primary.tracked_player.hand", "kind": "hand_mismatch"}],
                "llm_suggestion": {"resolution": "", "confidence": 0.0, "reason": ""},
                "human_resolution": human_resolution,
                "runner_verdict": {
                    "status": runner_status,
                    "reason": f"{runner_status.lower()} reason",
                    "runtime_mode": "rules_only",
                },
                "seed_metadata": {"source_match_id": "match_alpha", "source_turn_number": 3},
            },
        )

    def _write_json(self, path: Path, payload: dict) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    unittest.main()
