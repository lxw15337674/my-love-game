#!/usr/bin/env python3
"""Tighten the love.js web export layout for GitHub Pages."""
from __future__ import annotations

import sys
from pathlib import Path

DIST_DIR = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("dist")
INDEX_PATH = DIST_DIR / "index.html"
CSS_PATH = DIST_DIR / "theme" / "love.css"

index = INDEX_PATH.read_text(encoding="utf-8")
index = index.replace(
    '<link rel="stylesheet" type="text/css" href="theme/love.css">',
    '<link rel="stylesheet" type="text/css" href="theme/love.css?v=viewport-fill-v2">',
)
index = index.replace(
    '<canvas id="loadingCanvas" oncontextmenu="event.preventDefault()" width="800" height="600"></canvas>',
    '<canvas id="loadingCanvas" oncontextmenu="event.preventDefault()" width="1920" height="1080"></canvas>',
)
index = index.replace("canvas.scrollWidth", "canvas.width")
index = index.replace("canvas.scrollHeight", "canvas.height")
INDEX_PATH.write_text(index, encoding="utf-8")

CSS_PATH.write_text(
    """* {
    box-sizing: border-box;
}

:root {
    color-scheme: dark;
    background: #050716;
}

html,
body {
    width: 100%;
    height: 100%;
    margin: 0;
    overflow: hidden;
}

body {
    display: grid;
    place-items: center;
    background:
        radial-gradient(circle at 22% 12%, rgba(117, 211, 255, 0.22), transparent 28%),
        radial-gradient(circle at 82% 18%, rgba(177, 126, 255, 0.14), transparent 30%),
        linear-gradient(180deg, #071024 0%, #050716 52%, #03040b 100%);
    color: #dff7ff;
    font-family: Arial, sans-serif;
}

center,
center > div {
    width: 100vw;
    height: 100vh;
    display: grid;
    place-items: center;
}

h1,
footer {
    display: none;
}

/* The canvas must not have border or padding, otherwise mouse coords drift. */
#loadingCanvas,
#canvas {
    display: block;
    width: min(100vw, calc(100vh * 16 / 9));
    height: min(100vh, calc(100vw * 9 / 16));
    max-width: 100vw;
    max-height: 100vh;
    border: 0;
    padding: 0;
    margin: 0;
    background: #050716;
    image-rendering: pixelated;
    image-rendering: crisp-edges;
}

#canvas {
    visibility: hidden;
}
""",
    encoding="utf-8",
)

print(f"Patched love.js web layout in {DIST_DIR}")
