"""Sơ đồ 8 hướng của một con quái: hướng nào đã có ảnh, hướng nào lật ngang, hướng nào còn phải vẽ.

    python3 tools/art/direction_map.py sprite_chéo_xuống_trái.png out.png
Sprite đầu vào là hướng chéo xuống-trái (góc 3/4 mặt về camera, thân sang trái), như mẫu Sói yêu.
"""
import sys

from PIL import Image, ImageDraw, ImageFont

GROUND = (23, 32, 26)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

# (hàng, cột) trong lưới 3x3 → (tên, trạng thái, ghi chú). Trạng thái: "có" / "lật" / "vẽ".
CELLS = {
    (0, 0): ("Chéo lên-trái", "lật", "lật từ chéo lên-phải"),
    (0, 1): ("Lên", "vẽ", "quay lưng hẳn về camera"),
    (0, 2): ("Chéo lên-phải", "vẽ", "3/4 quay lưng, thân sang phải"),
    (1, 0): ("Trái", "lật", "lật từ phải"),
    (1, 2): ("Phải", "vẽ", "nhìn ngang, thân sang phải"),
    (2, 0): ("Chéo xuống-trái", "có", "chính là ảnh mẫu"),
    (2, 1): ("Xuống", "vẽ", "mặt hướng thẳng về camera"),
    (2, 2): ("Chéo xuống-phải", "lật", "lật từ ảnh mẫu"),
}


def main(sprite_path, out_path):
    spr = Image.open(sprite_path).convert("RGBA")
    title_f, name_f, small_f = ImageFont.truetype(BOLD, 24), ImageFont.truetype(BOLD, 16), ImageFont.truetype(FONT, 13)
    paper, muted = (233, 236, 228), (154, 168, 157)
    colors = {"có": (111, 211, 176), "lật": (140, 170, 255), "vẽ": (240, 180, 90)}
    tags = {"có": "ĐÃ CÓ", "lật": "LẬT NGANG", "vẽ": "CẦN VẼ"}
    cell, gap, margin, top = 250, 16, 32, 100
    width = margin * 2 + cell * 3 + gap * 2
    img = Image.new("RGB", (width, top + (cell + gap) * 3 + 70), GROUND)
    d = ImageDraw.Draw(img)
    d.text((margin, 24), "Sói yêu — 8 hướng", font=title_f, fill=paper)
    d.text((margin, 58), "Vẽ 5 hướng (1 đã có từ ảnh mẫu → còn 4), lật ngang 3 hướng phía trái.",
           font=small_f, fill=muted)
    fit = spr.copy()
    fit.thumbnail((cell - 40, cell - 80), Image.NEAREST)
    for (r, c), (name, state, note) in CELLS.items():
        x, y = margin + c * (cell + gap), top + r * (cell + gap)
        col = colors[state]
        d.rectangle([x, y, x + cell, y + cell], outline=col, width=2)
        d.text((x + 10, y + 8), tags[state], font=small_f, fill=col)
        if state == "có" or name == "Chéo xuống-phải":
            s = fit if state == "có" else fit.transpose(Image.FLIP_LEFT_RIGHT)
            img.paste(s, (x + (cell - s.width) // 2, y + 30 + (cell - 80 - s.height) // 2), s)
        else:
            d.text((x + cell // 2 - 6, y + cell // 2 - 30), "?", font=title_f, fill=col)
        d.text((x + 10, y + cell - 46), name, font=name_f, fill=paper)
        d.text((x + 10, y + cell - 22), note, font=small_f, fill=muted)
    # Ô giữa: la bàn
    cx, cy = margin + cell + gap + cell // 2, top + cell + gap + cell // 2
    for (r, c) in CELLS:
        dx, dy = (c - 1) * 80, (r - 1) * 80
        d.line([cx, cy, cx + dx, cy + dy], fill=colors[CELLS[(r, c)][1]], width=3)
        d.ellipse([cx + dx - 5, cy + dy - 5, cx + dx + 5, cy + dy + 5], fill=colors[CELLS[(r, c)][1]])
    d.ellipse([cx - 9, cy - 9, cx + 9, cy + 9], fill=paper)
    y = top + (cell + gap) * 3 + 6
    d.text((margin, y), "Chạy: 6 khung × 5 hướng vẽ = 30 khung.   Cả 7 hành động: 26 khung × 5 = 130 khung.",
           font=small_f, fill=muted)
    img.save(out_path)
    print("đã ghi", out_path)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
