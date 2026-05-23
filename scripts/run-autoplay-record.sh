#!/usr/bin/env bash
set -euo pipefail

TARGET_WAVE="${1:-12}"
OUTPUT_PATH="${2:-tmp/autoplay-record-wave-${TARGET_WAVE}.md}"
SPEED="${LOVE_AUTOPLAY_SPEED:-12}"
WINDOW_W="${LOVE_WINDOW_W:-1280}"
WINDOW_H="${LOVE_WINDOW_H:-720}"
TIMEOUT_SECONDS="${LOVE_AUTOPLAY_TIMEOUT:-180}"

mkdir -p "$(dirname "$OUTPUT_PATH")"
rm -f "$OUTPUT_PATH"

runner=(love .)
if command -v xvfb-run >/dev/null 2>&1; then
  runner=(xvfb-run -a love .)
fi

LOVE_AUTOPLAY_RECORD=1 \
LOVE_AUTOPLAY_TARGET_WAVE="$TARGET_WAVE" \
LOVE_AUTOPLAY_SPEED="$SPEED" \
LOVE_AUTOPLAY_RECORD_PATH="$OUTPUT_PATH" \
LOVE_WINDOW_W="$WINDOW_W" \
LOVE_WINDOW_H="$WINDOW_H" \
timeout "$TIMEOUT_SECONDS" "${runner[@]}"

printf 'autoplay_record=%s\n' "$OUTPUT_PATH"
