import json
import os
import shutil
import tempfile
import unittest

import train_interaction_scorer


class TrainInteractionScorerTests(unittest.TestCase):
    def test_load_data_skips_dirty_match_payloads(self):
        tmp_dir = tempfile.mkdtemp(prefix="ptcg_train_interaction_")
        try:
            clean_path = os.path.join(tmp_dir, "clean.json")
            dirty_path = os.path.join(tmp_dir, "dirty.json")

            with open(clean_path, "w", encoding="utf-8") as handle:
                json.dump(
                    {
                        "failure_reason": "normal_game_end",
                        "match_quality_weight": 1.0,
                        "meta": {"match_id": "match_clean"},
                        "interaction_records": [
                            {
                                "match_id": "match_clean",
                                "interaction_id": 0,
                                "turn_number": 3,
                                "player_index": 0,
                                "step_id": "discard_energy",
                                "step_type": "dialog_multi_select",
                                "result": 1.0,
                                "state_features": [0.1, 0.2, 0.3],
                                "candidates": [
                                    {
                                        "candidate_index": 0,
                                        "strategy_score": 10.0,
                                        "chosen": True,
                                        "interaction_vector": [1.0, 0.0],
                                    },
                                    {
                                        "candidate_index": 1,
                                        "strategy_score": 1.0,
                                        "chosen": False,
                                        "interaction_vector": [0.0, 1.0],
                                    },
                                ],
                            }
                        ],
                    },
                    handle,
                )
            with open(dirty_path, "w", encoding="utf-8") as handle:
                json.dump(
                    {
                        "failure_reason": "unsupported_interaction_step",
                        "terminated_by_cap": False,
                        "stalled": False,
                        "match_quality_weight": 0.0,
                        "meta": {"match_id": "match_dirty"},
                        "interaction_records": [
                            {
                                "match_id": "match_dirty",
                                "interaction_id": 0,
                                "turn_number": 3,
                                "player_index": 0,
                                "step_id": "discard_energy",
                                "step_type": "dialog_multi_select",
                                "result": 1.0,
                                "state_features": [0.9, 0.9, 0.9],
                                "candidates": [
                                    {
                                        "candidate_index": 0,
                                        "strategy_score": 10.0,
                                        "chosen": True,
                                        "interaction_vector": [1.0, 0.0],
                                    }
                                ],
                            }
                        ],
                    },
                    handle,
                )

            samples, features, targets, sample_weights, state_dim, interaction_dim = train_interaction_scorer.load_data(
                tmp_dir,
                allow_dirty_matches=False,
            )

            self.assertEqual(len(samples), 2)
            self.assertEqual(features.shape[0], 2)
            self.assertEqual(targets.shape[0], 2)
            self.assertEqual(sample_weights.shape[0], 2)
            self.assertEqual(state_dim, 3)
            self.assertEqual(interaction_dim, 2)
            self.assertTrue(all(sample["match_id"] == "match_clean" for sample in samples))
        finally:
            shutil.rmtree(tmp_dir, ignore_errors=True)

    def test_load_data_prioritizes_chosen_winning_interaction_over_strategy_rank(self):
        tmp_dir = tempfile.mkdtemp(prefix="ptcg_train_interaction_teacher_")
        try:
            data_path = os.path.join(tmp_dir, "teacher.json")
            with open(data_path, "w", encoding="utf-8") as handle:
                json.dump(
                    {
                        "failure_reason": "normal_game_end",
                        "match_quality_weight": 1.0,
                        "meta": {"match_id": "match_teacher", "deck_identity": "gardevoir"},
                        "interaction_records": [
                            {
                                "match_id": "match_teacher",
                                "interaction_id": 0,
                                "turn_number": 5,
                                "player_index": 0,
                                "deck_identity": "gardevoir",
                                "step_id": "embrace_target",
                                "step_type": "card_assignment",
                                "result": 1.0,
                                "state_features": [0.1, 0.2, 0.3],
                                "candidates": [
                                    {
                                        "candidate_index": 0,
                                        "strategy_score": 100.0,
                                        "chosen": False,
                                        "interaction_vector": [1.0, 0.0],
                                    },
                                    {
                                        "candidate_index": 1,
                                        "strategy_score": 5.0,
                                        "chosen": True,
                                        "interaction_vector": [0.0, 1.0],
                                    },
                                ],
                            }
                        ],
                    },
                    handle,
                )

            samples, _features, _targets, sample_weights, _state_dim, _interaction_dim = train_interaction_scorer.load_data(
                tmp_dir,
                allow_dirty_matches=False,
            )

            unchosen = next(sample for sample in samples if not sample["chosen"])
            chosen = next(sample for sample in samples if sample["chosen"])
            self.assertLess(float(unchosen["target"]), float(chosen["target"]))
            self.assertGreater(float(chosen["sample_weight"]), 1.0)
            self.assertGreater(float(sample_weights[1]), float(sample_weights[0]))
        finally:
            shutil.rmtree(tmp_dir, ignore_errors=True)

    def test_metrics_compare_model_against_teacher_oracle_not_raw_strategy_rank(self):
        samples = [
            {
                "decision_key": "i1",
                "step_id": "embrace_target",
                "step_type": "card_assignment",
                "candidate_index": 0,
                "chosen": False,
                "target": 0.2,
                "oracle_score": 0.2,
                "strategy_score": 100.0,
                "sample_weight": 3.0,
            },
            {
                "decision_key": "i1",
                "step_id": "embrace_target",
                "step_type": "card_assignment",
                "candidate_index": 1,
                "chosen": True,
                "target": 0.9,
                "oracle_score": 0.9,
                "strategy_score": 10.0,
                "sample_weight": 3.0,
            },
        ]
        predictions = train_interaction_scorer.np.array([0.1, 0.95], dtype=train_interaction_scorer.np.float32)

        metrics = train_interaction_scorer.build_interaction_metrics(samples, predictions)

        self.assertAlmostEqual(metrics["overall"]["model_top1_hit_rate"], 1.0)
        self.assertAlmostEqual(metrics["overall"]["strategy_top1_hit_rate"], 0.0)
        self.assertGreater(metrics["overall"]["top1_gain_vs_strategy"], 0.9)
        self.assertGreater(metrics["overall"]["weighted_decision_count"], 0.0)


if __name__ == "__main__":
    unittest.main()
