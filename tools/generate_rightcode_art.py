#!/usr/bin/env python3
"""Generate game art through Right Code draw API.

The script intentionally reads credentials from environment variables only.
Do not commit real API keys.

Required:
  RIGHTCODE_API_KEY or RC_DRAW_API_KEY

Defaults:
  base url: https://www.right.codes/draw
  model: gpt-image-2
  size: 1024x1024
  response_format: url
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

DEFAULT_BASE_URL = "https://www.right.codes/draw"
DEFAULT_MODEL = "gpt-image-2"
DEFAULT_PROMPT = """Game-ready transparent PNG sprite sheet for a 2D top-down arena roguelite named Heartcore Survivor. Clean high-contrast stylized sci-fi fantasy, readable at small size, not pixel art, not realistic, no text, no UI. Transparent background. Neat grid with generous spacing. Assets: glowing heart-core player, small splinter enemy, red drifter enemy, green armored shell enemy, cyan arc wisp enemy, purple elite shade enemy, large boss heartbreak core, gold coin pickup, green XP crystal pickup, shield orb pickup, star needle bullet, swarm mini missile, molten fire orb, echo blade, arc lightning bolt, void orb. Consistent icon perspective, strong silhouettes, subtle glow, crisp edges. No square placeholder shapes."""


def getenv_key() -> str:
    key = os.environ.get("RIGHTCODE_API_KEY") or os.environ.get("RC_DRAW_API_KEY")
    if not key:
        raise SystemExit("Missing RIGHTCODE_API_KEY or RC_DRAW_API_KEY. Refusing to read keys from files or arguments.")
    return key


def request_json(url: str, api_key: str, payload: dict[str, Any], timeout: int) -> dict[str, Any]:
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "my-love-game-art-generator/1.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"RightCode API HTTP {exc.code}: {detail[:1000]}") from exc
    except urllib.error.URLError as exc:
        raise SystemExit(f"RightCode API connection failed: {exc}") from exc

    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"RightCode API returned non-JSON response: {raw[:1000]}") from exc


def first_image_payload(data: dict[str, Any]) -> tuple[str, str]:
    items = data.get("data")
    if not isinstance(items, list) or not items:
        raise SystemExit(f"No image data in response: {json.dumps(data, ensure_ascii=False)[:1000]}")
    item = items[0]
    if not isinstance(item, dict):
        raise SystemExit("Unexpected image item in response")
    if item.get("url"):
        return "url", str(item["url"])
    if item.get("b64_json"):
        return "b64", str(item["b64_json"])
    if item.get("base64"):
        return "b64", str(item["base64"])
    raise SystemExit(f"No url/base64 image field in response item: {json.dumps(item, ensure_ascii=False)[:1000]}")


def download_url(url: str, out_path: Path, timeout: int) -> None:
    req = urllib.request.Request(url, headers={"User-Agent": "my-love-game-art-generator/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            out_path.write_bytes(resp.read())
    except urllib.error.URLError as exc:
        raise SystemExit(f"Image download failed: {exc}") from exc


def write_b64(payload: str, out_path: Path) -> None:
    if payload.startswith("data:"):
        payload = payload.split(",", 1)[1]
    out_path.write_bytes(base64.b64decode(payload))


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Heartcore Survivor art via Right Code draw API")
    parser.add_argument("--prompt", default=DEFAULT_PROMPT, help="Image prompt")
    parser.add_argument("--prompt-file", type=Path, help="Read prompt from UTF-8 text file")
    parser.add_argument("--model", default=os.environ.get("RC_DRAW_MODEL", DEFAULT_MODEL))
    parser.add_argument("--size", default=os.environ.get("RC_DRAW_SIZE", "1024x1024"))
    parser.add_argument("--base-url", default=os.environ.get("RC_DRAW_BASE_URL", DEFAULT_BASE_URL))
    parser.add_argument("--output", type=Path, default=Path("assets/generated/heartcore_generated.png"))
    parser.add_argument("--response-format", default="url", choices=["url", "b64_json"])
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--dry-run", action="store_true", help="Validate request shape without calling API")
    args = parser.parse_args()

    prompt = args.prompt_file.read_text(encoding="utf-8") if args.prompt_file else args.prompt
    endpoint = args.base_url.rstrip("/") + "/v1/images/generations"
    payload = {
        "model": args.model,
        "prompt": prompt,
        "size": args.size,
        "response_format": args.response_format,
    }

    if args.dry_run:
        safe_payload = dict(payload)
        safe_payload["prompt"] = safe_payload["prompt"][:160] + ("..." if len(safe_payload["prompt"]) > 160 else "")
        print(json.dumps({"endpoint": endpoint, "payload": safe_payload}, ensure_ascii=False, indent=2))
        return 0

    api_key = getenv_key()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    data = request_json(endpoint, api_key, payload, args.timeout)
    kind, value = first_image_payload(data)
    if kind == "url":
        download_url(value, args.output, args.timeout)
    else:
        write_b64(value, args.output)

    meta = {
        "created_at": int(time.time()),
        "endpoint": endpoint,
        "model": args.model,
        "size": args.size,
        "output": str(args.output),
        "response_kind": kind,
        "prompt": prompt,
    }
    args.output.with_suffix(args.output.suffix + ".json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    print(args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
