#!/usr/bin/env python3
"""
Train the PTCG Train value network from exported self-play JSON files.
Exports weights in a GDScript-readable JSON format.

Supports:
- automatic input-dim detection for deck-specific encoders
- optional third hidden layer
- optional teacher distillation from hand-written board evaluation
- grouped train/val splitting by match id
- optional ingestion of top-level decision states and interaction states
- dirty-match filtering so stalled/capped/unsupported games do not poison training
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


class ValueNet(nn.Module):
    def __init__(self, input_dim: int = 30, hidden1: int = 64, hidden2: int = 32, hidden3: int = 0):
        super().__init__()
        layers: list[nn.Module] = [
            nn.Linear(input_dim, hidden1),
            nn.ReLU(),
            nn.Linear(hidden1, hidden2),
            nn.ReLU(),
        ]
        if hidden3 > 0:
            layers.extend(
                [
                    nn.Linear(hidden2, hidden3),
                    nn.ReLU(),
                    nn.Linear(hidden3, 1),
                ]
            )
        else:
            layers.append(nn.Linear(hidden2, 1))
        layers.append(nn.Sigmoid())
        self.net = nn.Sequential(*layers)

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
        train_idx.extend(grouped_indices[shuffled_groups[0]])
    if not val_idx:
        val_idx.extend(grouped_indices[shuffled_groups[-1]])
    return train_idx, val_idx


def _normalize_failure_reason(payload: dict) -> str:
    return str(payload.get("failure_reason", "")).strip()


def _match_is_dirty(payload: dict) -> bool:
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


def load_data(
    data_dir: str,
    decision_data_dir: str = "",
    decision_state_weight: float = 0.75,
    interaction_state_weight: float = 0.5,
    allow_dirty_matches: bool = False,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray, str, int]:
    """Load training data and optional decision-state samples.

    Returns:
        features, results, teacher_scores, sample_weights, group_ids, encoder_name, feature_dim
    """
    pattern = os.path.join(data_dir, "game_*.json")
    files = sorted(glob.glob(pattern))
    if not files:
        print(f"[error] no training data files found: {pattern}")
        sys.exit(1)

    all_features: list[list[float]] = []
    all_results: list[float] = []
    all_teacher_scores: list[float] = []
    all_sample_weights: list[float] = []
    all_group_ids: list[str] = []
    encoder_name = "generic"
    feature_dim = 0
    skipped_dirty_games = 0
    self_play_records = 0
    decision_records = 0
    interaction_records = 0

    for fpath in files:
        with open(fpath, "r", encoding="utf-8") as handle:
            payload = json.load(handle)
        if not allow_dirty_matches and _match_is_dirty(payload):
            skipped_dirty_games += 1
            continue
        if payload.get("encoder"):
            encoder_name = str(payload["encoder"])
        if payload.get("feature_dim"):
            feature_dim = int(payload["feature_dim"])
        match_id = str(payload.get("meta", {}).get("match_id", os.path.basename(fpath)))
        match_weight = max(0.0, _payload_match_quality_weight(payload))
        for record in payload.get("records", []):
            features = record.get("features", [])
            if not features:
                continue
            if feature_dim <= 0:
                feature_dim = len(features)
            if len(features) != feature_dim:
                continue
            all_features.append([float(v) for v in features])
            all_results.append(float(record.get("result", 0.5)))
            all_teacher_scores.append(float(record.get("teacher_score", -1.0)))
            all_sample_weights.append(match_weight)
            all_group_ids.append(match_id)
            self_play_records += 1

    if decision_data_dir:
        decision_pattern = os.path.join(decision_data_dir, "*.json")
        for fpath in sorted(glob.glob(decision_pattern)):
            with open(fpath, "r", encoding="utf-8") as handle:
                payload = json.load(handle)
            if not allow_dirty_matches and _match_is_dirty(payload):
                continue
            match_id = str(payload.get("meta", {}).get("match_id", os.path.splitext(os.path.basename(fpath))[0]))
            match_weight = max(0.0, _payload_match_quality_weight(payload))
            for record in payload.get("records", []):
                state_features = record.get("state_features", [])
                if not state_features:
                    continue
                if feature_dim <= 0:
                    feature_dim = len(state_features)
                if len(state_features) != feature_dim:
                    continue
                all_features.append([float(v) for v in state_features])
                all_results.append(float(record.get("result", 0.5)))
                all_teacher_scores.append(-1.0)
                all_sample_weights.append(match_weight * float(decision_state_weight))
                all_group_ids.append(match_id)
                decision_records += 1
            for record in payload.get("interaction_records", []):
                state_features = record.get("state_features", [])
                if not state_features:
                    continue
                if feature_dim <= 0:
                    feature_dim = len(state_features)
                if len(state_features) != feature_dim:
                    continue
                all_features.append([float(v) for v in state_features])
                all_results.append(float(record.get("result", 0.5)))
                all_teacher_scores.append(-1.0)
                all_sample_weights.append(match_weight * float(interaction_state_weight))
                all_group_ids.append(match_id)
                interaction_records += 1

    if not all_features:
        print(f"[error] no usable value samples found in {data_dir}")
        sys.exit(1)

    print(
        "[data] self_play_files=%d self_play_records=%d decision_records=%d interaction_records=%d skipped_dirty_games=%d encoder=%s"
        % (len(files), self_play_records, decision_records, interaction_records, skipped_dirty_games, encoder_name)
    )
    features_arr = np.array(all_features, dtype=np.float32)
    if feature_dim == 0:
        feature_dim = int(features_arr.shape[1])
    return (
        features_arr,
        np.array(all_results, dtype=np.float32),
        np.array(all_teacher_scores, dtype=np.float32),
        np.array(all_sample_weights, dtype=np.float32),
        np.array(all_group_ids, dtype=object),
        encoder_name,
        feature_dim,
    )


def export_weights(model: ValueNet, output_path: str, input_dim: int, encoder_name: str = "", feature_dim: int = 0) -> None:
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

    data = {
        "architecture": "mlp",
        "input_dim": input_dim,
        "layers": layers,
    }
    if encoder_name:
        data["encoder_name"] = encoder_name
    if feature_dim > 0:
        data["feature_dim"] = feature_dim

    with open(output_path, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2)
    print(f"[export] saved weights to {output_path}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train the PTCG Train value network")
    parser.add_argument("--data-dir", required=True, help="training data directory")
    parser.add_argument("--output", default="value_net_weights.json", help="output weights path")
    parser.add_argument("--epochs", type=int, default=100, help="training epochs")
    parser.add_argument("--batch-size", type=int, default=256, help="batch size")
    parser.add_argument("--lr", type=float, default=0.001, help="learning rate")
    parser.add_argument("--hidden1", type=int, default=64, help="first hidden layer size")
    parser.add_argument("--hidden2", type=int, default=32, help="second hidden layer size")
    parser.add_argument("--hidden3", type=int, default=0, help="third hidden layer size (0=disabled)")
    parser.add_argument("--teacher-weight", type=float, default=0.0, help="teacher distillation weight (0=disabled)")
    parser.add_argument("--decision-data-dir", default="", help="optional decision sample directory to add decision-state samples")
    parser.add_argument("--decision-state-weight", type=float, default=0.75, help="sample weight multiplier for top-level decision states")
    parser.add_argument("--interaction-state-weight", type=float, default=0.5, help="sample weight multiplier for interaction states")
    parser.add_argument("--allow-dirty-matches", action="store_true", help="keep matches that ended via cap/stall/unsupported failures")
    parser.add_argument("--patience", type=int, default=10, help="early stopping patience")
    parser.add_argument("--device", default="auto", choices=["auto", "cpu", "cuda"], help="training device")
    parser.add_argument("--num-threads", type=int, default=1, help="torch CPU thread cap; 0 keeps default")
    parser.add_argument("--interop-threads", type=int, default=1, help="torch interop thread cap; 0 keeps default")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    runtime_config = build_runtime_config(args.device, args.num_threads, args.interop_threads)
    device = runtime_config["device"]

    features, results, teacher_scores, sample_weights, group_ids, encoder_name, feature_dim = load_data(
        args.data_dir,
        decision_data_dir=args.decision_data_dir,
        decision_state_weight=args.decision_state_weight,
        interaction_state_weight=args.interaction_state_weight,
        allow_dirty_matches=args.allow_dirty_matches,
    )
    input_dim = features.shape[1]

    has_teacher = args.teacher_weight > 0 and np.any(teacher_scores >= 0)
    teacher_weight = args.teacher_weight if has_teacher else 0.0

    train_idx, val_idx = build_grouped_split_indices(group_ids.tolist(), train_ratio=0.8, seed=7)

    train_x = torch.from_numpy(features[train_idx])
    train_y = torch.from_numpy(results[train_idx])
    train_t = torch.from_numpy(teacher_scores[train_idx])
    train_w = torch.from_numpy(sample_weights[train_idx])
    val_x = torch.from_numpy(features[val_idx]).to(device)
    val_y = torch.from_numpy(results[val_idx]).to(device)
    val_t = torch.from_numpy(teacher_scores[val_idx]).to(device)
    val_w = torch.from_numpy(sample_weights[val_idx]).to(device)

    train_loader = DataLoader(
        TensorDataset(train_x, train_y, train_t, train_w),
        batch_size=args.batch_size,
        shuffle=True,
        pin_memory=(device.type == "cuda"),
    )

    model = ValueNet(input_dim, args.hidden1, args.hidden2, args.hidden3).to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)

    hidden3_str = f" hidden3={args.hidden3}" if args.hidden3 > 0 else ""
    teacher_str = f" teacher_weight={teacher_weight:.2f}" if teacher_weight > 0 else ""
    print(
        f"[train] input_dim={input_dim} hidden1={args.hidden1} hidden2={args.hidden2}{hidden3_str} "
        f"device={device} num_threads={args.num_threads} interop_threads={args.interop_threads}{teacher_str}"
    )
    print(f"[train] train={len(train_idx)} val={len(val_idx)} epochs={args.epochs} patience={args.patience}")

    best_val_loss = float("inf")
    patience_counter = 0
    best_state = None

    for epoch in range(args.epochs):
        model.train()
        train_loss = 0.0
        train_count = 0
        for batch_x, batch_y, batch_t, batch_w in train_loader:
            batch_x = batch_x.to(device, non_blocking=(device.type == "cuda"))
            batch_y = batch_y.to(device, non_blocking=(device.type == "cuda"))
            batch_t = batch_t.to(device, non_blocking=(device.type == "cuda"))
            batch_w = batch_w.to(device, non_blocking=(device.type == "cuda"))
            optimizer.zero_grad()
            pred = model(batch_x)
            loss_bce_terms = F.binary_cross_entropy(pred, batch_y, reduction="none")
            loss_bce = (loss_bce_terms * batch_w).sum() / batch_w.sum().clamp_min(1e-6)
            loss = loss_bce
            if teacher_weight > 0:
                teacher_mask = batch_t >= 0
                if teacher_mask.any():
                    teacher_terms = F.mse_loss(pred[teacher_mask], batch_t[teacher_mask], reduction="none")
                    teacher_weights = batch_w[teacher_mask]
                    loss_teacher = (teacher_terms * teacher_weights).sum() / teacher_weights.sum().clamp_min(1e-6)
                    loss = (1.0 - teacher_weight) * loss_bce + teacher_weight * loss_teacher
            loss.backward()
            optimizer.step()
            train_loss += loss.item() * len(batch_x)
            train_count += len(batch_x)

        model.eval()
        with torch.no_grad():
            val_pred = model(val_x)
            val_loss_bce_terms = F.binary_cross_entropy(val_pred, val_y, reduction="none")
            val_loss_bce = ((val_loss_bce_terms * val_w).sum() / val_w.sum().clamp_min(1e-6)).item()
            val_loss = val_loss_bce
            if teacher_weight > 0:
                val_teacher_mask = val_t >= 0
                if val_teacher_mask.any():
                    val_teacher_terms = F.mse_loss(val_pred[val_teacher_mask], val_t[val_teacher_mask], reduction="none")
                    val_teacher_weights = val_w[val_teacher_mask]
                    val_loss_teacher = (
                        (val_teacher_terms * val_teacher_weights).sum() / val_teacher_weights.sum().clamp_min(1e-6)
                    ).item()
                    val_loss = (1.0 - teacher_weight) * val_loss_bce + teacher_weight * val_loss_teacher

        if (epoch + 1) % 10 == 0 or epoch == 0:
            print("  Epoch %3d: train_loss=%.4f, val_loss=%.4f" % (epoch + 1, train_loss / max(train_count, 1), val_loss))

        if val_loss < best_val_loss:
            best_val_loss = val_loss
            patience_counter = 0
            best_state = {key: value.cpu().clone() for key, value in model.state_dict().items()}
        else:
            patience_counter += 1
            if patience_counter >= args.patience:
                print(f"  [early stop] val_loss did not improve for {args.patience} epochs, stopping at epoch {epoch + 1}")
                break

    if best_state is not None:
        model.load_state_dict(best_state)
        model = model.to(device)
    print(f"  [best] val_loss={best_val_loss:.4f}")

    export_weights(model, args.output, input_dim, encoder_name, feature_dim)
    print("[done]")


if __name__ == "__main__":
    main()
