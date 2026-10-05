"""Bộ công cụ pixel art dùng chung cho sprite quái: bảng màu, nhãn vật liệu, tô màu, viền.

Mỗi sprite được vẽ thành bản đồ nhãn (mỗi pixel là một vật liệu: lông, lông phía xa, mắt...),
rồi `colorize` tô màu theo bảng màu chung, đổ sáng từ trên xuống và viền 1px. Nhờ vậy mọi hướng,
mọi hành động của mọi loại quái có cùng một phong cách.
"""
import math

from PIL import Image

SIZE = 48

# Bảng màu Sói yêu: lông xám rêu như màu sói trong game (#9aab8f), mắt đỏ yêu thú, linh văn ngọc bích.
OUTLINE = (10, 14, 12, 255)  # gần đen: phải tách khỏi màu đất tối của bản đồ
FUR_LIGHT = (196, 210, 182, 255)
FUR = (150, 167, 141, 255)
FUR_SHADE = (106, 123, 106, 255)
FUR_FAR = (74, 88, 77, 255)
MANE = (88, 103, 90, 255)
EYE = (255, 70, 52, 255)
EYE_GLOW = (255, 170, 120, 255)
CLAW = (233, 236, 228, 255)
EAR_IN = (178, 104, 92, 255)
MARK = (111, 211, 176, 255)
NOSE = (20, 24, 22, 255)
MUZZLE = (176, 190, 165, 255)

GROUND = (23, 32, 26, 255)  # màu đất của cảnh chơi, dùng làm nền xem trước

# Nhãn vật liệu
EMPTY, BODY, FAR, EYE_L, CLAW_L, EAR_L, MARK_L, MANE_L, GLOW_L, NOSE_L, MUZZLE_L = range(11)

_FLAT = {
    FAR: FUR_FAR, EYE_L: EYE, CLAW_L: CLAW, EAR_L: EAR_IN, MARK_L: MARK, MANE_L: MANE,
    GLOW_L: EYE_GLOW, NOSE_L: NOSE, MUZZLE_L: MUZZLE,
}


def leg(draw, label, hip, upper_deg, bend_deg, upper=6.5, lower=7.0, width=4):
    """Chân 2 đoạn (đùi + cẳng) nhìn ngang. Góc tính từ phương thẳng đứng, dương = về phía trước."""
    a = math.radians(upper_deg)
    knee = (hip[0] + math.sin(a) * upper, hip[1] + math.cos(a) * upper)
    b = math.radians(upper_deg + bend_deg)
    paw = (knee[0] + math.sin(b) * lower, knee[1] + math.cos(b) * lower)
    draw.line([hip, knee], fill=label, width=width)
    draw.line([knee, paw], fill=label, width=width - 1)
    draw.ellipse([knee[0] - 1.5, knee[1] - 1.5, knee[0] + 1.5, knee[1] + 1.5], fill=label)
    draw.ellipse([paw[0] - 2, paw[1] - 1, paw[0] + 2, paw[1] + 1], fill=label)
    return paw


def colorize(lab, shade_from_y):
    """Tô màu bản đồ nhãn: lông có viền sáng phía trên, tối dần từ `shade_from_y` trở xuống; viền 1px."""
    src = lab.load()
    w, h = lab.size
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        for x in range(w):
            v = src[x, y]
            if v == EMPTY:
                continue
            if v == BODY:
                above = src[x, y - 1] if y > 0 else EMPTY
                if above == EMPTY:
                    c = FUR_LIGHT
                elif y >= shade_from_y:
                    c = FUR_SHADE
                else:
                    c = FUR
            else:
                c = _FLAT[v]
            px[x, y] = c
    out = img.copy()
    op = out.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3]:
                    op[x, y] = OUTLINE
                    break
    return out


def mirror_half(lab):
    """Chép nửa trái của bản đồ nhãn sang nửa phải (cho hướng nhìn thẳng trước/sau đối xứng)."""
    w, h = lab.size
    px = lab.load()
    for y in range(h):
        for x in range(w // 2):
            v = px[x, y]
            if v != EMPTY:
                px[w - 1 - x, y] = v
    return lab
