# Game

## Summary

This is a community-made game by the tfpp community.

## Plot

## Project

### Inhabitants

- **Citizens** (`scenes/citizen.tscn`) are low-poly civilians who wander the
  arena, avoid obstacles, and hop on trampolines.
- **Frogs** (`scenes/frog.tscn`) are small, simple citizens. They rest, then
  hop about a meter at a time, turning away from obstacles, and spring higher
  on trampolines. Ten frogs are placed in `scenes/main.tscn`.
- **Frog hats**: face a nearby frog and press E (gamepad X, touch HAT) to wear
  it; press again to swap for another frog or take it off. Each frog rolls a
  kind by rarity (`KINDS` in `scripts/frog.gd`; set `kind` to force one):
  - Green, common (50%): no effect.
  - Blue, uncommon (24%): run 25% faster.
  - Red, uncommon (14%): trampolines launch 1.5x harder.
  - Purple, rare (8%): 70% gravity.
  - Golden, legendary (4%): jump twice as high; shines.

  Frogs of each kind hop with their own effect too.
