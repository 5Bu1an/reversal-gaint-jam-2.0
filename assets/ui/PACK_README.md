# Edo Cyberpunk — Ornate Edition, v2

A detailed painted redesign informed by the flowing ornament, frame hierarchy and organic menu structure in the Hollow Knight reference screenshots. The artwork itself uses Japanese cloud scrolls, ivory inlay, carved gold, black lacquer, vermilion silk knots and restrained turquoise energy.

## Open first
- `menu-preview.png`: composed menu and inventory detail preview.
- `catalog.png`: all 49 component roles.
- `example.html`: dependency-free menu, settings and inventory integration example.
- `CLAUDE_START_HERE.md`: implementation notes.

## Contents
- `sources/`: 20 newly generated transparent PNG master paintings, preserved at generation resolution.
- `png/`: 49 independently usable RGBA UI component textures at the previous logical sizes.
- `png-2x/`: all 49 textures at double resolution for higher-density rendering.
- `svg/`: self-contained compositions embedding raster paintings and simple state overlays. These are NOT vector tracings of the painting and do not gain new image detail when enlarged.
- `artwork/`: four retained artworks from v1: background, clan crest, katana and lantern.
- `manifest.json`: paths, dimensions, pivots, usage and checksums.
- `generation.json`: prompts for the 20 new paintings, made with the built-in image generation tool.
- `build_pack.py`: reproducible assembly/export script using Python, Pillow for validation and Inkscape for rendering. No API key required to rebuild from included sources.

## What changed
Angular wireframe-style UI was replaced with carved curling ornament, layered cloud relief, silk ties, gilded edges, patina, soft glows and fuller item silhouettes. The paintings derive from 20 independently generated masters. Direction changes, small control elements and interaction states are composited from those masters; 49 roles does not mean 49 separately painted originals.

## Import
Use PNGs for engine textures. Preserve aspect ratio and use linear filtering. Render png-2x at half its pixel dimensions to retain the previous logical sizes. Full-resolution sources are available for larger presentations. Small UI icons will naturally lose microdetail at very small display sizes.

PNG paths and component IDs remain compatible with v1. Default rendered dimensions remain unchanged. The old nine-slice metadata has been removed: the detailed painted borders should not be arbitrarily stretched. For resizable panels, anchor the four individual corner ornaments and repeat/stretch only simple intervening borders; fill the middle with a dark UI shape.

Use live labels. No font binary, original Hollow Knight assets, game code, character animations, sound or level tiles are included. NEON RONIN is a replaceable preview title. PNG alpha includes intentional soft lighting around some painted subjects. The energy meter has a transparent center for live fill.
