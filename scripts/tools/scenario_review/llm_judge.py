from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


SCRIPTS_TOOLS_ROOT = Path(__file__).resolve().parents[1]
if str(SCRIPTS_TOOLS_ROOT) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_TOOLS_ROOT))

from shared.scenario_schema import resolve_path  # noqa: E402


LLM_JUDGE_NAME = "scenario_review_llm_judge"
LLM_JUDGE_VERSION = 1
DEFAULT_CONFIG = {
    "endpoint": "https://zenmux.ai/api/v1",
    "api_key": "",
    "model": "openai/gpt-5.4",
    "timeout_seconds": 60.0,
}
ENV_ENDPOINT = "SCENARIO_REVIEW_ENDPOINT"
ENV_API_KEY = "SCENARIO_REVIEW_API_KEY"
ENV_MODEL = "SCENARIO_REVIEW_MODEL"
ENV_TIMEOUT_SECONDS = "SCENARIO_REVIEW_TIMEOUT_SECONDS"


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Judge scenario review packets with a chat-completions compatible provider and emit "
            "JSONL judgments suitable for import_review_judgments.py."
        ),
    )
    parser.add_argument("--packets-path", required=True, help="Input packets.jsonl from export_review_packets.py.")
    parser.add_argument("--output-path", required=True, help="Output JSONL path for suggested judgments.")
    parser.add_argument("--config-path", help="Optional explicit developer API config JSON path.")
    parser.add_argument("--endpoint", help="Override API endpoint.")
    parser.add_argument("--api-key", help="Override API key.")
    parser.add_argument("--model", help="Override model.")
    parser.add_argument("--timeout-seconds", type=float, help="Override timeout in seconds.")
    return parser.parse_args(argv)


def run_llm_judge(args: argparse.Namespace) -> dict[str, Any]:
    project_root = Path(__file__).resolve().parents[3]
    packets_path = resolve_path(args.packets_path, project_root=project_root)
    output_path = resolve_path(args.output_path, project_root=project_root)
    config = load_api_config(
        project_root=project_root,
        explicit_config_path=args.config_path,
        endpoint=args.endpoint,
        api_key=args.api_key,
        model=args.model,
        timeout_seconds=args.timeout_seconds,
    )

    if not config["api_key"]:
        raise ValueError(
            "Missing API key. Provide --api-key, set %s, or pass --config-path to a developer config file."
            % ENV_API_KEY
        )

    packets = load_packets(packets_path)
    judgments: list[dict[str, Any]] = []
    errors: list[dict[str, Any]] = []

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="\n") as handle:
        for index, packet in enumerate(packets, start=1):
            review_request_id = str(packet.get("review_request_id", "")).strip()
            if not review_request_id:
                errors.append({"packet_index": index, "reason": "missing_review_request_id"})
                continue
            try:
                response = judge_packet(packet, config)
            except Exception as exc:  # noqa: BLE001
                errors.append(
                    {
                        "packet_index": index,
                        "review_request_id": review_request_id,
                        "reason": str(exc),
                    }
                )
                continue

            judgment = {
                "review_request_id": review_request_id,
                "resolution": str(response.get("resolution", "")).strip(),
                "confidence": _coerce_float(response.get("confidence", 0.0), 0.0),
                "reason": str(response.get("reason", "")).strip(),
            }
            judgments.append(judgment)
            handle.write(json.dumps(judgment, ensure_ascii=False))
            handle.write("\n")

    return {
        "judge": LLM_JUDGE_NAME,
        "judge_version": LLM_JUDGE_VERSION,
        "packets_path": str(packets_path),
        "output_path": str(output_path),
        "model": config["model"],
        "endpoint": normalize_endpoint(config["endpoint"]),
        "judgment_count": len(judgments),
        "error_count": len(errors),
        "errors": errors,
    }


