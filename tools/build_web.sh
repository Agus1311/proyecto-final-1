#!/usr/bin/env bash
# Build web optimizado de «Mesa de Ayuda — CAA Corp».
#
# 1. Copia el proyecto a una carpeta temporal y reduce a la mitad las texturas de más de 512 px
#    (solo para la web: la versión de escritorio conserva las texturas completas).
# 2. Exporta con el preset «Web» (Compatibility, un solo hilo) a build/web/.
# 3. Empaqueta: zip para itch.io, HTML único y versión para hosting estático (página + partes .json).
#
# Uso:  GODOT=/ruta/a/godot tools/build_web.sh [carpeta_de_salida]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
OUT="${1:-$ROOT/build/entrega_web}"
TMP="$(mktemp -d /tmp/caa_web_XXXX)"

echo "== copia del proyecto en $TMP"
( cd "$ROOT" && tar --exclude=./.godot --exclude=./build -cf - . ) | ( cd "$TMP" && tar -xf - )

echo "== texturas a la mitad para la web"
python3 - "$TMP/assets/textures" <<'EOF'
import sys, os
from PIL import Image
n = 0; before = after = 0
for dp, _, fs in os.walk(sys.argv[1]):
    for f in fs:
        if not f.lower().endswith(('.png', '.jpg', '.jpeg')): continue
        p = os.path.join(dp, f); before += os.path.getsize(p)
        im = Image.open(p)
        if max(im.size) > 512:
            im = im.resize((max(1, im.width // 2), max(1, im.height // 2)), Image.LANCZOS)
            im.save(p); n += 1
        after += os.path.getsize(p)
print(f"   {n} texturas reducidas · {before // 1024 // 1024} MB -> {after // 1024 // 1024} MB")
EOF

echo "== importar y exportar"
mkdir -p "$TMP/build/web" "$ROOT/build/web"
touch "$TMP/build/.gdignore"
"$GODOT" --headless --path "$TMP" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$TMP" --export-release "Web" "$TMP/build/web/index.html" >/dev/null 2>&1
cp "$TMP"/build/web/index.* "$ROOT/build/web/"
ls -la "$ROOT/build/web/index.pck" "$ROOT/build/web/index.wasm"

echo "== empaquetar"
mkdir -p "$OUT/hosting"
W="$ROOT/build/web"
( cd "$W" && rm -f "$OUT/CAA_Corp_Web_itchio.zip" && zip -q -9 "$OUT/CAA_Corp_Web_itchio.zip" \
    index.html index.js index.wasm index.pck index.png index.icon.png index.apple-touch-icon.png \
    index.audio.worklet.js index.audio.position.worklet.js )
python3 "$ROOT/tools/single_html.py" "$W" "$OUT/MesaDeAyuda_CAA_Corp.html"
python3 "$ROOT/tools/host_html.py" "$W" "$OUT/hosting/index.html"
rm -rf "$TMP"
echo "== listo en $OUT"
ls -la "$OUT" "$OUT/hosting"
