"""Nguồn duy nhất của prompt tạo ảnh Sói yêu. Ghép sẵn mỗi prompt thành một khối hoàn chỉnh.

    python3 tools/art/wolf_prompts.py                # in bộ prompt giai đoạn 1 dạng Markdown
    python3 tools/art/wolf_prompts.py --phase 2      # giai đoạn 2
    python3 tools/art/wolf_prompts.py --todo         # chỉ các prompt chưa có ảnh trong assets/enemies/wolf
    python3 tools/art/wolf_prompts.py --json         # in mọi giai đoạn dạng JSON (trang artifact dùng)

Giai đoạn 1: Đi + Chạy cho 5 hướng vẽ (ảnh tĩnh dùng concept, 3 hướng phía trái lật ngang).
Giai đoạn 2: Cào + Gồng + Nghỉ + Chết, đủ để mọi trạng thái của Sói yêu (wolf.gd) có hình riêng:
Đuổi = Đi, Gồng cào + Cào = Cào, Gồng = Gồng, Lao = Chạy, Nghỉ = Nghỉ. Trúng đòn dùng nháy trắng có sẵn.
"""
import json
import sys
from pathlib import Path

WOLF = Path(__file__).resolve().parents[2] / "assets/enemies/wolf"

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

# Hành động chạy một lần (không lặp): bỏ câu "seamless loop", nói rõ khung đầu và cuối.
SHEET_ONCE = (
    "sprite sheet, {n} frames in one horizontal row, evenly spaced, every frame the same size and the same "
    "character scale, feet on the same ground line in every frame, plays once from left to right and does "
    "not loop"
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

# (mã, tên tiếng Việt, số khung, mô tả chuyển động, lặp, giai đoạn)
ACTIONS = [
    ("walk", "Đi", 6,
     "walking trot cycle: 1 front-left and hind-right paws step forward, 2 weight shifts onto them and the "
     "body dips slightly, 3 legs pass under the body and the body is at its highest, 4 front-right and "
     "hind-left paws step forward, 5 weight shifts and the body dips, 6 legs pass under the body; small "
     "bouncy chibi steps, head steady, ears and tail flame swaying gently", True, 1),
    ("run", "Chạy", 6,
     "running gallop cycle: 1 gather with legs under the body, 2 hind legs push off, 3 full extension in the "
     "air with front legs reaching forward and hind legs stretched back, 4 front paws land, 5 front legs push "
     "while hind legs swing forward, 6 hind paws land; ears pinned back, tail flame streaming behind", True, 1),
    ("claw", "Cào", 4,
     "claw swipe attack at close range: 1 rears up slightly and raises one front paw with claws out, runes "
     "glowing, 2 paw pulled back high, ready to strike, 3 fast swipe across the front with three bright "
     "lavender-white claw streaks in the air, 4 paw back on the ground in the neutral pose; body stays in "
     "place", False, 2),
    ("windup", "Gồng", 3,
     "charging up before a dash, a clear warning pose: 1 stops and lowers the front of the body, ears turning "
     "back, 2 crouches deeper with weight on the hind legs, purple runes glowing brighter, 3 fully crouched and "
     "ready to spring, ears flat, eyes glowing intensely, tail flame flaring twice as large; the last frame is "
     "held until the dash starts", False, 2),
    ("recover", "Nghỉ", 4,
     "recovering after a dash: 1 skidding to a stop with front paws braced forward and the body leaning back, "
     "2 small stumble with the head dipping, 3 catching breath with tongue out and runes dimmed, 4 back to the "
     "neutral standing pose of the reference image; tail flame smaller and dimmer than usual", False, 2),
    ("death", "Chết", 5,
     "defeat animation: 1 staggers with eyes squeezed shut, 2 collapses onto its side, 3 lies on the ground "
     "and the body starts to turn translucent, 4 dissolves into blue spirit flame wisps and purple rune "
     "sparks rising upward, 5 only a few small fading sparks remain where the body was", False, 2),
]


def prompts(phase=None):
    """Danh sách prompt (một giai đoạn hoặc tất cả), mỗi phần tử: file, hướng, hành động, số khung, prompt."""
    out = []
    for act, act_name, n, act_text, loop, ph in ACTIONS:
        if phase is not None and ph != phase:
            continue
        sheet = (SHEET if loop else SHEET_ONCE).format(n=n)
        for d, d_name, d_text in DIRECTIONS:
            out.append({
                "file": f"wolf_{d}_{act}.png",
                "direction": d_name,
                "action": act_name,
                "frames": n,
                "phase": ph,
                "prompt": ", ".join([COMMON, d_text, sheet, act_text]),
            })
    return out


def todo():
    """Các prompt chưa có dải đã xử lý (assets/enemies/wolf/<hành động>/wolf_<hướng>_<hành động>.png).
    Thứ tự ưu tiên: giai đoạn 1 trước, trong mỗi giai đoạn theo thứ tự ACTIONS."""
    out = []
    for p in prompts():
        act = p["file"].rsplit("_", 1)[1].removesuffix(".png")
        if not (WOLF / act / p["file"]).exists():
            out.append(p)
    return out


def markdown(phase=1):
    items = todo() if phase == "todo" else prompts(phase)
    n_act = len({p["action"] for p in items})
    lines = [
        f"**{len(items)} prompt** ({n_act} hành động × {len(DIRECTIONS)} hướng). Mỗi khối dưới đây đã ghép đủ, "
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
        print(json.dumps({"negative": NEGATIVE, "prompts": prompts(), "todo": todo()}, ensure_ascii=False, indent=1))
    elif "--todo" in sys.argv:
        print(markdown("todo"))
    else:
        phase = int(sys.argv[sys.argv.index("--phase") + 1]) if "--phase" in sys.argv else 1
        print(markdown(phase))
