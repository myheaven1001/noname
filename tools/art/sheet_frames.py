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


def _cuts(sheet, n, search=0.15):
    """Vị trí cắt giữa các khung: cột có ít điểm ảnh nhất trong ±search ô quanh ranh giới đều.

    Khi các khung chạm nhau (lửa đuôi, đốm lửa vắt sang ô bên), cắt ở cột thưa nhất làm ít mảnh
    của khung này lọt sang khung kia nhất.
    """
    w = sheet.width / n
    alpha = sheet.getchannel("A").load()
    counts = [sum(1 for y in range(0, sheet.height, 2) if alpha[x, y]) for x in range(sheet.width)]
    cuts = [0]
    for i in range(1, n):
        lo, hi = round((i - search) * w), round((i + search) * w)
        cuts.append(min(range(lo, hi), key=lambda x: (counts[x], abs(x - i * w))))
    cuts.append(sheet.width)
    return cuts


def split_cells(sheet, n, margin=0.2):
    """Tách n khung; mỗi khung giữ toạ độ theo ô đều danh nghĩa (để các khung thẳng hàng) và được
    nới thêm `margin` ô mỗi bên cho phần nhô ra. Trả về ảnh khung, khung bao từng khung, khung bao hợp."""
    w = sheet.width / n
    cuts = _cuts(sheet, n)
    m = round(margin * w)
    cells = []
    for i in range(n):
        part = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
        part.paste(sheet.crop((cuts[i], 0, cuts[i + 1], sheet.height)), (cuts[i], 0))
        left = round(i * w) - m
        canvas = Image.new("RGBA", (round(w) + 2 * m, sheet.height), (0, 0, 0, 0))
        canvas.paste(part.crop((max(0, left), 0, min(sheet.width, left + canvas.width), sheet.height)),
                     (max(0, -left), 0))
        cells.append(canvas)
    boxes = [c.getbbox() for c in cells]
    found = [b for b in boxes if b]
    if len(found) < n:
        # Chỉ chấp nhận ô trống ở cuối dải (khung cuối của Chết có thể đã tan hết); ô trống giữa dải là lỗi.
        if not found or boxes.index(None) < len(found):
            raise ValueError("có ô trống: dải không có đủ %d khung" % n)
        print("CẢNH BÁO: %d khung cuối trống, giữ nguyên là khung trong suốt" % (n - len(found)))
    union = (min(b[0] for b in found), min(b[1] for b in found), max(b[2] for b in found), max(b[3] for b in found))
    return cells, boxes, union


def place(frame, size, pad, scale, resample, center_x=None):
    """Thu theo `scale`, đặt vào ô size×size, đáy khung bao sát lề dưới. Căn giữa ngang theo cả khung,
    hoặc theo cột `center_x` (toạ độ trong `frame`) nếu có. Phần tràn khỏi ô bị cắt."""
    w, h = max(1, round(frame.width * scale)), max(1, round(frame.height * scale))
    small = frame.resize((w, h), resample)
    x = (size - w) // 2 if center_x is None else round(size / 2 - center_x * scale)
    cell = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas = Image.new("RGBA", (size + 2 * w, size + h), (0, 0, 0, 0))  # chừa chỗ để dán lệch ra ngoài ô
    canvas.alpha_composite(small, (x + w, size - pad - h + h))
    cell.alpha_composite(canvas.crop((w, h, w + size, h + size)))
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
    ap.add_argument("--scale", type=float, default=0.0,
                    help="tỉ lệ thu nhỏ cố định (0 = tự tính theo khung bao lớn nhất); dùng chung giữa các hành động")
    ap.add_argument("--dir-scale", default="",
                    help="nhân thêm tỉ lệ riêng từng hướng, vd. right=0.76,up=0.98 (khi AI vẽ thân to nhỏ khác dải Đi)")
    ap.add_argument("--anchor-frame", type=int, default=-1,
                    help="căn giữa ngang theo thân ở khung này (đánh số từ 1) thay vì theo khung bao hợp; "
                         "dùng khi có hiệu ứng (vệt vuốt) làm lệch khung bao")
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
    scale = a.scale or (a.cell - 2 * a.pad) / biggest
    if biggest * scale > a.cell - 2 * a.pad + 0.5:
        print("CẢNH BÁO: với tỉ lệ %.4f, khung bao lớn nhất (%d px) vượt ô %d px, phần thừa bị cắt"
              % (scale, biggest, a.cell))
    k = a.cell // a.game
    report = {"scale_to_cell": round(scale, 4), "dir_scale": a.dir_scale, "anchor_frame": a.anchor_frame,
              "directions": {}}

    dir_scale = {kv.split("=")[0]: float(kv.split("=")[1]) for kv in a.dir_scale.split(",") if kv}
    for name, (cells, boxes, union) in parsed.items():
        big_frames, game_frames = [], []
        sc = scale * dir_scale.get(name, 1.0)
        cx = None
        if a.anchor_frame > 0:
            ab = boxes[a.anchor_frame - 1]
            cx = (ab[0] + ab[2]) / 2 - union[0]
        for c in cells:
            f = c.crop(union)
            big_frames.append(place(f, a.cell, a.pad, sc, Image.BOX, cx))
            g = place(f, a.game, max(1, a.pad // k), sc / k, Image.LANCZOS, cx)
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
        found = [b for b in boxes if b]
        heights = [b[3] - b[1] for b in found]
        grounds = [b[3] for b in found]
        widths = [b[2] - b[0] for b in found]
        report["directions"][name] = {
            "frames": len(cells),
            "union_px": [union[2] - union[0], union[3] - union[1]],
            "height_spread_pct": round(100 * (max(heights) - min(heights)) / max(heights), 1),
            "width_spread_pct": round(100 * (max(widths) - min(widths)) / max(widths), 1),
            "ground_spread_px_in_cell": round((max(grounds) - min(grounds)) * sc, 1),
        }
    (out / f"report_{a.action}.json").write_text(json.dumps(report, ensure_ascii=False, indent=1))
    print(json.dumps(report, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
