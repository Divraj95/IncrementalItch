# Steal the Ground — prototype 01

A short Godot 4.6 terrain puzzle. Borrow tiles to cross a broken glade, recover the forest heart, and bring it home. This is the first mechanic prototype, not the planned 15-minute adventure.

## Play

WASD or arrow keys move. Click an adjacent tile to pick it up, or an adjacent gap to place the selected carried tile. E / Space uses the tile you face. 1–3 or Tab selects a backpack slot. Z undoes movement and interactions; R resets. Water is not walkable. Trees, the home ring, and the heart's tile stay rooted.

Carry up to three tiles. The recovered heart occupies one slot. Build a three-tile crossing across the central gap and preserve your path home.

## Develop

Open `project.godot` in Godot 4.6.3 and press F6/F5. From a terminal:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/smoke.gd
godot --path .
```

Export the Web preset with matching official Godot export templates:

```sh
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
python3 -m http.server 8000 --directory build/web
```

The Web preset uses single-threaded WebAssembly and needs no cross-origin isolation headers. Serve the exported files over HTTP(S), rather than opening the HTML as a local file.

## Artwork

Minifantasy by **Krishna Palacio**. Uses the user-provided commercial Tiny Overworld and Creatures packs. Their original licenses are preserved beside the local artwork. The licenses require creator credit and sending a link upon project completion. Standalone asset redistribution is prohibited. Licensed PNGs and license files are intentionally ignored by Git; preserve them locally or restore them from your own purchased packs. Do not publish the source bundle containing these assets without checking redistribution rights.
