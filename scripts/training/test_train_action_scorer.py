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
    teacher_available: bool = False,
    teacher_post_value: float = 0.5,
    teacher_value_delta: float = 0.0,
) -> dict:
    return {
        "action_index": action_index,
        "kind": kind,
        "score": heuristic_score,
        "features": {
            "action_vector": action_vector,
        },
        "chosen": chosen,
        "teacher_available": teacher_available,
        "teacher_post_value": teacher_post_value,
        "teacher_value_delta": teacher_value_delta,
    }


class TrainActionScorerTests(unittest.TestCase):
    def test_build_grouped_split_indices_keeps_groups_isolated(self):
        group_ids = [
            "match_a", "match_a",
            "match_b", "match_b",
            "match_c", "match_c",
            "match_d", "match_d",
            "match_e", "match_e",
        ]

        train_idx, val_idx = train_action_scorer.build_grouped_split_indices(
            group_ids,
            train_ratio=0.8,
            seed=11,
        )

        train_groups = {group_ids[index] for index in train_idx}
        val_groups = {group_ids[index] for index in val_idx}

        self.assertTrue(train_idx)
        self.assertTrue(val_idx)
        self.assertTrue(train_groups.isdisjoint(val_groups))
        self.assertEqual(train_groups | val_groups, set(group_ids))

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

    def test_load_data_skips_dirty_match_payloads(self):
        tmp_dir = os.path.join(
            os.getcwd(),
            "tmp_test_train_action_scorer_dirty_%s" % uuid.uuid4().hex,
        )
        os.makedirs(tmp_dir, exist_ok=True)
        try:
            data_path = os.path.join(tmp_dir, "match_test.json")
            dirty_path = os.path.join(tmp_dir, "match_dirty.json")
            with open(data_path, "w", encoding="utf-8") as handle:
                json.dump(
                    {
                        "version": "1.0",
                        "winner_index": 0,
                        "failure_reason": "normal_game_end",
                        "match_quality_weight": 1.0,
                        "meta": {"match_id": "match_clean"},
                        "records": [
                            _make_decision_record(
                                1,
                                0,
                                [0.1, 0.2],
                                1.0,
                                [
                                    _make_legal_action(0, "attack", 100.0, [1.0, 0.0], chosen=True),
                                    _make_legal_action(1, "play_trainer", 10.0, [0.0, 1.0]),
                                ],
                            )
                        ],
                    },
                    handle,
                )
            with open(dirty_path, "w", encoding="utf-8") as handle:
                json.dump(
                    {
                        "version": "1.0",
                        "winner_index": 0,
                        "failure_reason": "action_cap_reached",
                        "terminated_by_cap": True,
                        "match_quality_weight": 0.0,
                        "meta": {"match_id": "match_dirty"},
                        "records": [
                            _make_decision_record(
                                1,
                                0,
                                [0.9, 0.9],
                                1.0,
                                [
                                    _make_legal_action(0, "attack", 100.0, [1.0, 0.0], chosen=True),
                                    _make_legal_action(1, "play_trainer", 10.0, [0.0, 1.0]),
                                ],
                            )
                        ],
                    },
                    handle,
                )

            samples, features, targets, sample_weights, state_dim, action_dim = train_action_scorer.load_data(
                tmp_dir,
                allow_dirty_matches=False,
            )

            self.assertEqual(len(samples), 2)
            self.assertEqual(features.shape[0], 2)
            self.assertEqual(targets.shape[0], 2)
            self.assertEqual(sample_weights.shape[0], 2)
            self.assertEqual(state_dim, 2)
            self.assertEqual(action_dim, 2)
            self.assertEqual({sample["match_id"] for sample in samples}, {"match_test"})
        finally:
            shutil.rmtree(tmp_dir, ignore_errors=True)

    def test_load_data_prefers_exported_teacher_scores_when_available(self):
        tmp_dir = os.path.join(
            os.getcwd(),
            "tmp_test_train_action_scorer_teacher_%s" % uuid.uuid4().hex,
        )
        os.makedirs(tmp_dir, exist_ok=True)
        try:
            data_path = os.path.join(tmp_dir, "match_teacher.json")
            with open(data_path, "w", encoding="utf-8") as handle:
                json.dump(
                    {
                        "version": "1.0",
                        "winner_index": 0,
                        "failure_reason": "normal_game_end",
                        "match_quality_weight": 1.0,
                        "meta": {"match_id": "match_teacher"},
                        "records": [
                            _make_decision_record(
                                1,
                                0,
                                [0.1, 0.2],
                                1.0,
                                [
                                    _make_legal_action(
                                        0,
                                        "attack",
                                        10.0,
                                        [1.0, 0.0],
                                        chosen=True,
                                        teacher_available=True,
                                        teacher_post_value=0.2,
                                        teacher_value_delta=-0.2,
                                    ),
                                    _make_legal_action(
                                        1,
                                        "play_trainer",
                                        5.0,
                                        [0.0, 1.0],
                                        teacher_available=True,
                                        teacher_post_value=0.9,
                                        teacher_value_delta=0.4,
                                    ),
                                ],
                            )
                        ],
                    },
                    handle,
                )

            samples, _features, targets, _weights, _state_dim, _action_dim = train_action_scorer.load_data(
                tmp_dir,
                allow_dirty_matches=False,
            )

            attack_sample = next(sample for sample in samples if sample["action_kind"] == "attack")
            trainer_sample = next(sample for sample in samples if sample["action_kind"] == "play_trainer")
            self.assertLess(float(attack_sample["oracle_score"]), float(trainer_sample["oracle_score"]))
            self.assertLess(float(attack_sample["target"]), float(trainer_sample["target"]))
            self.assertEqual(len(targets), 2)
        finally:
            shutil.rmtree(tmp_dir, ignore_errors=True)

    def test_load_data_upweights_gardevoir_core_action_kinds(self):
        tmp_dir = os.path.join(
            os.getcwd(),
            "tmp_test_train_action_scorer_weights_%s" % uuid.uuid4().hex,
        )
        os.makedirs(tmp_dir, exist_ok=True)
        try:
            data_path = os.path.join(tmp_dir, "match_weights.json")
            with open(data_path, "w", encoding="utf-8") as handle:
                json.dump(
                    {
                        "version": "1.0",
                        "winner_index": 0,
                        "failure_reason": "normal_game_end",
                        "match_quality_weight": 1.0,
                        "meta": {"match_id": "match_weights"},
                        "records": [
                            {
                                **_make_decision_record(
                                    1,
                                    0,
                                    [0.1, 0.2],
                                    1.0,
                                    [
                                        _make_legal_action(0, "evolve", 10.0, [1.0, 0.0], chosen=True),
                                        _make_legal_action(1, "attack", 9.0, [0.0, 1.0]),
                                    ],
                                ),
                                "deck_identity": "gardevoir",
                            }
                        ],
                    },
                    handle,
                )

            samples, _features, _targets, sample_weights, _state_dim, _action_dim = train_action_scorer.load_data(
                tmp_dir,
                allow_dirty_matches=False,
            )

            evolve_sample = next(sample for sample in samples if sample["action_kind"] == "evolve")
            attack_sample = next(sample for sample in samples if sample["action_kind"] == "attack")
            evolve_weight = float(evolve_sample["sample_weight"])
            attack_weight = float(attack_sample["sample_weight"])
            self.assertGreater(evolve_weight, attack_weight)
            self.assertGreater(float(sample_weights[0]), float(sample_weights[1]))
        finally:
            shutil.rmtree(tmp_dir, ignore_errors=True)

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
