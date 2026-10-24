# Tenet (working title)

Cyberpunk metroidvania for Giant Jam 2 (theme: **reversal**). Your power is a
time bar measured in milliseconds: hold rewind and the fight plays backwards,
exactly as it happened. The timeline you undo keeps playing as a red ghost that
fights alongside you.

## Run it

1. Install **Godot 4.7.2** (exact version, so project files match).
2. Open Godot → Import → pick this folder's `project.godot`.
3. Press F5.

## Controls

| Action | Input |
| --- | --- |
| Move | W A S D |
| Jump (hold to go higher, tap for a short hop) | Space |
| Attack (click again quickly for a 3-hit combo) | Left click: aims at the cursor (above: up, below in the air: pogo, else toward it) |
| Special (nail art, no charge needed; 1.2 s cooldown) | Q: Great Slash; aiming up/down: Cyclone Slash; while dashing: Dash Slash |
| Dash | Shift |
| Block (hits from the front cost 0.3 s of time instead of health; breaks if you're out of time) | Hold right click |
| Time-parry (turn the attack back, +0.6 s, reflect boss shockwaves) | Raise the guard just as a hit lands |
| Rewind time | Hold E |
| Pause | Esc |
| Wall cling / wall jump | In the air, hold toward a wall; Space to kick off |
| Reboot after dying (lose your time to a shade) | Space while down |
| **Charged nail arts:** hold left click ~0.6 s until the ring pulses, then… | |
| Great Slash (2 damage; its echo hits again 0.5 s later, as a ghost) | …release |
| Dash Slash (lunge, 2 damage to everything in its path) | …press Shift |
| Cyclone Slash (spin, 3 hits all around) | …release aiming up or down |

## Web build (itch.io)

Needs Godot's 4.7.2 export templates once per machine (Editor → Manage Export
Templates → Download). Then:

```bash
godot --headless --path . --export-release "Web" export/web/index.html
cd export/web && zip -r ../tenet-web.zip . && cd -
```

Upload `export/tenet-web.zip` to itch.io as an HTML game ("This file will be
played in the browser"), viewport 1280×720. The build is single-threaded, so
SharedArrayBuffer support is not needed.

## Folders

- `scripts/`, `scenes/` — code and scenes (Arjun + Claude)
- `assets/art/`, `assets/audio/` — art and sound (see [docs/ART_SPEC.md](docs/ART_SPEC.md))

## Sound

`tools/gen_audio.py` synthesizes every sound effect and the music loop into
`assets/audio/` (`python3 tools/gen_audio.py`). To use a real sound instead,
drop a `.ogg` or `.wav` with the same name there; `.ogg` wins. Names in use:
jump, dash, slash, hit, kill, hurt, death, shard, rewind_loop, rewind_end,
gate, boss_slam, ui_move, ui_select, win, music_level.

## Scripted playtests

`scripts/dev/autopilot.gd` plays the game from a fixed input plan, prints the
game state and saves screenshots. It does nothing in a normal run.

```bash
godot --path . --fixed-fps 60 -- --autopilot=fight --shots=/absolute/output/dir
# plans: fight, arena, boss (add --checkpoint=1), win, title
```

To avoid merge conflicts, only edit files in your own folders. Pull before you
start, commit small, push often.