def load_api_config(
    *,
    project_root: Path,
    explicit_config_path: str | None,
    endpoint: str | None,
    api_key: str | None,
    model: str | None,
    timeout_seconds: float | None,
) -> dict[str, Any]:
    config = dict(DEFAULT_CONFIG)
    _apply_env_overrides(config)

    config_path: Path | None = None
    if explicit_config_path:
        config_path = resolve_path(explicit_config_path, project_root=project_root)

    if config_path is not None and config_path.exists():
        try:
            parsed = json.loads(config_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            parsed = {}
        if isinstance(parsed, dict):
            for key in ["endpoint", "api_key", "model"]:
                if key in parsed:
                    config[key] = str(parsed[key])
            if "timeout_seconds" in parsed:
                config["timeout_seconds"] = _coerce_float(parsed["timeout_seconds"], config["timeout_seconds"])

    if endpoint:
        config["endpoint"] = endpoint
    if api_key:
        config["api_key"] = api_key
    if model:
        config["model"] = model
    if timeout_seconds is not None:
        config["timeout_seconds"] = timeout_seconds
    return config


def _apply_env_overrides(config: dict[str, Any]) -> None:
    endpoint = os.environ.get(ENV_ENDPOINT, "").strip()
    api_key = os.environ.get(ENV_API_KEY, "").strip()
    model = os.environ.get(ENV_MODEL, "").strip()
    timeout_seconds = os.environ.get(ENV_TIMEOUT_SECONDS, "").strip()
    if endpoint:
        config["endpoint"] = endpoint
    if api_key:
        config["api_key"] = api_key
    if model:
        config["model"] = model
    if timeout_seconds:
        config["timeout_seconds"] = _coerce_float(timeout_seconds, config["timeout_seconds"])


def load_packets(path: Path) -> list[dict[str, Any]]:
    packets: list[dict[str, Any]] = []
    if not path.exists():
        return packets
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.lstrip("\ufeff").strip()
        if not line:
            continue
        parsed = json.loads(line)
        if isinstance(parsed, dict):
            packets.append(parsed)
    return packets


def judge_packet(packet: dict[str, Any], config: dict[str, Any]) -> dict[str, Any]:
    payload = build_chat_payload(packet, config["model"])
    response = request_chat_json(
        endpoint=normalize_endpoint(config["endpoint"]),
        api_key=str(config["api_key"]),
        payload=payload,
        timeout_seconds=float(config["timeout_seconds"]),
    )
    resolution = str(response.get("resolution", "")).strip().lower()
    if resolution not in {"equivalent", "dominant", "worse", "needs_review"}:
        raise ValueError(f"LLM returned invalid resolution: {resolution or '<empty>'}")
    return response


def build_chat_payload(packet: dict[str, Any], model: str) -> dict[str, Any]:
    system_prompt = (
        "You are reviewing whether an AI turn-end state is strategically acceptable versus a human reference. "
        "Compare only the provided end states and diff. Return JSON only."
    )
    user_payload = {
        "review_request_id": packet.get("review_request_id", ""),
        "runner_verdict": packet.get("runner_verdict", {}),
        "expected_end_state": packet.get("expected_end_state", {}),
        "ai_end_state": packet.get("ai_end_state", {}),
        "diff": packet.get("diff", []),
        "instructions": {
            "allowed_resolutions": ["equivalent", "dominant", "worse", "needs_review"],
            "notes": [
                "equivalent means strategically acceptable despite strict mismatch",
                "dominant means AI end state is clearly better",
                "worse means AI end state should not be approved",
                "needs_review means uncertain and should stay pending",
            ],
        },
    }
    return {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": json.dumps(user_payload, ensure_ascii=False)},
        ],
        "temperature": 0,
        "response_format": {
            "type": "json_schema",
            "json_schema": {
                "name": "scenario_review_judgment",
                "strict": True,
                "schema": {
                    "type": "object",
                    "additionalProperties": False,
                    "properties": {
                        "resolution": {
                            "type": "string",
                            "enum": ["equivalent", "dominant", "worse", "needs_review"],
                        },
                        "confidence": {"type": "number"},
                        "reason": {"type": "string"},
                    },
                    "required": ["resolution", "confidence", "reason"],
                },
            },
        },
    }


def request_chat_json(*, endpoint: str, api_key: str, payload: dict[str, Any], timeout_seconds: float) -> dict[str, Any]:
    request = urllib.request.Request(
        endpoint,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
            body = response.read().decode("utf-8")
            status_code = response.getcode()
    except urllib.error.HTTPError as exc:
        raise ValueError(f"HTTP {exc.code}: {exc.read().decode('utf-8', errors='replace')}") from exc
    except urllib.error.URLError as exc:
        raise ValueError(f"request_error: {exc.reason}") from exc

    return parse_chat_response(status_code, body)


def parse_chat_response(status_code: int, response_text: str) -> dict[str, Any]:
    if status_code < 200 or status_code >= 300:
        raise ValueError(f"HTTP {status_code}: {response_text}")
    parsed = json.loads(response_text)
    if not isinstance(parsed, dict):
        raise ValueError("response was not a JSON object")
    choices = parsed.get("choices", [])
    if not isinstance(choices, list) or not choices:
        raise ValueError("response did not include choices")
    first_choice = choices[0]
    if not isinstance(first_choice, dict):
        raise ValueError("response choice was not an object")
    message = first_choice.get("message", {})
    if not isinstance(message, dict):
        raise ValueError("response message was not an object")
    content = str(message.get("content", "")).strip()
    if not content:
        raise ValueError("response content was empty")
    content_parsed = json.loads(content)
    if not isinstance(content_parsed, dict):
        raise ValueError("response content must decode to an object")
    return content_parsed


def normalize_endpoint(endpoint: str) -> str:
    trimmed = endpoint.strip()
    if not trimmed:
        return trimmed
    suffix = "/chat/completions"
    if trimmed.endswith(suffix):
        return trimmed
    return trimmed.rstrip("/\\") + suffix


def _coerce_float(value: Any, default: float) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    report = run_llm_judge(args)
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0 if report["error_count"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
