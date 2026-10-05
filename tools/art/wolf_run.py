"""Vẽ animation Chạy của Sói yêu (6 khung, 48x48, pixel art, quay mặt sang phải).

Dựng bằng khung xương: thân/đầu/đuôi là khối hình, 4 chân là 2 đoạn (đùi + cẳng) với góc đặt
theo chu kỳ phi nước đại. Vẽ ra bản đồ nhãn (mỗi pixel là một vật liệu), rồi tô màu, đổ bóng
và viền 1px theo bảng màu chung.

    python3 tools/art/wolf_run.py            # ghi assets/enemies/wolf/wolf_run.png
    python3 tools/art/wolf_run.py preview.gif  # thêm bản xem trước phóng to
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

from pixel import (BODY, CLAW_L, EAR_L, EMPTY, EYE_L, FAR, GLOW_L, GROUND, MANE_L, MARK_L, SIZE,
                   colorize, leg)

FRAMES = 6

# Chu kỳ phi nước đại, mỗi khung: (độ nhún thân, góc đùi trước, gập gối trước, góc đùi sau, gập khoeo sau,
# góc đuôi). Góc tính bằng độ so với phương thẳng đứng, dương = chĩa về phía trước (phải).
POSES = [
    # thu chân: chân trước gập dưới ngực, chân sau đưa lên trước
    (1, -30, 55, 40, -35, 10),
    # chân sau đạp: chân sau duỗi ra sau, chân trước vung lên
    (0, 15, 70, -25, -20, 0),
    # duỗi bay: chân trước vươn xa, chân sau duỗi thẳng ra sau
    (-2, 55, 15, -50, -10, -12),
    # chân trước chạm đất
    (-1, 20, 5, -15, -45, -6),
    # chân trước đẩy, chân sau vung về trước
    (0, -15, 10, 15, -55, 4),
    # chân sau chạm đất, cơ thể co lại
    (1, -40, 30, 35, -30, 12),
]


def draw_frame(k):
    bob, f_up, f_bend, h_up, h_bend, tail_deg = POSES[k]
    lab = Image.new("L", (SIZE, SIZE), EMPTY)
    d = ImageDraw.Draw(lab)
    y = 26 + bob

    # Chân phía xa (vẽ trước, tối hơn), lệch pha một chút so với chân phía gần.
    fp = POSES[(k + 1) % FRAMES]
    leg(d, FAR, (27, y + 2), fp[1] - 8, fp[2], width=3)
    leg(d, FAR, (14, y + 2), fp[3] + 8, fp[4], width=3)

    # Đuôi xù hình chổi: gốc to, chóp nhọn, góc thay đổi theo nhịp chạy.
    t = math.radians(tail_deg)
    base = (11, y - 2)
    tip = (base[0] - 11 * math.cos(t), base[1] - 4 + 11 * math.sin(t))
    nx, ny = -(tip[1] - base[1]), tip[0] - base[0]
    ln = math.hypot(nx, ny) or 1.0
    nx, ny = nx / ln, ny / ln
    mid = ((base[0] + tip[0]) / 2, (base[1] + tip[1]) / 2)
    d.polygon([(base[0] + nx * 3, base[1] + ny * 3), (mid[0] + nx * 3, mid[1] + ny * 3), tip,
               (mid[0] - nx * 2, mid[1] - ny * 2), (base[0] - nx * 3, base[1] - ny * 3)], fill=BODY)

    # Thân: hông thon, đùi sau to, ngực sâu (dáng sói), bụng thóp.
    d.ellipse([10, y - 5, 23, y + 3], fill=BODY)
    d.ellipse([11, y - 3, 20, y + 6], fill=BODY)  # đùi sau
    d.ellipse([18, y - 6, 31, y + 3], fill=BODY)
    d.ellipse([23, y - 8, 35, y + 6], fill=BODY)  # ngực
    # Bờm sẫm trên vai + gáy, túm lông gai dọc sống lưng.
    d.polygon([(22, y - 6), (27, y - 10), (33, y - 10), (35, y - 6), (30, y - 3), (24, y - 3)], fill=MANE_L)
    for bx, h in ((16, 2), (20, 3), (24, 4), (28, 4)):
        d.polygon([(bx - 1, y - 5), (bx + 1, y - 5 - h), (bx + 2, y - 5)], fill=MANE_L)

    # Đầu: sọ to, mõm thon dần, hai tai nhọn dựng, mắt đỏ phát sáng, nanh trắng.
    hy = y - 8 - bob // 2
    d.ellipse([31, hy - 5, 41, hy + 4], fill=BODY)
    d.polygon([(38, hy - 3), (46, hy), (46, hy + 2), (43, hy + 4), (38, hy + 4)], fill=BODY)
    d.polygon([(32, hy - 3), (33, hy - 10), (36, hy - 4)], fill=FAR)  # tai xa
    d.polygon([(34, hy - 3), (37, hy - 11), (39, hy - 3)], fill=BODY)  # tai gần
    d.point([(37, hy - 7), (37, hy - 6)], fill=EAR_L)
    d.point((39, hy - 1), fill=EYE_L)
    d.point((40, hy - 1), fill=GLOW_L)
    d.point([(44, hy + 4), (42, hy + 4)], fill=CLAW_L)  # nanh

    # Linh văn hình thoi ở vai.
    d.point([(28, y - 1), (27, y), (29, y), (28, y + 1)], fill=MARK_L)

    # Chân phía gần.
    leg(d, BODY, (29, y + 2), f_up, f_bend)
    leg(d, BODY, (15, y + 2), h_up, h_bend)
    return colorize(lab, y + 3)


def main():
    root = Path(__file__).resolve().parents[2]
    frames = [draw_frame(k) for k in range(FRAMES)]
    sheet = Image.new("RGBA", (SIZE * FRAMES, SIZE), (0, 0, 0, 0))
    for k, f in enumerate(frames):
        sheet.paste(f, (k * SIZE, 0))
    out = root / "assets/enemies/wolf/wolf_run.png"
    sheet.save(out)
    print("đã ghi", out)
    if len(sys.argv) > 1:
        scale = 6
        bg = GROUND
        big = []
        for f in frames:
            canvas = Image.new("RGBA", (SIZE, SIZE), bg)
            canvas.alpha_composite(f)
            big.append(canvas.resize((SIZE * scale, SIZE * scale), Image.NEAREST).convert("P"))
        big[0].save(sys.argv[1], save_all=True, append_images=big[1:], duration=83, loop=0)
        strip = Image.new("RGBA", (SIZE * FRAMES, SIZE), bg)
        strip.alpha_composite(sheet)
        strip.resize((SIZE * FRAMES * scale, SIZE * scale), Image.NEAREST).save(sys.argv[1].replace(".gif", "_strip.png"))
        print("đã ghi", sys.argv[1])


if __name__ == "__main__":
    main()
