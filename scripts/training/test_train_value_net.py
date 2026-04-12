import json
import os
import shutil
import tempfile
import unittest

import torch

import train_value_net


class TrainValueNetRuntimeConfigTests(unittest.TestCase):
    def test_resolve_device_prefers_explicit_cpu(self):
        device = train_value_net.resolve_device("cpu")
        self.assertEqual(device.type, "cpu")

    def test_resolve_device_auto_matches_cuda_availability(self):
        device = train_value_net.resolve_device("auto")
        expected = "cuda" if torch.cuda.is_available() else "cpu"
        self.assertEqual(device.type, expected)

    def test_build_runtime_config_uses_safe_cpu_defaults(self):
        config = train_value_net.build_runtime_config(
            requested_device="cpu",
            num_threads=1,
            interop_threads=1,
        )
        self.assertEqual(config["device"].type, "cpu")
        self.assertEqual(config["num_threads"], 1)
        self.assertEqual(config["interop_threads"], 1)

    def test_build_grouped_split_indices_keeps_groups_isolated(self):
        group_ids = [
            "match_a", "match_a",
            "match_b", "match_b",
            "match_c", "match_c",
            "match_d", "match_d",
            "match_e", "match_e",
        ]

        train_idx, val_idx = train_value_net.build_grouped_split_indices(
            group_ids,
            train_ratio=0.8,
            seed=7,
        )

        train_groups = {group_ids[index] for index in train_idx}
        val_groups = {group_ids[index] for index in val_idx}

        self.assertTrue(train_idx)
        self.assertTrue(val_idx)
        self.assertTrue(train_groups.isdisjoint(val_groups))
        self.assertEqual(train_groups | val_groups, set(group_ids))

    def test_load_data_filters_dirty_matches_and_merges_decision_states(self):
        tmp_dir = tempfile.mkdtemp(prefix="ptcg_train_value_net_")
        try:
            value_dir = os.path.join(tmp_dir, "value")
            decision_dir = os.path.join(tmp_dir, "decision")
            os.makedirs(value_dir, exist_ok=True)
            os.makedirs(decision_dir, exist_ok=True)

            clean_value_path = os.path.join(value_dir, "game_clean.json")
            dirty_value_path = os.path.join(value_dir, "game_dirty.json")
            decision_path = os.path.join(decision_dir, "decision_clean.json")

            with open(clean_value_path, "w", encoding="utf-8") as handle:
                json.dump(
                    {
                        "encoder": "gardevoir",
                        "feature_dim": 3,
                        "winner_index": 0,
                        "failure_reason": "normal_game_end",
                        "match_quality_weight": 1.0,
                        "meta": {"match_id": "clean_match"},
                        "records": [
                            {"features": [0.1, 0.2, 0.3], "result": 1.0, "teacher_score": 0.8},
                            {"features": [0.4, 0.5, 0.6], "result": 0.0, "teacher_score": 0.2},
                        ],
                    },
                    handle,
                )
            with open(dirty_value_path, "w", encoding="utf-8") as handle:
                json.dump(
                    {
                        "encoder": "gardevoir",
                        "feature_dim": 3,
                        "winner_index": 0,
                        "failure_reason": "action_cap_reached",
                        "terminated_by_cap": True,
                        "match_quality_weight": 0.0,
                        "meta": {"match_id": "dirty_match"},
                        "records": [
                            {"features": [0.9, 0.9, 0.9], "result": 1.0, "teacher_score": 0.9},
                        ],
                    },
                    handle,
                )
            with open(decision_path, "w", encoding="utf-8") as handle:
                json.dump(
                    {
                        "failure_reason": "deck_out",
                        "match_quality_weight": 0.9,
                        "meta": {"match_id": "clean_match"},
                        "records": [
                            {"state_features": [0.7, 0.8, 0.9], "result": 1.0},
                        ],
                        "interaction_records": [
                            {"state_features": [0.2, 0.3, 0.4], "result": 0.0},
                        ],
                    },
                    handle,
                )

            features, results, teacher_scores, sample_weights, group_ids, encoder_name, feature_dim = train_value_net.load_data(
                value_dir,
                decision_data_dir=decision_dir,
                decision_state_weight=0.75,
                interaction_state_weight=0.5,
                allow_dirty_matches=False,
            )

            self.assertEqual(encoder_name, "gardevoir")
            self.assertEqual(feature_dim, 3)
            self.assertEqual(features.shape[0], 4)
            self.assertEqual(results.shape[0], 4)
            self.assertEqual(teacher_scores.shape[0], 4)
            self.assertEqual(sample_weights.shape[0], 4)
            self.assertTrue(all(group_id == "clean_match" for group_id in group_ids.tolist()))
            self.assertAlmostEqual(float(sample_weights[0]), 1.0)
            self.assertAlmostEqual(float(sample_weights[1]), 1.0)
            self.assertAlmostEqual(float(sample_weights[2]), 0.9 * 0.75)
            self.assertAlmostEqual(float(sample_weights[3]), 0.9 * 0.5)
            self.assertEqual(float(teacher_scores[2]), -1.0)
            self.assertEqual(float(teacher_scores[3]), -1.0)
        finally:
            shutil.rmtree(tmp_dir, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
