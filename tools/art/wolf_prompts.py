"""Nguồn duy nhất của prompt tạo ảnh Sói yêu. Ghép sẵn mỗi prompt thành một khối hoàn chỉnh.

    python3 tools/art/wolf_prompts.py            # in bộ prompt giai đoạn 1 dạng Markdown
    python3 tools/art/wolf_prompts.py --json     # in dạng JSON (trang artifact dùng)

Giai đoạn 1: chỉ Đi + Chạy cho 5 hướng vẽ (ảnh tĩnh dùng concept, 3 hướng phía trái lật ngang).
"""
import json
import sys

COMMON = (
    "pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, "
    "large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, "
    "jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, "
    "large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small "
    "floating flames, lavender-blue outline (no black outline), same palette, same proportions "
    "(head about 40% of body height), plain white background, no ground shadow, full body, centered, no text"
)

NEGATIVE = (
    "realistic, 3d render, painterly, blurry, anti-aliased edges, gradient background, ground shadow, "
    "cropped, extra limbs, extra tails, different character, different colors, text, watermark, frame, border, "
    "frames of different sizes, character changing size between frames"
)

SHEET = (
    "sprite sheet, {n} frames in one horizontal row, evenly spaced, every frame the same size and the same "
    "character scale, feet on the same ground line in every frame, seamless loop where the last frame flows "
    "back into the first"
)

# (mã, tên tiếng Việt, mô tả góc nhìn)
DIRECTIONS = [
    ("up", "Lên",
     "back view, the wolf faces straight away from the camera, we see the back of the head, both ears from "
     "behind, the scarf knot on the back, tail flame rising in front of the body toward the camera"),
    ("upright", "Chéo lên-phải",
     "three-quarter back view, body turned up and to the right, head turned away from the camera, one ear "
     "and part of the cheek visible, tail flame on the lower left"),
    ("right", "Phải",
     "side view facing right, full profile, only the near eye visible, pendant hanging under the chin, "
     "tail flame behind on the left"),
    ("down", "Xuống",
     "front view facing straight toward the camera, symmetrical, both eyes and the forehead rune clearly "
     "visible, pendant centered on the chest, tail flame visible behind the body above the back"),
    ("downleft", "Chéo xuống-trái",
     "three-quarter front view, body turned down and to the left, same camera angle as the reference image"),
]

# (mã, tên tiếng Việt, số khung, mô tả chuyển động)
ACTIONS = [
    ("walk", "Đi", 6,
     "walking trot cycle: 1 front-left and hind-right paws step forward, 2 weight shifts onto them and the "
     "body dips slightly, 3 legs pass under the body and the body is at its highest, 4 front-right and "
     "hind-left paws step forward, 5 weight shifts and the body dips, 6 legs pass under the body; small "
     "bouncy chibi steps, head steady, ears and tail flame swaying gently"),
    ("run", "Chạy", 6,
     "running gallop cycle: 1 gather with legs under the body, 2 hind legs push off, 3 full extension in the "
     "air with front legs reaching forward and hind legs stretched back, 4 front paws land, 5 front legs push "
     "while hind legs swing forward, 6 hind paws land; ears pinned back, tail flame streaming behind"),
]


def prompts():
    """Danh sách prompt giai đoạn 1, mỗi phần tử: file, hướng, hành động, số khung, prompt hoàn chỉnh."""
    out = []
    for act, act_name, n, act_text in ACTIONS:
        for d, d_name, d_text in DIRECTIONS:
            out.append({
                "file": f"wolf_{d}_{act}.png",
                "direction": d_name,
                "action": act_name,
                "frames": n,
                "prompt": ", ".join([COMMON, d_text, SHEET.format(n=n), act_text]),
            })
    return out


def markdown():
    items = prompts()
    lines = [
        f"**{len(items)} prompt** (2 hành động × {len(DIRECTIONS)} hướng). Mỗi khối dưới đây đã ghép đủ, "
        "chép nguyên khối dán vào công cụ tạo ảnh, đính kèm `wolf_concept.webp`.",
        "",
        "| # | Tên file gửi lại | Hành động | Hướng | Khung |",
        "|---|---|---|---|---|",
    ]
    for i, p in enumerate(items, 1):
        lines.append(f"| {i} | `{p['file']}` | {p['action']} | {p['direction']} | {p['frames']} |")
    lines.append("")
    for i, p in enumerate(items, 1):
        lines += [f"#### {i}. {p['action']} · {p['direction']} → `{p['file']}`", "", "```", p["prompt"], "```", ""]
    lines += ["#### Prompt phủ định (dùng chung, nếu công cụ có ô \"negative prompt\")", "", "```", NEGATIVE, "```"]
    return "\n".join(lines)


if __name__ == "__main__":
    if "--json" in sys.argv:
        print(json.dumps({"negative": NEGATIVE, "prompts": prompts()}, ensure_ascii=False, indent=1))
    else:
        print(markdown())
