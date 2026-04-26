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

import build_deck_case_suites  # noqa: E402


class BuildDeckCaseSuitesTests(unittest.TestCase):
    def test_builds_per_deck_manifests_with_fixed_gates_and_reviewed_counts(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            scenarios_dir = root / "scenarios"
            review_queue_dir = root / "review_queue"
            output_dir = root / "deck_case_suites"
            (scenarios_dir / "deck_575720").mkdir(parents=True)
            (scenarios_dir / "deck_578647").mkdir(parents=True)
            pending_dir = review_queue_dir / "pending"
            pending_dir.mkdir(parents=True)

            packets = [
                {
                    "review_request_id": "miraidon_alpha",
                    "scenario_path": "deck_575720/miraidon_alpha.json",
                    "llm_suggestion": {"resolution": "worse"},
                    "human_resolution": "worse",
                    "runner_verdict": {"status": "FAIL"},
                },
                {
                    "review_request_id": "miraidon_beta",
                    "scenario_path": "deck_575720/miraidon_beta.json",
                    "llm_suggestion": {"resolution": "equivalent"},
                    "human_resolution": "equivalent",
                    "runner_verdict": {"status": "DIVERGE"},
                },
                {
                    "review_request_id": "gardevoir_alpha",
                    "scenario_path": "deck_578647/gardevoir_alpha.json",
                    "llm_suggestion": {"resolution": "needs_review"},
                    "human_resolution": "",
                    "runner_verdict": {"status": "FAIL"},
                },
            ]
            for payload in packets:
                request_path = pending_dir / f"{payload['review_request_id']}.json"
                request_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

            summary = build_deck_case_suites.build_deck_case_suites(
                build_deck_case_suites.parse_args(
                    [
                        "--scenarios-dir",
                        str(scenarios_dir),
                        "--review-queue-dir",
                        str(review_queue_dir),
                        "--output-dir",
                        str(output_dir),
                    ]
                )
            )

            self.assertEqual(summary["suite_count"], 4)
            miraidon_manifest = json.loads((output_dir / "miraidon.json").read_text(encoding="utf-8"))
            self.assertEqual(miraidon_manifest["live_cases"]["total"], 2)
            self.assertEqual(miraidon_manifest["live_cases"]["resolution_counts"]["worse"], 1)
            self.assertEqual(miraidon_manifest["live_cases"]["resolution_counts"]["equivalent"], 1)
            self.assertEqual(miraidon_manifest["live_cases"]["approved_request_ids"], ["miraidon_beta"])
            self.assertTrue(miraidon_manifest["fixed_gates"])

            gardevoir_manifest = json.loads((output_dir / "gardevoir.json").read_text(encoding="utf-8"))
            self.assertEqual(gardevoir_manifest["live_cases"]["total"], 1)
            self.assertEqual(gardevoir_manifest["live_cases"]["resolution_counts"]["needs_review"], 1)
            self.assertEqual(gardevoir_manifest["live_cases"]["needs_review_request_ids"], ["gardevoir_alpha"])


if __name__ == "__main__":
    unittest.main()
