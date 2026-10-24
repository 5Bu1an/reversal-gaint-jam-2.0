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

| Action | Keys |
| --- | --- |
| Move | A / D or ← / → |
| Look up / down | W / S or ↑ / ↓ |
| Jump | Space or Z |
| Attack | J or X |
| Dash | K or C |
| Rewind (hold) | L or Shift |

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

## Scripted playtests

`scripts/dev/autopilot.gd` plays the game from a fixed input plan, prints the
game state and saves screenshots. It does nothing in a normal run.

```bash
godot --path . --fixed-fps 60 -- --autopilot=fight --shots=/absolute/output/dir
```

To avoid merge conflicts, only edit files in your own folders. Pull before you
start, commit small, push often.
