import json
import os
import shutil
import unittest
import uuid

import numpy as np
import train_action_scorer


def _make_decision_record(
    turn_number: int,
    player_index: int,
    state_features: list[float],
    result: float,
    legal_actions: list[dict],
) -> dict:
    return {
        "run_id": "run_test",
        "match_id": "match_test",
        "decision_id": turn_number,
        "turn_number": turn_number,
        "phase": "MAIN",
        "player_index": player_index,
        "pipeline_name": "miraidon_focus_training",
        "deck_identity": "miraidon",
        "opponent_deck_identity": "gardevoir",
        "state_features": state_features,
        "legal_actions": legal_actions,
        "chosen_action": next(
            (
                {
                    "kind": action["kind"],
                    "features": action.get("features", {}),
                }
                for action in legal_actions
                if action.get("chosen", False)
            ),
            {},
        ),
        "reason_tags": [],
        "used_mcts": False,
        "result": result,
    }


def _make_legal_action(
    action_index: int,
    kind: str,
    heuristic_score: float,
    action_vector: list[float],
    *,
    chosen: bool = False,
) -> dict:
    return {
        "action_index": action_index,
        "kind": kind,
        "score": heuristic_score,
        "features": {
            "action_vector": action_vector,
        },
        "chosen": chosen,
    }


class TrainActionScorerTests(unittest.TestCase):
    def test_metrics_and_digest_capture_model_vs_heuristic_gains(self):
        samples = [
            {
                "decision_key": "d1",
                "action_kind": "attack",
                "teacher_action_kind": "attack",
                "deck_identity": "miraidon",
                "opponent_deck_identity": "gardevoir",
                "used_mcts": False,
                "target": 1.0,
                "result": 1.0,
                "chosen": True,
                "heuristic_score": 10.0,
                "action_index": 0,
            },
            {
                "decision_key": "d1",
                "action_kind": "play_trainer",
                "teacher_action_kind": "attack",
                "deck_identity": "miraidon",
                "opponent_deck_identity": "gardevoir",
                "used_mcts": False,
                "target": 0.75,
                "result": 1.0,
                "chosen": False,
                "heuristic_score": 100.0,
                "action_index": 1,
            },
            {
                "decision_key": "d2",
                "action_kind": "play_trainer",
                "teacher_action_kind": "play_trainer",
                "deck_identity": "miraidon",
                "opponent_deck_identity": "charizard_ex",
                "used_mcts": False,
                "target": 1.0,
                "result": 1.0,
                "chosen": True,
                "heuristic_score": 200.0,
                "action_index": 0,
            },
            {
                "decision_key": "d2",
                "action_kind": "attack",
                "teacher_action_kind": "play_trainer",
                "deck_identity": "miraidon",
                "opponent_deck_identity": "charizard_ex",
                "used_mcts": False,
                "target": 0.75,
                "result": 1.0,
                "chosen": False,
                "heuristic_score": 50.0,
                "action_index": 1,
            },
        ]
        predictions = np.array([0.95, 0.10, 0.90, 0.20], dtype=np.float32)

        metrics = train_action_scorer.build_decision_metrics(samples, predictions)
        digest = train_action_scorer.build_decision_comparison_digest(metrics)

        self.assertEqual(metrics["overall"]["decision_count"], 2)
        self.assertAlmostEqual(metrics["overall"]["model_top1_hit_rate"], 1.0)
        self.assertAlmostEqual(metrics["overall"]["heuristic_top1_hit_rate"], 0.5)
        self.assertAlmostEqual(metrics["overall"]["top1_gain_vs_heuristic"], 0.5)
        self.assertIn("attack", metrics["by_action_kind"])
        self.assertIn("play_trainer", metrics["by_action_kind"])
        self.assertTrue(digest["best_action_kinds"])
        self.assertEqual(digest["overall_summary"]["top1_gain_vs_heuristic"], 0.5)

    def test_parse_args_and_tiny_fit_export_round_trip(self):
        tmp_dir = os.path.join(
            os.getcwd(),
            "tmp_test_train_action_scorer_%s" % uuid.uuid4().hex,
        )
        os.makedirs(tmp_dir, exist_ok=True)
        try:
            data_dir = os.path.join(tmp_dir, "decision_samples")
            os.makedirs(data_dir, exist_ok=True)
            output_path = os.path.join(tmp_dir, "action_scorer_weights.json")
            data_path = os.path.join(data_dir, "match_test.json")

            payload = {
                "version": "1.0",
                "winner_index": 0,
                "meta": {
                    "match_id": "match_test",
                    "pipeline_name": "miraidon_focus_training",
                },
                "records": [
                    _make_decision_record(
                        1,
                        0,
                        [0.2, 0.8],
                        1.0,
                        [
                            _make_legal_action(0, "attack", 500.0, [1.0, 0.0, 0.0], chosen=True),
                            _make_legal_action(1, "play_trainer", 50.0, [0.0, 1.0, 0.0]),
                        ],
                    ),
                    _make_decision_record(
                        2,
                        1,
                        [0.7, 0.1],
                        0.0,
                        [
                            _make_legal_action(0, "play_trainer", 100.0, [0.0, 1.0, 0.0]),
                            _make_legal_action(1, "attack", 50.0, [0.0, 0.0, 1.0], chosen=True),
                        ],
                    ),
                    _make_decision_record(
                        3,
                        0,
                        [0.3, 0.4],
                        1.0,
                        [
                            _make_legal_action(0, "play_trainer", 25.0, [0.0, 1.0, 1.0]),
                            _make_legal_action(1, "attach_energy", 200.0, [1.0, 0.0, 1.0], chosen=True),
                        ],
                    ),
                ],
            }
            with open(data_path, "w", encoding="utf-8") as handle:
                json.dump(payload, handle)

            args = train_action_scorer.parse_args(
                [
                    "--data-dir",
                    data_dir,
                    "--output",
                    output_path,
                    "--epochs",
                    "2",
                    "--batch-size",
                    "2",
                    "--device",
                    "cpu",
                    "--num-threads",
                    "1",
                    "--interop-threads",
                    "1",
                ]
            )

            train_action_scorer.train_from_args(args)

            self.assertTrue(os.path.exists(output_path))
            metrics_path = os.path.join(tmp_dir, "decision_metrics.json")
            digest_path = os.path.join(tmp_dir, "decision_comparison_digest.json")
            self.assertTrue(os.path.exists(metrics_path))
            self.assertTrue(os.path.exists(digest_path))
            with open(output_path, "r", encoding="utf-8") as handle:
                exported = json.load(handle)
            with open(metrics_path, "r", encoding="utf-8") as handle:
                metrics = json.load(handle)
            with open(digest_path, "r", encoding="utf-8") as handle:
                digest = json.load(handle)

            self.assertEqual(exported["architecture"], "action_mlp")
            self.assertEqual(exported["state_dim"], 2)
            self.assertEqual(exported["action_dim"], 3)
            self.assertEqual(exported["input_dim"], 5)
            self.assertGreaterEqual(len(exported["layers"]), 2)
            self.assertGreaterEqual(metrics["overall"]["decision_count"], 3)
            self.assertIn("by_action_kind", metrics)
            self.assertIn("overall_summary", digest)
        finally:
            shutil.rmtree(tmp_dir, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
