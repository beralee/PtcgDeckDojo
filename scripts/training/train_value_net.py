#!/usr/bin/env python3
"""
Train the PTCG Train value network from exported self-play JSON files.
Exports weights in a GDScript-readable JSON format.
"""

import argparse
import glob
import json
import os
import sys

import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import DataLoader, TensorDataset


class ValueNet(nn.Module):
    def __init__(self, input_dim: int = 30, hidden1: int = 64, hidden2: int = 32):
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
        torch.set_num_interop_threads(interop_threads)


def build_runtime_config(requested_device: str, num_threads: int, interop_threads: int) -> dict:
    device = resolve_device(requested_device)
    configure_torch_threads(num_threads, interop_threads)
    return {
        "device": device,
        "num_threads": num_threads,
        "interop_threads": interop_threads,
    }


def load_data(data_dir: str) -> tuple[np.ndarray, np.ndarray]:
    pattern = os.path.join(data_dir, "game_*.json")
    files = sorted(glob.glob(pattern))
    if not files:
        print(f"[error] no training data files found: {pattern}")
        sys.exit(1)

    all_features = []
    all_results = []
    for fpath in files:
        with open(fpath, "r", encoding="utf-8") as handle:
            data = json.load(handle)
        for record in data.get("records", []):
            features = record.get("features", [])
            result = record.get("result", 0.5)
            if len(features) > 0:
                all_features.append(features)
                all_results.append(result)

    print(f"[data] loaded {len(files)} files, {len(all_features)} records")
    return np.array(all_features, dtype=np.float32), np.array(all_results, dtype=np.float32)


def export_weights(model: ValueNet, output_path: str, input_dim: int) -> None:
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
    parser.add_argument("--device", default="auto", choices=["auto", "cpu", "cuda"], help="training device")
    parser.add_argument("--num-threads", type=int, default=1, help="torch CPU thread cap; 0 keeps default")
    parser.add_argument("--interop-threads", type=int, default=1, help="torch interop thread cap; 0 keeps default")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    runtime_config = build_runtime_config(args.device, args.num_threads, args.interop_threads)
    device = runtime_config["device"]

    features, results = load_data(args.data_dir)
    input_dim = features.shape[1]

    total_count = len(features)
    indices = np.random.permutation(total_count)
    split = int(total_count * 0.8)
    train_idx, val_idx = indices[:split], indices[split:]

    train_x = torch.from_numpy(features[train_idx])
    train_y = torch.from_numpy(results[train_idx])
    val_x = torch.from_numpy(features[val_idx]).to(device)
    val_y = torch.from_numpy(results[val_idx]).to(device)

    train_loader = DataLoader(
        TensorDataset(train_x, train_y),
        batch_size=args.batch_size,
        shuffle=True,
        pin_memory=(device.type == "cuda"),
    )

    model = ValueNet(input_dim, args.hidden1, args.hidden2).to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)
    criterion = nn.BCELoss()

    print(
        "[train] input_dim=%d hidden1=%d hidden2=%d device=%s num_threads=%d interop_threads=%d"
        % (input_dim, args.hidden1, args.hidden2, device, args.num_threads, args.interop_threads)
    )
    print(
        "[train] train=%d val=%d epochs=%d"
        % (len(train_idx), len(val_idx), args.epochs)
    )

    for epoch in range(args.epochs):
        model.train()
        train_loss = 0.0
        train_count = 0
        for batch_x, batch_y in train_loader:
            batch_x = batch_x.to(device, non_blocking=(device.type == "cuda"))
            batch_y = batch_y.to(device, non_blocking=(device.type == "cuda"))
            optimizer.zero_grad()
            pred = model(batch_x)
            loss = criterion(pred, batch_y)
            loss.backward()
            optimizer.step()
            train_loss += loss.item() * len(batch_x)
            train_count += len(batch_x)

        if (epoch + 1) % 10 == 0 or epoch == 0:
            model.eval()
            with torch.no_grad():
                val_pred = model(val_x)
                val_loss = criterion(val_pred, val_y).item()
            print(
                "  Epoch %3d: train_loss=%.4f, val_loss=%.4f"
                % (epoch + 1, train_loss / max(train_count, 1), val_loss)
            )

    export_weights(model, args.output, input_dim)
    print("[done]")


if __name__ == "__main__":
    main()
