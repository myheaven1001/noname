"""Ảnh duyệt Sói yêu 4 hướng (phải, trái, đi xuống, đi lên) + kích thước thật trong game.

Hướng phải lấy khung "chân trước chạm đất" của animation Chạy (wolf_run.py); hướng trái là hướng phải
lật ngang; hai hướng nhìn thẳng (đi xuống / đi lên) vẽ nửa trái rồi lật đối xứng, riêng đuôi vẽ lệch.

    python3 tools/art/wolf_directions.py out.png
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import wolf_run
from pixel import (BODY, CLAW_L, EAR_L, EMPTY, EYE_L, FAR, GLOW_L, GROUND, MANE_L, MARK_L,
                   MUZZLE_L, NOSE_L, SIZE, colorize, mirror_half)

SIDE_FRAME = 3  # khung "chân trước chạm đất": dáng đứng vững, đọc rõ nhất


def draw_down():
    """Đi xuống: mặt hướng về camera, lưng lùi ra sau (phía trên màn hình). Mặt thon chữ V về phía mõm."""
    lab = Image.new("L", (SIZE, SIZE), EMPTY)
    d = ImageDraw.Draw(lab)
    d.line([(19, 26), (18, 35)], fill=FAR, width=3)  # chân sau phía xa
    d.ellipse([16, 34, 20, 37], fill=FAR)
    d.ellipse([17, 12, 30, 30], fill=BODY)  # lưng lùi ra sau
    d.ellipse([14, 19, 33, 31], fill=MANE_L)  # bờm quanh cổ
    d.polygon([(15, 21), (11, 22), (14, 24)], fill=MANE_L)
    d.polygon([(14, 25), (11, 28), (15, 28)], fill=MANE_L)
    d.line([(20, 30), (20, 39)], fill=BODY, width=3)  # chân trước
    d.ellipse([17, 38, 22, 41], fill=BODY)
    d.ellipse([18, 26, 29, 35], fill=BODY)  # ngực
    d.ellipse([16, 14, 31, 25], fill=BODY)  # sọ
    d.polygon([(17, 21), (21, 29), (23, 30), (23, 21)], fill=BODY)  # má thon về mõm
    d.polygon([(20, 22), (22, 29), (23, 29), (23, 22)], fill=MUZZLE_L)  # sống mũi sáng
    d.polygon([(16, 18), (16, 8), (21, 15)], fill=BODY)  # tai
    d.point([(17, 12), (17, 13), (18, 14)], fill=EAR_L)
    d.point((19, 19), fill=EYE_L)  # mắt xếch
    d.point((20, 20), fill=GLOW_L)
    d.point((21, 30), fill=CLAW_L)  # nanh
    mirror_half(lab)
    # Chóp đuôi nhô sau lưng, lệch sang phải (để giữa thì trông như vương miện cùng hai tai).
    # Chỉ tô vào chỗ trống để đuôi nằm SAU thân.
    tail = Image.new("L", (SIZE, SIZE), EMPTY)
    ImageDraw.Draw(tail).polygon([(27, 16), (30, 8), (33, 6), (33, 11), (30, 17)], fill=BODY)
    lp, tp = lab.load(), tail.load()
    for yy in range(SIZE):
        for xx in range(SIZE):
            if tp[xx, yy] != EMPTY and lp[xx, yy] == EMPTY:
                lp[xx, yy] = tp[xx, yy]
    d.point([(23, 29), (24, 29)], fill=NOSE_L)  # mũi nhỏ ở chóp mõm
    d.point([(23, 15), (24, 15), (22, 16), (25, 16), (23, 17), (24, 17)], fill=MARK_L)  # linh văn trán
    return colorize(lab, 34)


def draw_up():
    """Đi lên: quay lưng về camera, thấy gáy, bờm gai, sống lưng, đùi sau và đuôi rủ xuống."""
    lab = Image.new("L", (SIZE, SIZE), EMPTY)
    d = ImageDraw.Draw(lab)
    d.ellipse([18, 8, 29, 17], fill=BODY)  # sau đầu
    d.polygon([(18, 12), (17, 3), (22, 9)], fill=BODY)  # tai nhọn (nhìn từ sau)
    d.line([(18, 21), (17, 32)], fill=FAR, width=3)  # chân trước phía xa
    d.ellipse([15, 31, 19, 34], fill=FAR)
    d.ellipse([15, 13, 32, 24], fill=MANE_L)  # bờm
    d.polygon([(16, 15), (15, 9), (19, 14)], fill=MANE_L)  # gai bờm
    d.polygon([(20, 13), (21, 8), (23, 13)], fill=MANE_L)
    d.ellipse([16, 16, 31, 34], fill=BODY)  # lưng
    d.ellipse([14, 26, 22, 37], fill=BODY)  # đùi sau
    d.line([(17, 35), (17, 40)], fill=BODY, width=3)
    d.ellipse([15, 39, 20, 42], fill=BODY)
    d.line([(23, 17), (23, 32)], fill=MANE_L, width=1)  # sống lưng sẫm
    d.point([(19, 20), (18, 21), (20, 21), (19, 22)], fill=MARK_L)  # linh văn hai bả vai
    mirror_half(lab)
    # Đuôi xù rủ xuống, lệch sang phải một chút (không đối xứng → có cảm giác chuyển động).
    d.polygon([(21, 31), (26, 31), (28, 36), (26, 43), (24, 44), (22, 38)], fill=BODY)
    return colorize(lab, 36)


def directions():
    right = wolf_run.draw_frame(SIDE_FRAME)
    return {
        "phải": right,
        "trái": right.transpose(Image.FLIP_LEFT_RIGHT),
        "đi xuống": draw_down(),
        "đi lên": draw_up(),
    }


def build_sheet(out_path):
    font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    bold_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
    title_f = ImageFont.truetype(bold_path, 26)
    label_f = ImageFont.truetype(bold_path, 18)
    small_f = ImageFont.truetype(font_path, 14)
    paper = (233, 236, 228)
    muted = (154, 168, 157)
    jade = (111, 211, 176)

    dirs = directions()
    scale = 5
    cell = SIZE * scale
    gap = 28
    margin = 32
    width = margin * 2 + cell * 4 + gap * 3
    height = 900
    img = Image.new("RGB", (width, height), GROUND[:3])
    d = ImageDraw.Draw(img)

    d.text((margin, 24), "Sói yêu — ảnh duyệt 4 hướng", font=title_f, fill=paper)
    d.text((margin, 60), "Pixel art 48×48 px, phóng to ×5. Hướng trái = hướng phải lật ngang, nên chỉ cần vẽ 3 hướng.",
           font=small_f, fill=muted)

    top = 100
    notes = {
        "phải": "Khung \"chân trước chạm đất\" của animation Chạy",
        "trái": "Lật ngang từ hướng phải (không vẽ thêm)",
        "đi xuống": "Mặt, ngực hướng về camera; linh văn trên trán",
        "đi lên": "Quay lưng: bờm gai, sống lưng, đuôi rủ",
    }
    for k, (name, spr) in enumerate(dirs.items()):
        x = margin + k * (cell + gap)
        frame = Image.new("RGBA", (SIZE, SIZE), GROUND)
        frame.alpha_composite(spr)
        img.paste(frame.resize((cell, cell), Image.NEAREST), (x, top))
        d.rectangle([x - 1, top - 1, x + cell, top + cell], outline=(52, 68, 58))
        d.text((x, top + cell + 12), "Hướng " + name, font=label_f, fill=jade)
        for i, line in enumerate(_wrap(notes[name], small_f, cell)):
            d.text((x, top + cell + 38 + i * 18), line, font=small_f, fill=muted)

    # Kích thước thật trong game: vài con sói các hướng giữa dơi và người chơi, ở tỉ lệ 1:1 rồi ×2.
    y2 = top + cell + 104
    d.text((margin, y2), "Kích thước thật trong game", font=label_f, fill=paper)
    d.text((margin, y2 + 26), "Trái: tỉ lệ 1:1 như trên màn hình. Phải: cùng cảnh phóng ×2. "
           "Chấm xanh = người chơi, chấm tím = dơi.", font=small_f, fill=muted)
    scene = Image.new("RGBA", (300, 170), GROUND)
    sd = ImageDraw.Draw(scene)
    for bx, by in ((40, 30), (250, 40), (60, 140), (230, 140), (150, 25), (270, 100)):
        sd.ellipse([bx - 10, by - 10, bx + 10, by + 10], fill=(138, 92, 214), outline=(20, 20, 26))
    sd.ellipse([134, 69, 166, 101], fill=(77, 230, 255), outline=(0, 0, 0))
    placed = [("phải", 60, 62), ("trái", 196, 70), ("đi xuống", 128, 0), ("đi lên", 120, 116),
              ("phải", 10, 90), ("đi xuống", 200, 4)]
    for name, sx, sy in placed:
        scene.alpha_composite(dirs[name], (sx, sy))
    y3 = y2 + 58
    img.paste(scene, (margin, y3))
    img.paste(scene.resize((600, 340), Image.NEAREST), (margin + 300 + gap, y3))
    d.text((margin, y3 + 350), "Số khung khi làm đủ: Chạy 6 khung × 3 hướng vẽ = 18 khung (hướng trái lật lại).",
           font=small_f, fill=muted)
    img = img.crop((0, 0, width, y3 + 380))
    img.save(out_path)
    print("đã ghi", out_path)


def _wrap(text, font, width):
    lines, cur = [], ""
    for word in text.split(" "):
        trial = (cur + " " + word).strip()
        if font.getlength(trial) <= width or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    lines.append(cur)
    return lines


if __name__ == "__main__":
    build_sheet(sys.argv[1] if len(sys.argv) > 1 else str(Path("wolf_directions.png")))
