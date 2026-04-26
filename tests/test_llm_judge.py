from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_TOOLS_ROOT = REPO_ROOT / "scripts" / "tools"
SCENARIO_REVIEW_ROOT = SCRIPTS_TOOLS_ROOT / "scenario_review"
if str(SCRIPTS_TOOLS_ROOT) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_TOOLS_ROOT))
if str(SCENARIO_REVIEW_ROOT) not in sys.path:
    sys.path.insert(0, str(SCENARIO_REVIEW_ROOT))

import llm_judge  # noqa: E402


class LlmJudgeTests(unittest.TestCase):
    def test_normalize_endpoint_appends_chat_completions_suffix(self) -> None:
        self.assertEqual(
            llm_judge.normalize_endpoint("https://zenmux.ai/api/v1"),
            "https://zenmux.ai/api/v1/chat/completions",
        )
        self.assertEqual(
            llm_judge.normalize_endpoint("https://zenmux.ai/api/v1/chat/completions"),
            "https://zenmux.ai/api/v1/chat/completions",
        )

    def test_build_chat_payload_contains_packet_fields_and_schema(self) -> None:
        packet = {
            "review_request_id": "alpha",
            "runner_verdict": {"status": "FAIL"},
            "expected_end_state": {"primary": {}},
            "ai_end_state": {"primary": {}},
            "diff": [{"kind": "hand_mismatch"}],
        }
        payload = llm_judge.build_chat_payload(packet, "openai/gpt-5.4")
        self.assertEqual(payload["model"], "openai/gpt-5.4")
        self.assertEqual(payload["response_format"]["json_schema"]["schema"]["required"], ["resolution", "confidence", "reason"])
        self.assertIn("review_request_id", json.loads(payload["messages"][1]["content"]))

    def test_run_llm_judge_writes_jsonl_from_mocked_responses(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            packets_path = tmp_path / "packets.jsonl"
            output_path = tmp_path / "judgments.jsonl"
            packets_path.write_text(
                "\n".join(
                    [
                        json.dumps({"review_request_id": "a", "expected_end_state": {}, "ai_end_state": {}, "diff": [], "runner_verdict": {"status": "FAIL"}}, ensure_ascii=False),
                        json.dumps({"review_request_id": "b", "expected_end_state": {}, "ai_end_state": {}, "diff": [], "runner_verdict": {"status": "DIVERGE"}}, ensure_ascii=False),
                    ]
                )
                + "\n",
                encoding="utf-8",
            )

            mock_responses = [
                {"resolution": "equivalent", "confidence": 0.9, "reason": "Looks equivalent."},
                {"resolution": "worse", "confidence": 0.8, "reason": "Clearly worse."},
            ]

            with mock.patch.object(llm_judge, "request_chat_json", side_effect=mock_responses):
                report = llm_judge.run_llm_judge(
                    llm_judge.parse_args(
                        [
                            "--packets-path",
                            str(packets_path),
                            "--output-path",
                            str(output_path),
                            "--api-key",
                            "test-key",
                        ]
                    )
                )

            lines = [json.loads(line) for line in output_path.read_text(encoding="utf-8").splitlines() if line.strip()]
            self.assertEqual(report["judgment_count"], 2)
            self.assertEqual(lines[0]["review_request_id"], "a")
            self.assertEqual(lines[1]["resolution"], "worse")

    def test_load_api_config_reads_developer_env_without_user_root(self) -> None:
        with mock.patch.dict(
            "os.environ",
            {
                "SCENARIO_REVIEW_ENDPOINT": "https://example.invalid/api/v1",
                "SCENARIO_REVIEW_API_KEY": "env-key",
                "SCENARIO_REVIEW_MODEL": "openai/gpt-5.4-mini",
                "SCENARIO_REVIEW_TIMEOUT_SECONDS": "12.5",
            },
            clear=False,
        ):
            config = llm_judge.load_api_config(
                project_root=REPO_ROOT,
                explicit_config_path=None,
                endpoint=None,
                api_key=None,
                model=None,
                timeout_seconds=None,
            )

        self.assertEqual(config["endpoint"], "https://example.invalid/api/v1")
        self.assertEqual(config["api_key"], "env-key")
        self.assertEqual(config["model"], "openai/gpt-5.4-mini")
        self.assertEqual(config["timeout_seconds"], 12.5)


if __name__ == "__main__":
    unittest.main()
