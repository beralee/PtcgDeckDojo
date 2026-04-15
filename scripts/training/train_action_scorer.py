#!/usr/bin/env python3
"""
Train a lightweight action scorer from exported decision-sample JSON files.
Exports weights in a GDScript-readable JSON format.
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import sys
from collections import defaultdict

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader, TensorDataset


class ActionScorerNet(nn.Module):
    def __init__(self, input_dim: int, hidden1: int = 64, hidden2: int = 32):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(input_dim, hidden1),
            nn.ReLU(),
            nn.Linear(hidden1, hidden2),
            nn.ReLU(),
            nn.Linear(hidden2, 1),
            nn.Sigmoid(),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.net(x).squeeze(-1)


def resolve_device(requested_device: str) -> torch.device:
    normalized = str(requested_device).strip().lower()
    if normalized in ("", "auto"):
        return torch.device("cuda" if torch.cuda.is_available() else "cpu")
    if normalized == "cuda":
        if torch.cuda.is_available():
            return torch.device("cuda")
        print("[warning] CUDA requested but unavailable; falling back to CPU")
        return torch.device("cpu")
    return torch.device("cpu")


def configure_torch_threads(num_threads: int, interop_threads: int) -> None:
    if num_threads > 0:
        torch.set_num_threads(num_threads)
    if interop_threads > 0:
        try:
            torch.set_num_interop_threads(interop_threads)
        except RuntimeError:
            pass


def build_runtime_config(requested_device: str, num_threads: int, interop_threads: int) -> dict:
    device = resolve_device(requested_device)
    configure_torch_threads(num_threads, interop_threads)
    return {
        "device": device,
        "num_threads": num_threads,
        "interop_threads": interop_threads,
    }


def build_grouped_split_indices(
    group_ids: list[str] | np.ndarray,
    train_ratio: float = 0.8,
    seed: int = 7,
) -> tuple[list[int], list[int]]:
    normalized_groups = [str(group_id) for group_id in group_ids]
    grouped_indices: dict[str, list[int]] = defaultdict(list)
    for index, group_id in enumerate(normalized_groups):
        grouped_indices[group_id].append(index)

    unique_groups = list(grouped_indices.keys())
    if not unique_groups:
        return [], []
    if len(unique_groups) == 1:
        only_indices = grouped_indices[unique_groups[0]]
        return list(only_indices), list(only_indices)

    rng = np.random.default_rng(seed)
    shuffled_groups = [unique_groups[index] for index in rng.permutation(len(unique_groups))]
    split = int(round(len(shuffled_groups) * float(train_ratio)))
    split = max(1, min(len(shuffled_groups) - 1, split))

    train_groups = set(shuffled_groups[:split])
    val_groups = set(shuffled_groups[split:])

    train_idx: list[int] = []
    val_idx: list[int] = []
    for group_id, indices in grouped_indices.items():
        if group_id in train_groups:
            train_idx.extend(indices)
        elif group_id in val_groups:
            val_idx.extend(indices)

    if not train_idx:
        fallback_group = shuffled_groups[0]
        train_idx.extend(grouped_indices[fallback_group])
    if not val_idx:
        fallback_group = shuffled_groups[-1]
        val_idx.extend(grouped_indices[fallback_group])
    return train_idx, val_idx


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train the PTCG Train action scorer")
    parser.add_argument("--data-dir", required=True, help="decision sample directory")
    parser.add_argument("--output", default="action_scorer_weights.json", help="output weights path")
    parser.add_argument("--epochs", type=int, default=20, help="training epochs")
    parser.add_argument("--batch-size", type=int, default=256, help="batch size")
    parser.add_argument("--lr", type=float, default=0.001, help="learning rate")
    parser.add_argument("--hidden1", type=int, default=64, help="first hidden layer size")
    parser.add_argument("--hidden2", type=int, default=32, help="second hidden layer size")
    parser.add_argument("--device", default="auto", choices=["auto", "cpu", "cuda"], help="training device")
    parser.add_argument("--num-threads", type=int, default=1, help="torch CPU thread cap; 0 keeps default")
    parser.add_argument("--interop-threads", type=int, default=1, help="torch interop thread cap; 0 keeps default")
    parser.add_argument("--allow-dirty-matches", action="store_true", help="keep capped/stalled/unsupported matches in training")
    return parser.parse_args(argv)


def _normalize_scores(scores: list[float]) -> list[float]:
    if not scores:
        return []
    min_score = min(scores)
    max_score = max(scores)
    if abs(max_score - min_score) < 1e-6:
        return [0.5 for _ in scores]
    return [(score - min_score) / (max_score - min_score) for score in scores]


def _normalize_optional_scores(scores: list[float | None]) -> list[float]:
    present = [float(score) for score in scores if score is not None]
    if not present:
        return [0.5 for _ in scores]
    if len(present) == 1:
        return [0.5 if score is not None else 0.5 for score in scores]
    min_score = min(present)
    max_score = max(present)
    if abs(max_score - min_score) < 1e-6:
        return [0.5 if score is not None else 0.5 for score in scores]
    normalized: list[float] = []
    for score in scores:
        if score is None:
            normalized.append(0.5)
        else:
            normalized.append((float(score) - min_score) / (max_score - min_score))
    return normalized


def _normalize_name(value: str | None) -> str:
    return str(value or "").strip().lower()


def _gardevoir_card_weight(action_kind: str, card_name: str, phase: str) -> float:
    kind_key = _normalize_name(action_kind)
    card_key = _normalize_name(card_name)
    phase_key = _normalize_name(phase)
    weight = 1.0
    if kind_key == "play_basic_to_bench":
        if card_key == "ralts":
            weight *= 2.0 if phase_key in {"early", "mid"} else 1.4
        elif card_key in {"munkidori", "drifloon", "scream tail"}:
            weight *= 1.2
    elif kind_key == "evolve":
        if card_key == "kirlia":
            weight *= 1.45
        elif card_key == "gardevoir ex":
            weight *= 1.55
    elif kind_key == "play_trainer":
        if card_key in {"buddy-buddy poffin", "nest ball", "ultra ball", "arven", "technical machine: evolution"}:
            weight *= 1.2 if phase_key in {"early", "mid"} else 1.05
    return weight


def _action_kind_weight(deck_identity: str, action_kind: str, card_name: str = "", phase: str = "") -> float:
    deck_key = str(deck_identity).strip().lower()
    kind_key = str(action_kind).strip().lower()
    weight = 1.0
    if deck_key == "gardevoir":
        if kind_key == "evolve":
            weight *= 2.5
        elif kind_key == "play_basic_to_bench":
            weight *= 2.2
        elif kind_key == "use_ability":
            weight *= 2.35
        elif kind_key == "attach_energy":
            weight *= 1.2
        elif kind_key == "attack":
            weight *= 1.15
        weight *= _gardevoir_card_weight(action_kind, card_name, phase)
    elif deck_key == "miraidon":
        if kind_key == "attach_energy":
            weight *= 1.35
        elif kind_key == "use_ability":
            weight *= 1.2
        elif kind_key == "play_basic_to_bench":
            weight *= 1.15
        elif kind_key == "attack":
            weight *= 1.15
    return weight


def _plan_bonus(deck_identity: str, action_kind: str, chosen: bool, result: float, card_name: str = "", phase: str = "") -> float:
    if not chosen:
        return 0.0
    deck_key = str(deck_identity).strip().lower()
    kind_key = str(action_kind).strip().lower()
    card_key = _normalize_name(card_name)
    phase_key = _normalize_name(phase)
    result_clamped = max(0.0, min(1.0, float(result)))
    if deck_key == "gardevoir":
        if kind_key == "evolve":
            if card_key == "gardevoir ex":
                return 0.18 * result_clamped
            if card_key == "kirlia":
                return 0.16 * result_clamped
            return 0.12 * result_clamped
        if kind_key == "play_basic_to_bench":
            if card_key == "ralts" and phase_key in {"early", "mid"}:
                return 0.20 * result_clamped
            if card_key in {"munkidori", "drifloon", "scream tail"}:
                return 0.10 * result_clamped
            return 0.08 * result_clamped
        if kind_key == "use_ability":
            return 0.12 * result_clamped if phase_key != "early" else 0.08 * result_clamped
        if kind_key == "play_trainer" and card_key in {"buddy-buddy poffin", "nest ball", "ultra ball", "arven", "technical machine: evolution"}:
            return 0.08 * result_clamped if phase_key in {"early", "mid"} else 0.03 * result_clamped
    if deck_key == "miraidon":
        if kind_key == "attach_energy":
            return 0.06 * result_clamped
        if kind_key == "use_ability":
            return 0.04 * result_clamped
    return 0.0


def _build_decision_key(record: dict, path: str, record_index: int) -> str:
    match_id = record.get("match_id") or os.path.splitext(os.path.basename(path))[0]
    decision_id = record.get("decision_id", record_index)
    turn_number = record.get("turn_number", -1)
    player_index = record.get("player_index", -1)
    return "%s:%s:%s:%s" % (match_id, decision_id, turn_number, player_index)


def _normalize_failure_reason(payload: dict) -> str:
    return str(payload.get("failure_reason", "")).strip()


def _payload_is_dirty(payload: dict) -> bool:
    if bool(payload.get("terminated_by_cap", False)) or bool(payload.get("stalled", False)):
        return True
    failure_reason = _normalize_failure_reason(payload)
    if failure_reason in {"", "normal_game_end", "deck_out"}:
        return False
    return True


def _payload_match_quality_weight(payload: dict) -> float:
    try:
        return float(payload.get("match_quality_weight", 1.0))
    except (TypeError, ValueError):
        return 1.0


def load_decision_samples(
    data_dir: str,
    allow_dirty_matches: bool = False,
) -> tuple[list[dict], np.ndarray, np.ndarray, np.ndarray, int, int]:
    pattern = os.path.join(data_dir, "*.json")
    files = sorted(glob.glob(pattern))
    if not files:
        print(f"[error] no decision sample files found: {pattern}")
        sys.exit(1)

    flat_samples: list[dict] = []
    sample_rows: list[list[float]] = []
    sample_targets: list[float] = []
    sample_weights: list[float] = []
    state_dim = -1
    action_dim = -1

    for path in files:
        with open(path, "r", encoding="utf-8") as handle:
            payload = json.load(handle)
        if not allow_dirty_matches and _payload_is_dirty(payload):
            continue
        payload_weight = max(0.0, _payload_match_quality_weight(payload))
        payload_match_id = payload.get("meta", {}).get("match_id", os.path.splitext(os.path.basename(path))[0])
        for record_index, record in enumerate(payload.get("records", [])):
            state_features = [float(v) for v in record.get("state_features", [])]
            legal_actions = record.get("legal_actions", [])
            if not state_features or not isinstance(legal_actions, list):
                continue
            decision_key = record.get("decision_key") or _build_decision_key(record, path, record_index)
            legal_scores: list[float] = []
            for action in legal_actions:
                if not isinstance(action, dict):
                    continue
                legal_scores.append(float(action.get("score", 0.0)))
            normalized_scores = _normalize_scores(legal_scores)
            decision_samples: list[dict] = []
            decision_rows: list[list[float]] = []
            for action_index, action in enumerate(legal_actions):
                features = action.get("features", {}) if isinstance(action, dict) else {}
                action_vector = features.get("action_vector", []) if isinstance(features, dict) else []
                if not action_vector:
                    continue
                if state_dim < 0:
                    state_dim = len(state_features)
                if action_dim < 0:
                    action_dim = len(action_vector)
                if len(state_features) != state_dim or len(action_vector) != action_dim:
                    continue
                used_mcts = bool(record.get("used_mcts", False))
                row = state_features + [float(v) for v in action_vector]
                teacher_available = bool(action.get("teacher_available", False))
                teacher_post_value = None
                teacher_value_delta = None
                if teacher_available:
                    try:
                        teacher_post_value = float(action.get("teacher_post_value", 0.5))
                        teacher_value_delta = float(action.get("teacher_value_delta", 0.0))
                    except (TypeError, ValueError):
                        teacher_available = False
                        teacher_post_value = None
                        teacher_value_delta = None
                sample = {
                    "decision_key": decision_key,
                    "match_id": record.get("match_id", payload_match_id),
                    "turn_number": int(record.get("turn_number", 0)),
                    "phase": str(record.get("phase", "")),
                    "player_index": int(record.get("player_index", 0)),
                    "pipeline_name": record.get("pipeline_name", payload.get("meta", {}).get("pipeline_name", "unknown")),
                    "deck_identity": str(record.get("deck_identity", "unknown")),
                    "opponent_deck_identity": str(record.get("opponent_deck_identity", "unknown")),
                    "used_mcts": used_mcts,
                    "action_kind": str(action.get("kind", "unknown")),
                    "action_index": int(action.get("action_index", len(decision_samples))),
                    "card_name": str(action.get("card_name", "")),
                    "target_name": str(action.get("target_name", "")),
                    "heuristic_score": float(action.get("score", 0.0)),
                    "score_rank": float(normalized_scores[action_index] if action_index < len(normalized_scores) else 0.5),
                    "result": float(record.get("result", 0.5)),
                    "chosen": bool(action.get("chosen", False)),
                    "teacher_available": teacher_available,
                    "teacher_post_value": teacher_post_value,
                    "teacher_value_delta": teacher_value_delta,
                }
                decision_samples.append(sample)
                decision_rows.append(row)

            if decision_samples:
                teacher_post_ranks = _normalize_optional_scores(
                    [sample.get("teacher_post_value") for sample in decision_samples]
                )
                teacher_delta_ranks = _normalize_optional_scores(
                    [sample.get("teacher_value_delta") for sample in decision_samples]
                )
                for sample_index, sample in enumerate(decision_samples):
                    score_rank = float(sample.get("score_rank", 0.5))
                    oracle_score = score_rank
                    if bool(sample.get("teacher_available", False)):
                        teacher_signal = 0.75 * float(teacher_post_ranks[sample_index]) + 0.25 * float(teacher_delta_ranks[sample_index])
                        oracle_score = max(0.0, min(1.0, 0.85 * teacher_signal + 0.15 * score_rank))
                    oracle_score = max(
                        0.0,
                        min(
                            1.0,
                            oracle_score
                            + _plan_bonus(
                                str(sample.get("deck_identity", "unknown")),
                                str(sample.get("action_kind", "unknown")),
                                bool(sample.get("chosen", False)),
                                float(sample.get("result", 0.5)),
                                str(sample.get("card_name", "")),
                                str(sample.get("phase", "")),
                            ),
                        ),
                    )
                    realized_bonus = 0.10 * float(sample.get("result", 0.5)) if bool(sample.get("chosen", False)) else 0.0
                    target = max(0.0, min(1.0, 0.90 * oracle_score + realized_bonus))
                    sample["oracle_score"] = float(oracle_score)
                    sample["target"] = float(target)
                    sample_weight = payload_weight * _action_kind_weight(
                        str(sample.get("deck_identity", "unknown")),
                        str(sample.get("action_kind", "unknown")),
                        str(sample.get("card_name", "")),
                        str(sample.get("phase", "")),
                    )
                    if bool(sample.get("chosen", False)):
                        sample_weight *= 1.1
                    sample["sample_weight"] = float(sample_weight)
                    sample_rows.append(decision_rows[sample_index])
                    sample_targets.append(target)
                    sample_weights.append(sample_weight)
                teacher_entry = max(
                    decision_samples,
                    key=lambda entry: (
                        float(entry.get("oracle_score", entry.get("target", 0.0))),
                        float(entry.get("heuristic_score", 0.0)),
                        -int(entry.get("action_index", 0)),
                    ),
                )
                for sample in decision_samples:
                    sample["teacher_action_kind"] = teacher_entry.get("action_kind", "unknown")
                flat_samples.extend(decision_samples)

    if not flat_samples or not sample_rows or state_dim <= 0 or action_dim <= 0:
        print(f"[error] no usable action samples found in {data_dir}")
        sys.exit(1)

    print(f"[data] loaded {len(files)} files, {len(flat_samples)} action samples")
    return (
        flat_samples,
        np.array(sample_rows, dtype=np.float32),
        np.array(sample_targets, dtype=np.float32),
        np.array(sample_weights, dtype=np.float32),
        state_dim,
        action_dim,
    )


def load_data(data_dir: str, allow_dirty_matches: bool = False) -> tuple[list[dict], np.ndarray, np.ndarray, np.ndarray, int, int]:
    return load_decision_samples(data_dir, allow_dirty_matches=allow_dirty_matches)


def _entry_key(sample: dict) -> tuple[int, str]:
    return (
        int(sample.get("action_index", 0)),
        str(sample.get("action_kind", "unknown")),
    )


def _rate(numerator: float, denominator: float) -> float:
    if denominator <= 0:
        return 0.0
    return float(numerator) / float(denominator)


def _mean(values: list[float]) -> float:
    if not values:
        return 0.0
    return float(sum(values)) / float(len(values))


def _build_decision_summaries(samples: list[dict], predictions: np.ndarray) -> list[dict]:
    predicted_values = np.asarray(predictions, dtype=np.float32).reshape(-1)
    if len(samples) != len(predicted_values):
        raise ValueError("samples/predictions length mismatch")

    decision_groups: dict[str, list[dict]] = defaultdict(list)
    for sample, predicted_value in zip(samples, predicted_values):
        enriched = dict(sample)
        enriched["predicted_value"] = float(predicted_value)
        decision_groups[str(enriched.get("decision_key", "unknown"))].append(enriched)

    decision_summaries: list[dict] = []
    for decision_key, entries in decision_groups.items():
        if not entries:
            continue

        oracle_sorted = sorted(
            entries,
            key=lambda entry: (
                float(entry.get("oracle_score", entry.get("target", 0.0))),
                float(entry.get("heuristic_score", 0.0)),
                -int(entry.get("action_index", 0)),
            ),
            reverse=True,
        )
        oracle_entry = oracle_sorted[0]
        oracle_key = _entry_key(oracle_entry)

        model_sorted = sorted(
            entries,
            key=lambda entry: (
                float(entry.get("predicted_value", 0.0)),
                float(entry.get("heuristic_score", 0.0)),
                -int(entry.get("action_index", 0)),
            ),
            reverse=True,
        )
        heuristic_sorted = sorted(
            entries,
            key=lambda entry: (
                float(entry.get("heuristic_score", 0.0)),
                float(entry.get("predicted_value", 0.0)),
                -int(entry.get("action_index", 0)),
            ),
            reverse=True,
        )
        chosen_entry = next((entry for entry in entries if entry.get("chosen", False)), oracle_entry)
        chosen_key = _entry_key(chosen_entry)

        model_keys = [_entry_key(entry) for entry in model_sorted]
        heuristic_keys = [_entry_key(entry) for entry in heuristic_sorted]
        oracle_keys = [_entry_key(entry) for entry in oracle_sorted]

        model_top1_hit = model_keys[0] == oracle_key
        heuristic_top1_hit = heuristic_keys[0] == oracle_key
        model_top3_hit = oracle_key in model_keys[:3]
        heuristic_top3_hit = oracle_key in heuristic_keys[:3]
        model_margin = float(model_sorted[0].get("predicted_value", 0.0))
        if len(model_sorted) > 1:
            model_margin -= float(model_sorted[1].get("predicted_value", 0.0))
        heuristic_margin = float(heuristic_sorted[0].get("heuristic_score", 0.0))
        if len(heuristic_sorted) > 1:
            heuristic_margin -= float(heuristic_sorted[1].get("heuristic_score", 0.0))

        decision_summaries.append(
            {
                "decision_key": decision_key,
                "action_kind": str(oracle_entry.get("teacher_action_kind", oracle_entry.get("action_kind", "unknown"))),
                "deck_identity": str(oracle_entry.get("deck_identity", "unknown")),
                "opponent_deck_identity": str(oracle_entry.get("opponent_deck_identity", "unknown")),
                "used_mcts": bool(oracle_entry.get("used_mcts", False)),
                "sample_count": len(entries),
                "model_top1_hit": 1.0 if model_top1_hit else 0.0,
                "model_top3_hit": 1.0 if model_top3_hit else 0.0,
                "heuristic_top1_hit": 1.0 if heuristic_top1_hit else 0.0,
                "heuristic_top3_hit": 1.0 if heuristic_top3_hit else 0.0,
                "chosen_matches_oracle": 1.0 if chosen_key == oracle_key else 0.0,
                "avg_result": float(oracle_entry.get("result", 0.0)),
                "avg_oracle_score": float(oracle_entry.get("oracle_score", oracle_entry.get("target", 0.0))),
                "avg_target": float(oracle_entry.get("target", 0.0)),
                "avg_predicted_value": float(model_sorted[0].get("predicted_value", 0.0)),
                "avg_heuristic_score": float(chosen_entry.get("heuristic_score", 0.0)),
                "avg_learned_score": float(chosen_entry.get("predicted_value", 0.0)),
                "avg_margin_vs_next_best": model_margin,
                "avg_heuristic_margin_vs_next_best": heuristic_margin,
                "model_rank_of_chosen": float(model_keys.index(chosen_key) + 1),
                "heuristic_rank_of_chosen": float(heuristic_keys.index(chosen_key) + 1),
                "chosen_rank_by_target": float(oracle_keys.index(chosen_key) + 1),
            }
        )

    return decision_summaries


def _aggregate_decision_summaries(decision_summaries: list[dict]) -> dict:
    decision_count = len(decision_summaries)
    sample_count = int(sum(int(summary.get("sample_count", 0)) for summary in decision_summaries))
    return {
        "sample_count": sample_count,
        "decision_count": decision_count,
        "model_top1_hit_rate": _mean([float(summary.get("model_top1_hit", 0.0)) for summary in decision_summaries]),
        "model_top3_hit_rate": _mean([float(summary.get("model_top3_hit", 0.0)) for summary in decision_summaries]),
        "heuristic_top1_hit_rate": _mean([float(summary.get("heuristic_top1_hit", 0.0)) for summary in decision_summaries]),
        "heuristic_top3_hit_rate": _mean([float(summary.get("heuristic_top3_hit", 0.0)) for summary in decision_summaries]),
        "top1_gain_vs_heuristic": _mean([float(summary.get("model_top1_hit", 0.0)) for summary in decision_summaries])
        - _mean([float(summary.get("heuristic_top1_hit", 0.0)) for summary in decision_summaries]),
        "top3_gain_vs_heuristic": _mean([float(summary.get("model_top3_hit", 0.0)) for summary in decision_summaries])
        - _mean([float(summary.get("heuristic_top3_hit", 0.0)) for summary in decision_summaries]),
        "avg_result": _mean([float(summary.get("avg_result", 0.0)) for summary in decision_summaries]),
        "avg_oracle_score": _mean([float(summary.get("avg_oracle_score", 0.0)) for summary in decision_summaries]),
        "avg_target": _mean([float(summary.get("avg_target", 0.0)) for summary in decision_summaries]),
        "avg_predicted_value": _mean([float(summary.get("avg_predicted_value", 0.0)) for summary in decision_summaries]),
        "avg_heuristic_score": _mean([float(summary.get("avg_heuristic_score", 0.0)) for summary in decision_summaries]),
        "avg_learned_score": _mean([float(summary.get("avg_learned_score", 0.0)) for summary in decision_summaries]),
        "avg_margin_vs_next_best": _mean([float(summary.get("avg_margin_vs_next_best", 0.0)) for summary in decision_summaries]),
        "avg_heuristic_margin_vs_next_best": _mean([float(summary.get("avg_heuristic_margin_vs_next_best", 0.0)) for summary in decision_summaries]),
        "avg_model_rank_of_chosen": _mean([float(summary.get("model_rank_of_chosen", 0.0)) for summary in decision_summaries]),
        "avg_heuristic_rank_of_chosen": _mean([float(summary.get("heuristic_rank_of_chosen", 0.0)) for summary in decision_summaries]),
        "avg_chosen_rank_by_target": _mean([float(summary.get("chosen_rank_by_target", 0.0)) for summary in decision_summaries]),
        "oracle_chosen_rate": _mean([float(summary.get("chosen_matches_oracle", 0.0)) for summary in decision_summaries]),
    }


def build_decision_metrics(samples: list[dict], predictions: np.ndarray) -> dict:
    decision_summaries = _build_decision_summaries(samples, predictions)
    by_action_kind: dict[str, dict] = {}
    by_matchup: dict[str, dict] = {}

    action_kind_groups: dict[str, list[dict]] = defaultdict(list)
    matchup_groups: dict[str, list[dict]] = defaultdict(list)
    for summary in decision_summaries:
        action_kind_groups[str(summary.get("action_kind", "unknown"))].append(summary)
        matchup_key = "%s_vs_%s" % (
            str(summary.get("deck_identity", "unknown")),
            str(summary.get("opponent_deck_identity", "unknown")),
        )
        matchup_groups[matchup_key].append(summary)

    for action_kind, grouped_summaries in action_kind_groups.items():
        by_action_kind[action_kind] = _aggregate_decision_summaries(grouped_summaries)
    for matchup_key, grouped_summaries in matchup_groups.items():
        by_matchup[matchup_key] = _aggregate_decision_summaries(grouped_summaries)

    return {
        "overall": _aggregate_decision_summaries(decision_summaries),
        "by_action_kind": by_action_kind,
        "by_matchup": by_matchup,
    }


def build_decision_comparison_digest(metrics: dict) -> dict:
    def _top_entries(group_metrics: dict, label_name: str, *, reverse: bool) -> list[dict]:
        rows = []
        for label, values in group_metrics.items():
            row = dict(values)
            row[label_name] = label
            rows.append(row)
        rows.sort(
            key=lambda row: (
                float(row.get("top1_gain_vs_heuristic", 0.0)),
                float(row.get("model_top1_hit_rate", 0.0)),
                int(row.get("decision_count", 0)),
            ),
            reverse=reverse,
        )
        return rows[:5]

    action_rows = _top_entries(metrics.get("by_action_kind", {}), "action_kind", reverse=True)
    worst_action_rows = _top_entries(metrics.get("by_action_kind", {}), "action_kind", reverse=False)
    matchup_rows = _top_entries(metrics.get("by_matchup", {}), "matchup", reverse=True)
    worst_matchup_rows = _top_entries(metrics.get("by_matchup", {}), "matchup", reverse=False)

    regressions = [
        row
        for row in action_rows + worst_action_rows
        if float(row.get("top1_gain_vs_heuristic", 0.0)) < 0.0 or float(row.get("top3_gain_vs_heuristic", 0.0)) < 0.0
    ]
    confidence_warnings = []
    for label, values in metrics.get("by_action_kind", {}).items():
        if int(values.get("decision_count", 0)) < 10:
            confidence_warnings.append(
                {
                    "kind": "low_sample_action_kind",
                    "action_kind": label,
                    "decision_count": int(values.get("decision_count", 0)),
                }
            )
    for label, values in metrics.get("by_matchup", {}).items():
        if int(values.get("decision_count", 0)) < 10:
            confidence_warnings.append(
                {
                    "kind": "low_sample_matchup",
                    "matchup": label,
                    "decision_count": int(values.get("decision_count", 0)),
                }
            )

    overall = metrics.get("overall", {})
    return {
        "overall_summary": {
            "decision_count": int(overall.get("decision_count", 0)),
            "sample_count": int(overall.get("sample_count", 0)),
            "model_top1_hit_rate": float(overall.get("model_top1_hit_rate", 0.0)),
            "heuristic_top1_hit_rate": float(overall.get("heuristic_top1_hit_rate", 0.0)),
            "top1_gain_vs_heuristic": float(overall.get("top1_gain_vs_heuristic", 0.0)),
            "model_top3_hit_rate": float(overall.get("model_top3_hit_rate", 0.0)),
            "heuristic_top3_hit_rate": float(overall.get("heuristic_top3_hit_rate", 0.0)),
            "top3_gain_vs_heuristic": float(overall.get("top3_gain_vs_heuristic", 0.0)),
            "avg_margin_vs_next_best": float(overall.get("avg_margin_vs_next_best", 0.0)),
        },
        "best_action_kinds": action_rows,
        "worst_action_kinds": worst_action_rows,
        "best_matchups": matchup_rows,
        "worst_matchups": worst_matchup_rows,
        "regressions": regressions[:5],
        "confidence_warnings": confidence_warnings[:10],
    }


def export_weights(
    model: ActionScorerNet,
    output_path: str,
    input_dim: int,
    state_dim: int,
    action_dim: int,
) -> None:
    layers = []
    activation_map = {
        "ReLU": "relu",
        "Sigmoid": "sigmoid",
    }
    modules = list(model.net.children())
    for index, module in enumerate(modules):
        if not isinstance(module, nn.Linear):
            continue
        activation = "relu"
        if index + 1 < len(modules):
            activation = activation_map.get(type(modules[index + 1]).__name__, "relu")
        layers.append(
            {
                "out_features": module.out_features,
                "activation": activation,
                "weights": module.weight.detach().cpu().numpy().tolist(),
                "bias": module.bias.detach().cpu().numpy().tolist(),
            }
        )

    payload = {
        "architecture": "action_mlp",
        "input_dim": input_dim,
        "state_dim": state_dim,
        "action_dim": action_dim,
        "layers": layers,
    }
    with open(output_path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)
    print(f"[export] saved weights to {output_path}")


def train_from_args(args: argparse.Namespace) -> None:
    runtime_config = build_runtime_config(args.device, args.num_threads, args.interop_threads)
    device = runtime_config["device"]

    samples, features, targets, sample_weights, state_dim, action_dim = load_data(
        args.data_dir,
        allow_dirty_matches=args.allow_dirty_matches,
    )
    input_dim = features.shape[1]

    group_ids = [str(sample.get("match_id", sample.get("decision_key", ""))) for sample in samples]
    train_idx, val_idx = build_grouped_split_indices(group_ids, train_ratio=0.8, seed=7)

    train_x = torch.from_numpy(features[train_idx])
    train_y = torch.from_numpy(targets[train_idx])
    train_w = torch.from_numpy(sample_weights[train_idx])
    val_x = torch.from_numpy(features[val_idx]).to(device)
    val_y = torch.from_numpy(targets[val_idx]).to(device)
    val_w = torch.from_numpy(sample_weights[val_idx]).to(device)

    train_loader = DataLoader(
        TensorDataset(train_x, train_y, train_w),
        batch_size=min(args.batch_size, max(len(train_idx), 1)),
        shuffle=True,
        pin_memory=(device.type == "cuda"),
    )

    model = ActionScorerNet(input_dim, args.hidden1, args.hidden2).to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)

    print(
        "[train] input_dim=%d state_dim=%d action_dim=%d hidden1=%d hidden2=%d device=%s"
        % (input_dim, state_dim, action_dim, args.hidden1, args.hidden2, device)
    )
    print(
        "[train] train=%d val=%d epochs=%d"
        % (len(train_idx), len(val_idx), args.epochs)
    )

    for epoch in range(args.epochs):
        model.train()
        train_loss = 0.0
        train_count = 0
        for batch_x, batch_y, batch_w in train_loader:
            batch_x = batch_x.to(device, non_blocking=(device.type == "cuda"))
            batch_y = batch_y.to(device, non_blocking=(device.type == "cuda"))
            batch_w = batch_w.to(device, non_blocking=(device.type == "cuda"))
            optimizer.zero_grad()
            pred = model(batch_x)
            loss_terms = F.binary_cross_entropy(pred, batch_y, reduction="none")
            loss = (loss_terms * batch_w).sum() / batch_w.sum().clamp_min(1e-6)
            loss.backward()
            optimizer.step()
            train_loss += loss.item() * len(batch_x)
            train_count += len(batch_x)

        if (epoch + 1) % 5 == 0 or epoch == 0 or epoch == args.epochs - 1:
            model.eval()
            with torch.no_grad():
                val_pred = model(val_x)
                val_loss_terms = F.binary_cross_entropy(val_pred, val_y, reduction="none")
                val_loss = ((val_loss_terms * val_w).sum() / val_w.sum().clamp_min(1e-6)).item()
            print(
                "  Epoch %3d: train_loss=%.4f, val_loss=%.4f"
                % (epoch + 1, train_loss / max(train_count, 1), val_loss)
            )

    export_weights(model, args.output, input_dim, state_dim, action_dim)

    model.eval()
    with torch.no_grad():
        full_x = torch.from_numpy(features).to(device)
        predictions = model(full_x).detach().cpu().numpy()

    metrics = build_decision_metrics(samples, predictions)
    digest = build_decision_comparison_digest(metrics)
    output_dir = os.path.dirname(args.output) or "."
    metrics_path = os.path.join(output_dir, "decision_metrics.json")
    digest_path = os.path.join(output_dir, "decision_comparison_digest.json")
    with open(metrics_path, "w", encoding="utf-8") as handle:
        json.dump(metrics, handle, indent=2)
    with open(digest_path, "w", encoding="utf-8") as handle:
        json.dump(digest, handle, indent=2)
    print(f"[export] saved decision metrics to {metrics_path}")
    print(f"[export] saved decision digest to {digest_path}")
    print("[done]")


def main() -> None:
    train_from_args(parse_args())


if __name__ == "__main__":
    main()
