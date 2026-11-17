#!/bin/bash
set -Eeuo pipefail

if [ "$#" -ne 4 ]; then
  echo "Uso: bash prepare-release.sh SERVIDOR FUENTE SALIDA_NUEVA ETIQUETA_IMAGEN" >&2
  exit 2
fi
server=$(cd "$1" && pwd -P)
source_dir=$(cd "$2" && pwd -P)
parent=$(cd "$(dirname "$3")" && pwd -P)
release="$parent/$(basename "$3")"
image=$4
if [ -e "$release" ] || [ -L "$release" ]; then
  echo "La salida ya existe: $release" >&2
  exit 1
fi
case "$release/" in
  "$source_dir/"*) echo "La salida no puede estar dentro de la fuente." >&2; exit 1 ;;
esac
for file in install_shiny_server.sh install_pandoc.sh install_s6init.sh; do
  test -f "$server/$file"
done
test -f "$source_dir/deploy/Dockerfile"
if docker info >/dev/null 2>&1; then
  docker_cmd=(docker)
else
  docker_cmd=(sudo -n docker)
fi

mkdir "$release"
mkdir -p "$release/context/deploy"
for file in install_shiny_server.sh install_pandoc.sh install_s6init.sh; do
  cp -p "$server/$file" "$release/context/$file"
done
cp -R "$source_dir/deploy/." "$release/context/deploy/"
"${docker_cmd[@]}" build \
  -f "$release/context/deploy/Dockerfile" -t "$image" "$release/context"
"${docker_cmd[@]}" run --rm --user shiny --entrypoint Rscript \
  "$image" --vanilla /opt/notebooks/install-deps.R --check
"${docker_cmd[@]}" run --rm --user root \
  --mount "type=bind,source=$source_dir,target=/input,readonly" \
  --mount "type=bind,source=$release,target=/output" \
  --entrypoint Rscript "$image" --vanilla \
  /opt/notebooks/render-notebooks.R /input /output/prepared

python3 - "$release/compose.release.json" "$image" "$release/prepared/site" <<'PY'
import json
import sys
path, image, site = sys.argv[1:]
config = {
    "version": "3.0",
    "services": {"shiny_server": {
        "image": image,
        "volumes": [{"type": "bind", "source": site, "target": "/srv/shiny-server"}],
    }},
}
with open(path, "x") as handle:
    json.dump(config, handle, indent=2)
    handle.write("\n")
PY
printf 'PREPARACIÓN COMPLETA: %s\nNo se ha sustituido ningún contenedor.\n' "$release"
