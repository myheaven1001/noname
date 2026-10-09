"""Từ ảnh mẫu (pixel art đã phóng to, nền trắng) → sprite gốc nền trong, các cỡ dùng trong game,
bảng màu, và tấm so sánh kích thước trong cảnh chơi thật.

    python3 tools/art/reference_scale.py assets/enemies/wolf/reference/wolf_concept.webp out_dir
"""
import collections
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

GROUND = (23, 32, 26, 255)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def native_grid(img, cell):
    """Lấy mẫu ở tâm mỗi ô `cell` px để khôi phục ảnh pixel gốc."""
    n = round(img.width / cell)
    step = img.width / n
    out = Image.new("RGBA", (n, n))
    src, dst = img.load(), out.load()
    for y in range(n):
        for x in range(n):
            dst[x, y] = src[int((x + 0.5) * step), int((y + 0.5) * step)]
    return out


def remove_background(img, threshold=232):
    """Xoá nền trắng nối liền với mép ảnh (loang từ 4 góc), giữ chi tiết trắng bên trong nhân vật."""
    w, h = img.size
    px = img.load()
    seen = set()
    stack = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        r, g, b, a = px[x, y]
        if min(r, g, b) < threshold:
            continue
        seen.add((x, y))
        px[x, y] = (0, 0, 0, 0)
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return img.crop(img.getbbox())


def shrink(sprite, height, colors=None):
    """Thu nhỏ giữ độ nét pixel: lọc LANCZOS, cắt alpha cứng (viền sắc, không bán trong suốt).

    `colors` = số màu để gom bảng màu; mặc định không gom: ở cỡ 64 px, gom màu (kể cả 64 màu) làm
    mất các chi tiết ít điểm ảnh như ngọc bội ngọc bích và hạt vàng.
    """
    w = round(sprite.width * height / sprite.height)
    small = sprite.resize((w, height), Image.LANCZOS)
    alpha = small.getchannel("A").point(lambda a: 255 if a >= 110 else 0)
    rgb = small.convert("RGB")
    if colors:
        rgb = rgb.quantize(colors, method=Image.Quantize.MEDIANCUT).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def palette(sprite, n=14):
    counts = collections.Counter()
    for r, g, b, a in sprite.convert("RGBA").get_flattened_data():
        if a:
            counts[(r // 12 * 12, g // 12 * 12, b // 12 * 12)] += 1
    return [c for c, _ in counts.most_common(n)]


def scene(sprite_by_size, size, scale):
    """Cảnh 300x170 giống cảnh chơi: người chơi giữa, dơi xung quanh, sói cỡ `size` (lật để có 2 hướng)."""
    sc = Image.new("RGBA", (300, 170), GROUND)
    d = ImageDraw.Draw(sc)
    for bx, by in ((30, 25), (270, 30), (40, 150), (260, 150), (150, 18), (285, 95)):
        d.ellipse([bx - 10, by - 10, bx + 10, by + 10], fill=(138, 92, 214), outline=(20, 20, 26))
    d.ellipse([134, 69, 166, 101], fill=(77, 230, 255), outline=(0, 0, 0))
    spr = sprite_by_size[size]
    flip = spr.transpose(Image.FLIP_LEFT_RIGHT)
    for img, x, y in ((spr, 185, 60), (flip, 115 - spr.width, 55), (spr, 60, 110), (flip, 200, 110)):
        sc.alpha_composite(img, (x, y))
    return sc.resize((300 * scale, 170 * scale), Image.NEAREST)


def main(src, out_dir):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    big = Image.open(src).convert("RGBA")
    native = remove_background(native_grid(big, 7.84))
    native.save(out_dir / "wolf_concept_native.png")
    sizes = {96: shrink(native, 96), 64: shrink(native, 64), 48: shrink(native, 48)}
    for h, img in sizes.items():
        img.save(out_dir / f"wolf_concept_{h}.png")

    title_f, label_f, small_f = ImageFont.truetype(BOLD, 24), ImageFont.truetype(BOLD, 16), ImageFont.truetype(FONT, 13)
    paper, muted, jade = (233, 236, 228), (154, 168, 157), (111, 211, 176)
    W = 1240
    sheet = Image.new("RGB", (W, 1300), GROUND[:3])
    d = ImageDraw.Draw(sheet)
    d.text((32, 22), "Mẫu Sói yêu — độ dễ nhìn ở các cỡ trong game", font=title_f, fill=paper)
    d.text((32, 56), f"Ảnh gốc là pixel art {native.width}×{native.height} px (sau khi cắt nền). "
           "Cột trái: sprite phóng ×3 để xem chi tiết. Cột phải: cảnh chơi (người chơi, dơi) phóng ×2.",
           font=small_f, fill=muted)
    y = 92
    notes = {
        96: "96 px: gần như giữ đủ chi tiết (mắt, phù văn, ngọc bội, lửa). Hợp với tinh anh / boss.",
        64: "64 px: còn đọc được mắt tím, ngọc bội, lửa xanh; phù văn nhoè thành chấm.",
        48: "48 px (cỡ quái thường hiện tại): còn dáng và màu, mất gần hết chi tiết nhỏ.",
    }
    for h in (96, 64, 48):
        spr = sizes[h]
        box = Image.new("RGBA", (300, 300), GROUND)
        z = spr.resize((spr.width * 3, spr.height * 3), Image.NEAREST)
        box.alpha_composite(z, ((300 - z.width) // 2, (300 - z.height) // 2))
        sheet.paste(box, (32, y))
        sc = scene(sizes, h, 2)
        sheet.paste(sc, (360, y - 20))
        d.text((32, y + 304), f"Cỡ {h} px", font=label_f, fill=jade)
        d.text((360, y + 324), notes[h] + "  (cảnh phải đã phóng ×2 để dễ nhìn)", font=small_f, fill=muted)
        y += 370
    # Bảng màu
    d.text((32, y), "Bảng màu rút từ mẫu", font=label_f, fill=paper)
    for k, c in enumerate(palette(native)):
        x = 32 + k * 84
        d.rectangle([x, y + 28, x + 70, y + 68], fill=c, outline=(52, 68, 58))
        d.text((x, y + 72), "#%02x%02x%02x" % c, font=small_f, fill=muted)
    sheet = sheet.crop((0, 0, W, y + 100))
    sheet.save(out_dir / "wolf_concept_scale_check.png")
    print("đã ghi", out_dir)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
