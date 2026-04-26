from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_TOOLS_ROOT = REPO_ROOT / "scripts" / "tools"
if str(SCRIPTS_TOOLS_ROOT) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_TOOLS_ROOT))

import run_unified_learning  # noqa: E402


class RunUnifiedLearningTests(unittest.TestCase):
    def test_run_unified_learning_builds_expected_stage_sequence(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)

            def fake_run(stage_name: str, command: list[str], cwd: Path) -> dict:
                return {
                    "stage": stage_name,
                    "command": command,
                    "returncode": 0,
                    "stdout": {"ok": True},
                    "stderr": "",
                }

            with mock.patch.object(run_unified_learning, "_run_json_command", side_effect=fake_run), mock.patch.object(
                run_unified_learning, "resolve_godot_bin", return_value="godot-bin"
            ):
                summary = run_unified_learning.run_unified_learning(
                    run_unified_learning.parse_args(
                        [
                            "--user-root",
                            str(tmp_path),
                            "--work-dir",
                            str(tmp_path / "work"),
                            "--run-llm-judge",
                            "--import-judgments",
                        ]
                    )
                )

            stage_names = [stage["stage"] for stage in summary["stages"]]
            self.assertEqual(
                stage_names,
                [
                    "extract",
                    "populate_expected",
                    "build_review_queue",
                    "hydrate_review_queue",
                    "export_review_packets",
                    "llm_judge",
                    "import_judgments",
                ],
            )
            self.assertTrue(summary["work_root"].endswith("work"))
            llm_stage = next(stage for stage in summary["stages"] if stage["stage"] == "llm_judge")
            self.assertNotIn("--user-root", llm_stage["command"])


if __name__ == "__main__":
    unittest.main()
