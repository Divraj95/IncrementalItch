#!/usr/bin/env bash
# Export a verified Web build and stage it for GitHub Pages.
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
export XDG_DATA_HOME="${XDG_DATA_HOME:-/tmp/steal-godot/data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/tmp/steal-godot/config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/tmp/steal-godot/cache}"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" build
# Screenshots and prior exports must never become game resources.
touch build/.gdignore
export_stage="$(mktemp -d "$project_root/build/export-stage.XXXXXX")"
trap 'rm -rf -- "$export_stage"' EXIT
export_log="$project_root/build/export-web.log"
if ! godot --headless --path "$project_root" --export-release Web "$export_stage/index.html" >"$export_log" 2>&1; then
  cat "$export_log"
  exit 1
fi
# Godot can emit script errors while returning success: reject those exports.
if rg -q 'SCRIPT ERROR|Parse Error|Failed to export|Export failed|ERROR:' "$export_log"; then
  cat "$export_log"
  exit 1
fi
python3 - "$export_stage" "$project_root/docs" <<'PY'
import hashlib, json, pathlib, re, shutil, sys
stage, destination = map(pathlib.Path, sys.argv[1:])
required = ['index.html', 'index.js', 'index.wasm', 'index.pck',
            'index.audio.worklet.js', 'index.audio.position.worklet.js']
for name in required:
    path = stage / name
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f'Missing or empty export output: {name}')
# Godot derives WASM and audio-worklet filenames from `executable`. Rename
# all runtime files together, then replace the basename in its HTML config.
# Each build has distinct URLs, so cached files cannot mix game versions.
digest = hashlib.sha256()
for name in sorted(required):
    digest.update((stage / name).read_bytes())
version = digest.hexdigest()[:12]
basename = f'game-{version}'
html = (stage / 'index.html').read_text()
match = re.search(r'const GODOT_CONFIG = (\{.*\});', html)
if not match:
    raise SystemExit('Godot HTML config missing; export format changed')
config = json.loads(match.group(1))
if config.get('executable') != 'index':
    raise SystemExit('Unexpected Godot executable basename')
config['executable'] = basename
config['fileSizes'] = {k.replace('index.', basename + '.', 1): v
                       for k, v in config['fileSizes'].items()}
html = html.replace(match.group(0), 'const GODOT_CONFIG = ' + json.dumps(config, separators=(',', ':')) + ';')
html = html.replace('src="index.', f'src="{basename}.')
html = html.replace('</head>', '<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">\n</head>')
html = html.replace('</body>', f'<!-- Steal the Ground build {version} -->\n</body>')
html = '\n'.join(line.rstrip() for line in html.splitlines()).rstrip() + '\n'
publish = stage / 'publish'
publish.mkdir()
(publish / 'index.html').write_text(html)
(publish / '.nojekyll').touch()
(publish / 'build.json').write_text(json.dumps({'version': version}) + '\n')
for path in stage.glob('index.*'):
    if path.name == 'index.html' or path.name.endswith('.import'):
        continue
    shutil.copy2(path, publish / path.name.replace('index.', basename + '.', 1))
# All verification precedes replacement. Preserve unrelated documentation.
destination.mkdir(exist_ok=True)
for path in destination.iterdir():
    if path.is_file() and (path.name.startswith(('index.', 'game-')) or path.name in ('.nojekyll', 'build.json')):
        path.unlink()
for path in publish.iterdir():
    shutil.copy2(path, destination / path.name)
print(f'Web build {version} staged in {destination}')
PY
