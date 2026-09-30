#!/usr/bin/env bash
# Export bản web (không đa luồng) và chuẩn bị các file để đăng thành trang:
#   build/web/play.html       trang chơi (từ web/play.html, điền sẵn kích thước file)
#   build/web/index.js        engine loader của Godot
#   build/web/engine.gz.wasm  engine đã nén gzip (trang tự giải nén trong trình duyệt)
#   build/web/game.pck.wasm   dữ liệu game
# Hai file cuối mang đuôi .wasm vì trang artifact chỉ phục vụ một số đuôi nhất định (.gz, .pck thì không).
# Cách dùng: GODOT=/đường/dẫn/godot tools/build_web.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=build/web

rm -rf "$OUT"
mkdir -p "$OUT"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Web" "$OUT/index.html"

gzip -9 -c "$OUT/index.wasm" > "$OUT/engine.gz.wasm"
cp "$OUT/index.pck" "$OUT/game.pck.wasm"
wasm_bytes=$(stat -c %s "$OUT/index.wasm")
pck_bytes=$(stat -c %s "$OUT/index.pck")
sed -e "s/const WASM_BYTES = [0-9]*;/const WASM_BYTES = ${wasm_bytes};/" \
    -e "s/const PCK_BYTES = [0-9]*;/const PCK_BYTES = ${pck_bytes};/" \
    web/play.html > "$OUT/play.html"

echo "wasm ${wasm_bytes} B, gzip $(stat -c %s "$OUT/engine.gz.wasm") B, pck ${pck_bytes} B"
