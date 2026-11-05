# Steal the Ground

A five-chapter Godot 4.6 terrain puzzle adventure. Borrow the ground, repair forgotten machinery, recover the forest heart, and carry it home. Each chapter introduces a new use for the three-slot backpack. Optional seeds reward detours. The game opens with a Play button, advances automatically through five levels, and ends with The End. Only three numbered inventory slots appear below the playfield.

Play the deployed build: **https://divraj95.github.io/IncrementalItch/**

## Controls

- **WASD / arrows:** move; hold a direction to keep walking.
- **Click an adjacent tile:** take it, or place the selected carried material into a gap.
- **E / Space:** use the tile you face.
- **1–3 / Tab:** select a backpack slot.
- **Z:** undo. **R:** restart the current chapter.
- **M:** mute sound.

Grass and stone are walkable; water is not. Rooted ground stays fixed. Water fills mill channels, while stone supports mechanisms. The heart needs one backpack slot. Blue sockets need water; gold sockets need stone. Fill every socket before heading for the exit.

## Develop

Restore your licensed artwork first using [assets/README.md](assets/README.md). Open `project.godot` in **Godot 4.6.3** and press F5. From a terminal:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/smoke.gd
godot --path .
```

The game is intended for keyboard and mouse on desktop browsers. The chapter structure targets a short adventure; actual first-play duration depends on puzzle discovery and needs player feedback.

## Export and publish

Install matching official Godot Web export templates, then run:

```sh
./tools/export_web.sh
python3 -m http.server 8000 --directory docs
```

The export helper creates a fresh build, rejects script/export errors, and copies only the successful output into `docs/`. In the managed cloud workspace it defaults to writable XDG directories under `/tmp/steal-godot`, where the matching templates were installed. Set `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, and `XDG_CACHE_HOME` explicitly to use a different installation.

Runtime filenames include a content-derived build ID so browser caches cannot mix files from different builds. `docs/build.json` identifies the published version. Serve over HTTP(S); opening the HTML directly from disk will not work. The single-threaded Web export needs no cross-origin isolation headers.

Commit the updated `docs/` directory with your changes. **Publish browser adventure** in GitHub Actions deploys it when those files change on `main`. It deploys the exported files; it does not rebuild from source or require access to the original commercial artwork. Check [Actions](https://github.com/Divraj95/IncrementalItch/actions) for deployment progress.

If Pages is not yet configured, select **Settings → Pages → Source → GitHub Actions**, then rerun the deployment workflow. Refresh the game after a successful deployment.

## Artwork

Minifantasy by **Krishna Palacio**. Uses the user-provided commercial Tiny Overworld and Creatures packs. Their original licenses are preserved beside the local artwork. The licenses require creator credit and sending a link upon project completion. Standalone asset redistribution is prohibited. Licensed PNGs and license files are intentionally ignored by Git; preserve them locally or restore them from your own purchased packs. Do not publish the source bundle containing these assets without checking redistribution rights.

## itch.io mini release

The game starts directly in chapter 1 on every page load, progresses through all five chapters, and ends with **The End**. There is no chapter selector. Enter on the ending starts a fresh run.

Upload `build/steal-the-ground-itch.zip` as an HTML game on itch.io and enable **This file will be played in the browser**. Use a 1152 × 768 viewport, allow fullscreen, and list keyboard/mouse as required. Credit Krishna Palacio in the page description as well as the in-game credits.

## itch.io upload

Upload `build/steal-the-ground-itch.zip` as an HTML game, enable **This file will be played in the browser**, set the viewport to 1152 × 768 and allow fullscreen. Put the controls above on the itch page. Include the credit **Minifantasy artwork by Krishna Palacio** in the page description. The upload includes CREDITS.txt.
