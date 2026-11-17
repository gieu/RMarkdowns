#!/bin/bash
set -Eeuo pipefail

# Safe default: prepare only. Install with --deploy only after approval.
mode=${1:---prepare-only}
if [ "$#" -gt 1 ] || { [ "$mode" != "--prepare-only" ] && [ "$mode" != "--deploy" ]; }; then
  echo "Uso: bash webhook.sh [--prepare-only|--deploy]" >&2
  exit 2
fi
server=${SHINY_SERVER_DIR:-/home/ubuntu/docker-compose/shiny}
server=$(cd "$server" && pwd -P)
repo="$server/mountpoints/apps"
mkdir -p "$server/releases"
exec 9>"$server/releases/.webhook.lock"
flock -n 9 || { echo "Ya hay otra actualización en curso." >&2; exit 1; }

# Fetch/archive do not modify the checkout or the directory currently served.
git -C "$repo" fetch origin master
commit=$(git -C "$repo" rev-parse --verify 'FETCH_HEAD^{commit}')
source_dir=$(mktemp -d "$server/releases/source-${commit:0:12}-XXXXXX")
git -C "$repo" archive "$commit" | tar -x -C "$source_dir"
release="$server/releases/release-${commit:0:12}-${source_dir##*-}"
image="shiny-server:release-${commit:0:12}-$(date +%s)"
bash "$source_dir/deploy/prepare-release.sh" "$server" "$source_dir" "$release" "$image"
printf '%s\n' "$commit" > "$release/commit.txt"

if [ "$mode" = "--prepare-only" ]; then
  echo "Preparación terminada. Producción no se ha modificado."
  exit 0
fi

# Keep the current image/mount available for a manual rollback.
old_image=$(sudo -n docker inspect --format '{{.Image}}' shiny_server)
old_site=$(sudo -n docker inspect --format \
  '{{range .Mounts}}{{if eq .Destination "/srv/shiny-server"}}{{.Source}}{{end}}{{end}}' shiny_server)
test -d "$old_site"
rollback_image="${image/release-/rollback-}"
sudo -n docker tag "$old_image" "$rollback_image"
python3 - "$release/compose.previous.json" "$rollback_image" "$old_site" <<'PY'
import json
import sys
path, image, site = sys.argv[1:]
with open(path, "x") as handle:
    json.dump({"version": "3.0", "services": {"shiny_server": {
        "image": image,
        "volumes": [site + ":/srv/shiny-server"],
    }}}, handle, indent=2)
    handle.write("\n")
PY
compose=(sudo -n docker-compose -f "$server/docker-compose.yml")
"${compose[@]}" -f "$release/compose.release.json" config --quiet
if ! "${compose[@]}" -f "$release/compose.release.json" \
  up --no-build --no-deps --force-recreate -d shiny_server; then
  echo "Falló la activación; intentando restaurar la imagen y el montaje anteriores." >&2
  "${compose[@]}" -f "$release/compose.previous.json" \
    up --no-build --no-deps --force-recreate -d shiny_server
  exit 1
fi
printf 'Activado: %s\nRollback manual: %s\n' "$release" "$release/compose.previous.json"
