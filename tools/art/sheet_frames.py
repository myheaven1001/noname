"""Dải animation do AI tạo (N khung xếp ngang, nền trắng) → các khung đã căn, cỡ 256 và cỡ game.

Các bước:
  1. Xoá nền trắng nối với mép ảnh.
  2. Chia đều N ô theo chiều ngang (AI được yêu cầu vẽ các khung cách đều).
  3. Cắt mọi khung theo CÙNG một khung bao (hợp nội dung của N ô) → nhân vật không nhảy chỗ giữa các khung.
  4. Mọi hướng dùng CÙNG một tỉ lệ thu nhỏ (theo hướng có khung bao lớn nhất) → các hướng cùng cỡ.
  5. Xuất ô CELL×CELL (chân sát lề dưới) và cỡ game GAME×GAME, dải PNG, GIF xem trước, báo cáo kiểm tra.

    python3 tools/art/sheet_frames.py out_dir hướng=ảnh.webp [hướng=ảnh.webp ...] [--frames 6]
"""
import argparse
import json
from pathlib import Path

from PIL import Image

from reference_scale import remove_background, shrink

GROUND = (23, 32, 26, 255)


def split_cells(sheet, n):
    """Chia đều n ô; trả về danh sách ảnh ô (nền trong) cùng khung bao hợp (toạ độ trong ô)."""
    w = sheet.width / n
    cells = [sheet.crop((round(i * w), 0, round((i + 1) * w), sheet.height)) for i in range(n)]
    boxes = [c.getbbox() for c in cells]
    if any(b is None for b in boxes):
        raise ValueError("có ô trống: dải không có đủ %d khung" % n)
    union = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
    return cells, boxes, union


def place(frame, size, pad, scale, resample):
    """Thu theo `scale`, đặt vào ô size×size: căn giữa ngang, đáy khung bao sát lề dưới."""
    w, h = max(1, round(frame.width * scale)), max(1, round(frame.height * scale))
    small = frame.resize((w, h), resample)
    cell = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cell.alpha_composite(small, ((size - w) // 2, size - pad - h))
    return cell


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out_dir")
    ap.add_argument("sheets", nargs="+", help="hướng=đường_dẫn_ảnh")
    ap.add_argument("--frames", type=int, default=6)
    ap.add_argument("--cell", type=int, default=256)
    ap.add_argument("--game", type=int, default=64)
    ap.add_argument("--pad", type=int, default=8)
    ap.add_argument("--action", default="walk")
    a = ap.parse_args()
    out = Path(a.out_dir)
    out.mkdir(parents=True, exist_ok=True)

    parsed = {}
    for item in a.sheets:
        name, path = item.split("=", 1)
        sheet = remove_background(Image.open(path).convert("RGBA"), threshold=232)
        # remove_background cắt theo khung bao toàn dải; chia ô trên dải đã cắt vẫn đều vì AI vẽ cách đều.
        cells, boxes, union = split_cells(sheet, a.frames)
        parsed[name] = (cells, boxes, union)

    # Một tỉ lệ chung cho mọi hướng: khung bao lớn nhất vừa khít ô (trừ lề).
    biggest = max(max(u[2] - u[0], u[3] - u[1]) for _, _, u in parsed.values())
    scale = (a.cell - 2 * a.pad) / biggest
    k = a.cell // a.game
    report = {"scale_to_cell": round(scale, 4), "directions": {}}

    for name, (cells, boxes, union) in parsed.items():
        big_frames, game_frames = [], []
        for c in cells:
            f = c.crop(union)
            big_frames.append(place(f, a.cell, a.pad, scale, Image.BOX))
            g = place(f, a.game, max(1, a.pad // k), scale / k, Image.LANCZOS)
            game_frames.append(shrink(g, a.game))
        for tag, frames, size in (("", big_frames, a.cell), (f"_{a.game}", game_frames, a.game)):
            strip = Image.new("RGBA", (size * len(frames), size), (0, 0, 0, 0))
            for i, f in enumerate(frames):
                strip.alpha_composite(f, (i * size, 0))
            strip.save(out / f"wolf_{name}_{a.action}{tag}.png")
        # GIF xem trước trên nền đất, 10 fps
        gif = []
        for f in big_frames:
            bg = Image.new("RGBA", f.size, GROUND)
            bg.alpha_composite(f)
            gif.append(bg.convert("P", palette=Image.ADAPTIVE, colors=255))
        gif[0].save(out / f"wolf_{name}_{a.action}.gif", save_all=True, append_images=gif[1:], duration=100, loop=0)

        # Kiểm tra: chiều cao và đường mặt đất (đáy nội dung) của từng khung, trong toạ độ ô gốc.
        heights = [b[3] - b[1] for b in boxes]
        grounds = [b[3] for b in boxes]
        widths = [b[2] - b[0] for b in boxes]
        report["directions"][name] = {
            "frames": len(cells),
            "union_px": [union[2] - union[0], union[3] - union[1]],
            "height_spread_pct": round(100 * (max(heights) - min(heights)) / max(heights), 1),
            "width_spread_pct": round(100 * (max(widths) - min(widths)) / max(widths), 1),
            "ground_spread_px_in_cell": round((max(grounds) - min(grounds)) * scale, 1),
        }
    (out / f"report_{a.action}.json").write_text(json.dumps(report, ensure_ascii=False, indent=1))
    print(json.dumps(report, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
