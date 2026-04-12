#!/usr/bin/env python3
"""
Train an interaction-target scorer from exported decision sample JSON files.
The scorer learns to rank candidate interaction targets for search/discard/
assignment/slot-selection style prompts.
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


class InteractionScorerNet(nn.Module):
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
        train_idx.extend(grouped_indices[shuffled_groups[0]])
    if not val_idx:
        val_idx.extend(grouped_indices[shuffled_groups[-1]])
    return train_idx, val_idx


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train the PTCG Train interaction scorer")
    parser.add_argument("--data-dir", required=True, help="decision sample directory")
    parser.add_argument("--output", default="interaction_scorer_weights.json", help="output weights path")
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


def _normalize_step_key(step_id: str, step_type: str) -> str:
    normalized_step_id = str(step_id).strip().lower()
    if normalized_step_id:
        return normalized_step_id
    return str(step_type).strip().lower()


def _interaction_step_weight(deck_identity: str, step_id: str, step_type: str) -> float:
    step_key = _normalize_step_key(step_id, step_type)
    weight = 1.0
    if step_key in {"embrace_target"}:
        weight *= 3.0
    elif step_key in {"assignment_target", "card_assignment"}:
        weight *= 2.4
    elif step_key in {"counter_distribution"}:
        weight *= 3.2
    elif step_key in {"search_cards", "search_pokemon", "search_item", "search_tool"}:
        weight *= 1.35
    elif step_key in {"discard_energy", "discard_cards"}:
        weight *= 1.2
    elif step_key in {"field_slot"}:
        weight *= 1.15
    deck_key = str(deck_identity).strip().lower()
    if deck_key == "gardevoir":
        if step_key in {"embrace_target"}:
            weight *= 1.4
        elif step_key in {"assignment_target", "card_assignment"}:
            weight *= 1.25
        elif step_key in {"counter_distribution"}:
            weight *= 1.35
    return weight


def _build_target(score_rank: float, record_result: float, chosen: bool) -> tuple[float, float]:
    normalized_rank = max(0.0, min(1.0, float(score_rank)))
    result = max(0.0, min(1.0, float(record_result)))
    chosen_signal = (0.15 + 0.75 * result) if chosen else 0.0
    target = max(0.0, min(1.0, 0.25 * normalized_rank + 0.75 * chosen_signal))
    return target, target


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


def load_data(data_dir: str, allow_dirty_matches: bool = False) -> tuple[list[dict], np.ndarray, np.ndarray, np.ndarray, int, int]:
    pattern = os.path.join(data_dir, "*.json")
    files = sorted(glob.glob(pattern))
    if not files:
        print(f"[error] no decision sample files found: {pattern}")
        sys.exit(1)

    flat_samples: list[dict] = []
    rows: list[list[float]] = []
    targets: list[float] = []
    sample_weights: list[float] = []
    state_dim = -1
    interaction_dim = -1

    for path in files:
        with open(path, "r", encoding="utf-8") as handle:
            payload = json.load(handle)
        if not allow_dirty_matches and _payload_is_dirty(payload):
            continue
        payload_weight = max(0.0, _payload_match_quality_weight(payload))
        for record in payload.get("interaction_records", []):
            state_features = [float(v) for v in record.get("state_features", [])]
            candidates = record.get("candidates", [])
            if not state_features or not isinstance(candidates, list) or not candidates:
                continue
            deck_identity = str(
                record.get(
                    "deck_identity",
                    payload.get("meta", {}).get("deck_identity", "unknown"),
                )
            )
            step_id = str(record.get("step_id", ""))
            step_type = str(record.get("step_type", ""))
            step_weight = _interaction_step_weight(deck_identity, step_id, step_type)
            candidate_scores = [float(candidate.get("strategy_score", 0.0)) for candidate in candidates]
            normalized_scores = _normalize_scores(candidate_scores)
            decision_key = "%s:%s:%s:%s:%s" % (
                str(record.get("match_id", os.path.splitext(os.path.basename(path))[0])),
                str(record.get("interaction_id", "")),
                str(record.get("turn_number", "")),
                str(record.get("player_index", "")),
                str(record.get("step_id", record.get("step_type", ""))),
            )
            for candidate_index, candidate in enumerate(candidates):
                interaction_vector = candidate.get("interaction_vector", [])
                if not interaction_vector:
                    continue
                if state_dim < 0:
                    state_dim = len(state_features)
                if interaction_dim < 0:
                    interaction_dim = len(interaction_vector)
                if len(state_features) != state_dim or len(interaction_vector) != interaction_dim:
                    continue
                chosen = bool(candidate.get("chosen", False))
                target, oracle_score = _build_target(
                    normalized_scores[candidate_index],
                    float(record.get("result", 0.5)),
                    chosen,
                )
                candidate_weight = payload_weight * step_weight
                if chosen:
                    candidate_weight *= 1.15
                flat_samples.append(
                    {
                        "match_id": str(record.get("match_id", os.path.splitext(os.path.basename(path))[0])),
                        "decision_key": decision_key,
                        "deck_identity": deck_identity,
                        "step_id": step_id,
                        "step_type": step_type,
                        "candidate_index": int(candidate.get("candidate_index", candidate_index)),
                        "chosen": chosen,
                        "result": float(record.get("result", 0.5)),
                        "target": float(target),
                        "oracle_score": float(oracle_score),
                        "strategy_score": float(candidate.get("strategy_score", 0.0)),
                        "sample_weight": float(candidate_weight),
                    }
                )
                rows.append(state_features + [float(v) for v in interaction_vector])
                targets.append(target)
                sample_weights.append(candidate_weight)

    if not flat_samples or not rows or state_dim <= 0 or interaction_dim <= 0:
        print(f"[error] no usable interaction samples found in {data_dir}")
        sys.exit(1)

    print(f"[data] loaded {len(files)} files, {len(flat_samples)} interaction samples")
    return (
        flat_samples,
        np.array(rows, dtype=np.float32),
        np.array(targets, dtype=np.float32),
        np.array(sample_weights, dtype=np.float32),
        state_dim,
        interaction_dim,
    )


def export_weights(
    model: InteractionScorerNet,
    output_path: str,
    input_dim: int,
    state_dim: int,
    interaction_dim: int,
) -> None:
    layers = []
    activation_map = {"ReLU": "relu", "Sigmoid": "sigmoid"}
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
        "architecture": "interaction_mlp",
        "input_dim": input_dim,
        "state_dim": state_dim,
        "interaction_dim": interaction_dim,
        "layers": layers,
    }
    with open(output_path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)
    print(f"[export] saved weights to {output_path}")


def _entry_key(sample: dict) -> int:
    return int(sample.get("candidate_index", 0))


def _mean(values: list[float]) -> float:
    if not values:
        return 0.0
    return float(sum(values)) / float(len(values))


def _build_interaction_decision_summaries(samples: list[dict], predictions: np.ndarray) -> list[dict]:
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
                float(entry.get("target", entry.get("oracle_score", 0.0))),
                float(entry.get("strategy_score", 0.0)),
                -int(entry.get("candidate_index", 0)),
            ),
            reverse=True,
        )
        strategy_sorted = sorted(
            entries,
            key=lambda entry: (
                float(entry.get("strategy_score", 0.0)),
                float(entry.get("target", 0.0)),
                -int(entry.get("candidate_index", 0)),
            ),
            reverse=True,
        )
        model_sorted = sorted(
            entries,
            key=lambda entry: (
                float(entry.get("predicted_value", 0.0)),
                float(entry.get("strategy_score", 0.0)),
                -int(entry.get("candidate_index", 0)),
            ),
            reverse=True,
        )
        chosen_entry = next((entry for entry in entries if entry.get("chosen", False)), oracle_sorted[0])
        oracle_key = _entry_key(oracle_sorted[0])
        strategy_key = _entry_key(strategy_sorted[0])
        chosen_key = _entry_key(chosen_entry)
        model_keys = [_entry_key(entry) for entry in model_sorted]
        strategy_keys = [_entry_key(entry) for entry in strategy_sorted]
        oracle_keys = [_entry_key(entry) for entry in oracle_sorted]
        model_margin = float(model_sorted[0].get("predicted_value", 0.0))
        if len(model_sorted) > 1:
            model_margin -= float(model_sorted[1].get("predicted_value", 0.0))
        strategy_margin = float(strategy_sorted[0].get("strategy_score", 0.0))
        if len(strategy_sorted) > 1:
            strategy_margin -= float(strategy_sorted[1].get("strategy_score", 0.0))
        decision_summaries.append(
            {
                "decision_key": decision_key,
                "step_id": str(entries[0].get("step_id", "")),
                "step_type": str(entries[0].get("step_type", "")),
                "sample_count": len(entries),
                "sample_weight": _mean([float(entry.get("sample_weight", 1.0)) for entry in entries]),
                "model_top1_hit": 1.0 if model_keys[0] == oracle_key else 0.0,
                "model_top3_hit": 1.0 if oracle_key in model_keys[:3] else 0.0,
                "strategy_top1_hit": 1.0 if strategy_key == oracle_key else 0.0,
                "strategy_top3_hit": 1.0 if oracle_key in strategy_keys[:3] else 0.0,
                "chosen_matches_oracle": 1.0 if chosen_key == oracle_key else 0.0,
                "avg_result": float(chosen_entry.get("result", 0.0)),
                "avg_oracle_score": float(oracle_sorted[0].get("oracle_score", oracle_sorted[0].get("target", 0.0))),
                "avg_target": float(oracle_sorted[0].get("target", 0.0)),
                "avg_predicted_value": float(model_sorted[0].get("predicted_value", 0.0)),
                "avg_strategy_score": float(chosen_entry.get("strategy_score", 0.0)),
                "avg_learned_score": float(chosen_entry.get("predicted_value", 0.0)),
                "avg_margin_vs_next_best": model_margin,
                "avg_strategy_margin_vs_next_best": strategy_margin,
                "avg_model_rank_of_chosen": float(model_keys.index(chosen_key) + 1),
                "avg_strategy_rank_of_chosen": float(strategy_keys.index(chosen_key) + 1),
                "avg_chosen_rank_by_target": float(oracle_keys.index(chosen_key) + 1),
            }
        )
    return decision_summaries


def _aggregate_interaction_summaries(decision_summaries: list[dict]) -> dict:
    sample_weights = [float(summary.get("sample_weight", 1.0)) for summary in decision_summaries]

    def _weighted_mean(key: str) -> float:
        if not decision_summaries:
            return 0.0
        total_weight = sum(sample_weights)
        if total_weight <= 0.0:
            return _mean([float(summary.get(key, 0.0)) for summary in decision_summaries])
        weighted_sum = 0.0
        for summary, weight in zip(decision_summaries, sample_weights):
            weighted_sum += float(summary.get(key, 0.0)) * weight
        return weighted_sum / total_weight

    return {
        "sample_count": int(sum(int(summary.get("sample_count", 0)) for summary in decision_summaries)),
        "decision_count": len(decision_summaries),
        "weighted_decision_count": float(sum(sample_weights)),
        "model_top1_hit_rate": _weighted_mean("model_top1_hit"),
        "model_top3_hit_rate": _weighted_mean("model_top3_hit"),
        "strategy_top1_hit_rate": _weighted_mean("strategy_top1_hit"),
        "strategy_top3_hit_rate": _weighted_mean("strategy_top3_hit"),
        "top1_gain_vs_strategy": _weighted_mean("model_top1_hit") - _weighted_mean("strategy_top1_hit"),
        "top3_gain_vs_strategy": _weighted_mean("model_top3_hit") - _weighted_mean("strategy_top3_hit"),
        "avg_result": _weighted_mean("avg_result"),
        "avg_oracle_score": _weighted_mean("avg_oracle_score"),
        "avg_target": _weighted_mean("avg_target"),
        "avg_predicted_value": _weighted_mean("avg_predicted_value"),
        "avg_strategy_score": _weighted_mean("avg_strategy_score"),
        "avg_learned_score": _weighted_mean("avg_learned_score"),
        "avg_margin_vs_next_best": _weighted_mean("avg_margin_vs_next_best"),
        "avg_strategy_margin_vs_next_best": _weighted_mean("avg_strategy_margin_vs_next_best"),
        "avg_model_rank_of_chosen": _weighted_mean("avg_model_rank_of_chosen"),
        "avg_strategy_rank_of_chosen": _weighted_mean("avg_strategy_rank_of_chosen"),
        "avg_chosen_rank_by_target": _weighted_mean("avg_chosen_rank_by_target"),
        "oracle_chosen_rate": _weighted_mean("chosen_matches_oracle"),
    }


def build_interaction_metrics(samples: list[dict], predictions: np.ndarray) -> dict:
    decision_summaries = _build_interaction_decision_summaries(samples, predictions)
    by_step_type: dict[str, dict] = {}
    grouped: dict[str, list[dict]] = defaultdict(list)
    for summary in decision_summaries:
        grouped[str(summary.get("step_type", summary.get("step_id", "unknown")))].append(summary)
    for step_type, grouped_summaries in grouped.items():
        by_step_type[step_type] = _aggregate_interaction_summaries(grouped_summaries)
    return {
        "overall": _aggregate_interaction_summaries(decision_summaries),
        "by_step_type": by_step_type,
    }


def build_interaction_comparison_digest(metrics: dict) -> dict:
    overall = dict(metrics.get("overall", {}))
    warnings = []
    for step_type, values in metrics.get("by_step_type", {}).items():
        if int(values.get("decision_count", 0)) < 16:
            warnings.append({"kind": "low_sample_step_type", "step_type": step_type, "decision_count": int(values.get("decision_count", 0))})
    digest = {
        "overall_summary": overall,
        "confidence_warnings": warnings,
    }
    if metrics.get("by_step_type"):
        ranked = []
        for step_type, values in metrics["by_step_type"].items():
            row = dict(values)
            row["step_type"] = step_type
            ranked.append(row)
        ranked.sort(key=lambda row: (float(row.get("top1_gain_vs_strategy", 0.0)), float(row.get("top3_gain_vs_strategy", 0.0))), reverse=True)
        digest["best_step_types"] = ranked[:5]
        digest["worst_step_types"] = list(reversed(ranked[-5:])) if ranked else []
    return digest


def train_from_args(args: argparse.Namespace) -> None:
    device = resolve_device(args.device)
    configure_torch_threads(args.num_threads, args.interop_threads)

    samples, features, targets, sample_weights, state_dim, interaction_dim = load_data(
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

    model = InteractionScorerNet(input_dim, args.hidden1, args.hidden2).to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)

    print(
        "[train] input_dim=%d state_dim=%d interaction_dim=%d hidden1=%d hidden2=%d device=%s"
        % (input_dim, state_dim, interaction_dim, args.hidden1, args.hidden2, device)
    )
    print("[train] train=%d val=%d epochs=%d" % (len(train_idx), len(val_idx), args.epochs))

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
            print("  Epoch %3d: train_loss=%.4f, val_loss=%.4f" % (epoch + 1, train_loss / max(train_count, 1), val_loss))

    model.eval()
    with torch.no_grad():
        predictions = model(torch.from_numpy(features).to(device)).detach().cpu().numpy()

    export_weights(model, args.output, input_dim, state_dim, interaction_dim)
    metrics = build_interaction_metrics(samples, predictions)
    digest = build_interaction_comparison_digest(metrics)
    output_dir = os.path.dirname(os.path.abspath(args.output))
    metrics_path = os.path.join(output_dir, "interaction_metrics.json")
    digest_path = os.path.join(output_dir, "interaction_comparison_digest.json")
    with open(metrics_path, "w", encoding="utf-8") as handle:
        json.dump(metrics, handle, indent=2)
    with open(digest_path, "w", encoding="utf-8") as handle:
        json.dump(digest, handle, indent=2)
    print(f"[metrics] wrote interaction metrics to {metrics_path}")
    print(f"[metrics] wrote interaction digest to {digest_path}")
    print("[done]")


def main() -> None:
    train_from_args(parse_args())


if __name__ == "__main__":
    main()
