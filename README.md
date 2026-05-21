# Heartcore Survivor Prototype

A small LÖVE 11.x arena roguelite prototype.

Design direction:

- Short 30-second survival waves
- Automatic aiming and firing
- Clear, restrained stats instead of huge number spam
- Loot-driven builds inspired by randomized gear, brands, elements, and legendary effects
- Heartcore / starfield theme

## Run

Install LÖVE 11.x, then run:

```bash
love .
```

## Controls

### Combat

- `WASD` / arrow keys - move
- Weapons aim and fire automatically
- `Esc` - quit

### Menu / Run

- `Enter` - start / next wave / restart

### Shop

- `1`-`4` - buy shop slot
- `Z` / `X` / `C` / `V` - lock shop slots 1-4
- `R` - reroll unlocked shop slots
- `Enter` - start next wave

## Current Prototype Features

- 10-wave run structure
- 30-second waves
- HP, shield, XP, level, coins, kills
- Auto-targeted weapons
- Six weapon archetypes:
  - Star Needle
  - Swarm Launcher
  - Molten Cannon
  - Echo Blade
  - Arc Coil
  - Void Orb
- Five gear brands:
  - Starforge
  - Swarm
  - Molten
  - Echo
  - Blackbox
- Element behaviors:
  - Burn
  - Arc
  - Corrode
  - Frost
  - Void
- Shop with weapons, shields, mods, relics, and legendary effects
- Boss wave placeholder

## Files

- `main.lua` - complete prototype loop, rendering, combat, loot, shop, and wave flow
- `conf.lua` - LÖVE window/module configuration
