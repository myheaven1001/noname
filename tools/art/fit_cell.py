"""Đưa ảnh nhân vật (pixel art phóng to, nền trắng) về một ô vuông cố định, mặc định 256×256.

Hai bản:
  - smooth: thu nhỏ trực tiếp từ ảnh gốc (giữ nhiều chi tiết nhất) → làm ảnh tham chiếu cho AI.
  - grid:   pixel art GAME px (mặc định 64) phóng ×(CELL/GAME) → đúng lưới, giống lúc hiện trong game.

    python3 tools/art/fit_cell.py ảnh_vào thư_mục_ra [--cell 256] [--game 64] [--pad 8]
"""
import argparse
from pathlib import Path

from PIL import Image

from reference_scale import native_grid, remove_background, shrink


def fit(sprite, size, pad, resample):
    """Thu/phóng `sprite` (nền trong) cho vừa ô size×size chừa lề `pad`, căn giữa ngang, chân sát đáy lề."""
    box = size - 2 * pad
    scale = min(box / sprite.width, box / sprite.height)
    w, h = max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale))
    small = sprite.resize((w, h), resample)
    cell = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cell.alpha_composite(small, ((size - w) // 2, size - pad - h))
    return cell


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out_dir")
    ap.add_argument("--cell", type=int, default=256)
    ap.add_argument("--game", type=int, default=64)
    ap.add_argument("--pad", type=int, default=8)
    ap.add_argument("--grid-cell", type=float, default=7.84, help="cỡ ô pixel của ảnh vào")
    a = ap.parse_args()
    out = Path(a.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    stem = Path(a.src).stem

    big = Image.open(a.src).convert("RGBA")
    # Bản chi tiết: xoá nền ở độ phân giải gốc rồi thu nhỏ bằng bộ lọc hộp (trung bình đều từng ô).
    clean_big = remove_background(big.copy())
    smooth = fit(clean_big, a.cell, a.pad * a.cell // 256, Image.BOX)
    smooth.save(out / f"{stem}_{a.cell}.png")

    # Bản lưới chuẩn: về pixel gốc → thu về GAME px (khoá bảng màu, alpha cứng) → phóng nearest ×k.
    native = remove_background(native_grid(big, a.grid_cell))
    k = a.cell // a.game
    game = fit(native, a.game, max(1, a.pad // k), Image.LANCZOS)
    game = shrink(game, a.game)  # alpha cứng ở cỡ game (giữ nguyên cỡ ô vì đã vuông)
    game.save(out / f"{stem}_cell{a.game}.png")
    grid = game.resize((a.cell, a.cell), Image.NEAREST)
    grid.save(out / f"{stem}_{a.game}x{k}_{a.cell}.png")
    for p in (smooth, grid):
        assert p.size == (a.cell, a.cell)
    print("đã ghi", out / f"{stem}_{a.cell}.png", "và", out / f"{stem}_{a.game}x{k}_{a.cell}.png")


if __name__ == "__main__":
    main()
