"""Gom các dải animation của Sói yêu thành một atlas cho game (một texture, một draw call).

Bố cục: mỗi hàng là một hướng vẽ (ROWS), các cột là khung của mọi hành động nối nhau (ACTIONS).
Ô CELL×CELL, chân sát lề dưới như dải gốc. Hướng phía trái do game lật ngang, không có trong atlas.
Dải còn thiếu được thay tạm (bảng "fallback" trong manifest):
  - Chạy thiếu → Đi cùng hướng;  hướng Xuống thiếu → cùng hành động của Chéo xuống-trái;
  - Gồng / Cào / Nghỉ thiếu → khung đầu của Đi giữ nguyên (game tô màu cảnh báo khi gồng).
Thứ tự hàng và cột phải khớp với EnemyRenderer (WOLF_ROWS, WOLF_ACTIONS).

    python3 tools/art/wolf_atlas.py            # ghi sprites/wolf_atlas.png + sprites/wolf_atlas.json
"""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/enemies/wolf"
OUT = ROOT / "sprites"
CELL = 128  # dải gốc 256 thu một nửa: đủ nét cho cỡ 64 (thường) và 96 (tinh anh)
SRC_CELL = 256
ROWS = ["up", "upright", "right", "down", "downleft"]
ACTIONS = [("walk", 6), ("run", 6), ("windup", 3), ("claw", 4), ("recover", 4)]


def _strip(action, d):
    """Các khung của dải gốc (256), hoặc None nếu chưa có."""
    path = SRC / action / f"wolf_{d}_{action}.png"
    if not path.exists():
        return None
    img = Image.open(path).convert("RGBA")
    return [img.crop((k * SRC_CELL, 0, (k + 1) * SRC_CELL, SRC_CELL)) for k in range(img.width // SRC_CELL)]


def resolve(action, d):
    """(khung, nguồn) cho một ô hành động × hướng, theo thứ tự thay thế ở đầu file."""
    tries = [(action, d)]
    if d == "down":
        tries.append((action, "downleft"))
    if action == "run":
        tries += [("walk", d)] + ([("walk", "downleft")] if d == "down" else [])
    for a, dd in tries:
        frames = _strip(a, dd)
        if frames:
            return frames, f"{a}/{dd}"
    # Hành động giai đoạn 2 chưa có: giữ khung đứng của Đi.
    for dd in (d, "downleft"):
        frames = _strip("walk", dd)
        if frames:
            return frames[:1], f"walk/{dd} khung 1"
    raise SystemExit(f"thiếu cả dải Đi cho hướng {d}")


def main():
    cols = sum(n for _, n in ACTIONS)
    atlas = Image.new("RGBA", (cols * CELL, len(ROWS) * CELL), (0, 0, 0, 0))
    manifest = {"cell": CELL, "rows": ROWS, "actions": [[a, n] for a, n in ACTIONS], "fallback": {}}
    for r, d in enumerate(ROWS):
        c0 = 0
        for action, n in ACTIONS:
            frames, source = resolve(action, d)
            if source != f"{action}/{d}":
                manifest["fallback"][f"{action}/{d}"] = source
            for k in range(n):
                # Dải ngắn hơn số khung (vd. khung đứng thay tạm) thì lặp lại.
                f = frames[k * len(frames) // n].resize((CELL, CELL), Image.LANCZOS)
                atlas.alpha_composite(f, ((c0 + k) * CELL, r * CELL))
            c0 += n
    OUT.mkdir(exist_ok=True)
    atlas.save(OUT / "wolf_atlas.png", optimize=True)
    (OUT / "wolf_atlas.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n")
    print(f"atlas {atlas.width}×{atlas.height}, thay tạm {len(manifest['fallback'])} ô:")
    for k, v in manifest["fallback"].items():
        print(f"  {k:18s} ← {v}")


if __name__ == "__main__":
    main()
