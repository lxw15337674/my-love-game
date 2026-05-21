# Stardrift Promise

A small original arcade game built with LÖVE 11.x.

You pilot a heart-shaped star through a drifting night sky. Collect the letters `L O V E` in order, avoid void shards, then reach the glowing heart gate to complete the promise.

## Run

Install LÖVE 11.x, then run:

```bash
love .
```

## Controls

- `Enter` - start / restart
- `WASD` or arrow keys - move
- Hold left mouse button - pull the heart toward the cursor
- `P` or `Space` - pause / resume
- `R` - restart instantly
- `Esc` - quit

## Gameplay

- Collect golden letter orbs in order: `L`, `O`, `V`, `E`.
- Pink hearts give points and keep your combo alive.
- Red void shards damage you.
- After collecting all four letters, fly into the heart gate on the right side.

## Project

This repository intentionally uses no external art or audio assets. All visuals are drawn procedurally in `main.lua`, so the game is lightweight and easy to run.

## Files

- `main.lua` - complete game loop, rendering, input, collision, scoring, and states
- `conf.lua` - LÖVE window/module configuration
