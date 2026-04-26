#!/usr/bin/env python3
"""Small ZenMux transport fallback for Godot headless runs.

Godot's Windows headless TLS stack can fail before the API response layer when
the process cannot read the system root store or when a local proxy terminates
TLS differently. This helper keeps the public request contract unchanged: it
only performs the HTTP POST and writes the raw provider response for GDScript to
parse with the normal ZenMuxClient code path.
"""

from __future__ import annotations

import json
import os
import ssl
import sys
import traceback
import urllib.error
import urllib.request


def _load_json(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def _write_json(path: str, payload: dict) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False)


def _build_opener(allow_unsafe_tls: bool) -> urllib.request.OpenerDirector:
    handlers: list[urllib.request.BaseHandler] = [urllib.request.ProxyHandler()]
    if allow_unsafe_tls:
        handlers.append(urllib.request.HTTPSHandler(context=ssl._create_unverified_context()))
    return urllib.request.build_opener(*handlers)


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: zenmux_request.py <input.json> <output.json>", file=sys.stderr)
        return 2

    input_path, output_path = sys.argv[1], sys.argv[2]
    try:
        config = _load_json(input_path)
        url = str(config.get("url", "")).strip()
        api_key = str(config.get("api_key", ""))
        payload = config.get("payload", {})
        timeout_seconds = max(float(config.get("timeout_seconds", 60.0)), 1.0)
        allow_unsafe_tls = bool(config.get("allow_unsafe_tls", True))

        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        request = urllib.request.Request(
            url,
            data=body,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {api_key}",
            },
            method="POST",
        )
        opener = _build_opener(allow_unsafe_tls)
        try:
            with opener.open(request, timeout=timeout_seconds) as response:
                _write_json(output_path, {
                    "ok": True,
                    "http_code": int(response.status),
                    "body": response.read().decode("utf-8", errors="replace"),
                })
                return 0
        except urllib.error.HTTPError as exc:
            _write_json(output_path, {
                "ok": True,
                "http_code": int(exc.code),
                "body": exc.read().decode("utf-8", errors="replace"),
            })
            return 0
    except Exception as exc:  # noqa: BLE001 - transport diagnostics must be complete.
        _write_json(output_path, {
            "ok": False,
            "error_type": "python_transport_error",
            "message": f"{type(exc).__name__}: {exc}",
            "traceback": traceback.format_exc(limit=8),
        })
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
