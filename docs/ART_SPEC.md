# Art and audio spec

The game runs at **640×360** and scales up 2× with no smoothing, so draw pixel
art at actual size. Keep silhouettes dark and let neon carry the color.

## Palette

| Use | Hex |
| --- | --- |
| Background / shadow | `#0b0b14` |
| Mid-tone walls | `#1a1a2e` |
| Neon pink (player, danger) | `#ff2a6d` |
| Neon cyan (UI, time bar) | `#05d9e8` |
| Rewind ghost | `#ff3b3b` at ~60% opacity (done in code, no need to draw) |

## Sprite sheets

Export each animation as a **horizontal PNG strip** (frames side by side, no
gaps, transparent background). Name files exactly as below and put them in
`assets/art/`. Feet sit on the bottom edge of the frame, centered.

### Player — 32×32 frames, priority order

| File | Frames | Notes |
| --- | --- | --- |
| `player_idle.png` | 4 | Slight breathing / coat sway |
| `player_run.png` | 6 | |
| `player_jump.png` | 2 | Rising, then falling |
| `player_slash.png` | 3 | Blade sweep in front; slash arc can extend past the frame edge if you widen this one to 48×32 |
| `player_dash.png` | 2 | Streaky, low |
| `player_hurt.png` | 1 | |

### Enemies — 32×32 frames

| File | Frames | Notes |
| --- | --- | --- |
| `drone_fly.png` | 4 | Flying security drone |
| `grunt_walk.png` | 4 | Ground enemy, corporate enforcer |
| `grunt_attack.png` | 3 | |

### Boss — 64×64 frames (after the above are done)

| File | Frames |
| --- | --- |
| `boss_idle.png` | 4 |
| `boss_attack.png` | 4 |

### Tiles — `tiles.png`

16×16 tiles in one sheet: floor top, floor fill, wall left, wall right,
ceiling, platform, spikes, plus a few neon-sign and pipe decorations.

### Background — `bg_city.png`

640×360, a far skyline layer for parallax. A second `bg_near.png` layer is a
bonus.

## Audio — put in `assets/audio/`

`.wav` for effects (jsfxr is fine), `.ogg` for music.

| File | |
| --- | --- |
| `slash.wav`, `hit.wav`, `hurt.wav`, `jump.wav`, `dash.wav` | Core effects |
| `rewind_loop.wav` | Loopable whir/tape-rewind sound while holding rewind |
| `music_level.ogg` | One synthwave track, loopable |

## Workflow

1. `git pull` before you start.
2. Only add or change files inside `assets/`.
3. Commit and push each finished sprite; it shows up in the game on the next
   pull. Placeholder rectangles are used until a file exists.
