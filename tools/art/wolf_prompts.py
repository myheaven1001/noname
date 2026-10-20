"""Nguồn duy nhất của prompt tạo ảnh Sói yêu. Ghép sẵn mỗi prompt thành một khối hoàn chỉnh.

    python3 tools/art/wolf_prompts.py                # in bộ prompt giai đoạn 1 dạng Markdown
    python3 tools/art/wolf_prompts.py --phase 2      # giai đoạn 2
    python3 tools/art/wolf_prompts.py --describe     # prompt miêu tả nhân vật (dán một lần đầu cuộc trò chuyện)
    python3 tools/art/wolf_prompts.py --brief claw   # prompt miêu tả hành động Cào + câu yêu cầu ngắn từng hướng
    python3 tools/art/wolf_prompts.py --todo         # chỉ các prompt chưa có ảnh trong assets/enemies/wolf
    python3 tools/art/wolf_prompts.py --json         # in mọi giai đoạn dạng JSON (trang artifact dùng)

Giai đoạn 1: Đi + Chạy cho 5 hướng vẽ (ảnh tĩnh dùng concept, 3 hướng phía trái lật ngang).
Giai đoạn 2: Cào + Gồng + Nghỉ + Chết, đủ để mọi trạng thái của Sói yêu (wolf.gd) có hình riêng:
Đuổi = Đi, Gồng cào + Cào = Cào, Gồng = Gồng, Lao = Chạy, Nghỉ = Nghỉ. Trúng đòn dùng nháy trắng có sẵn.

Nguyên tắc tách lớp: dải nhân vật chỉ vẽ con sói (kể cả lửa đuôi, phù văn phát sáng vì đó là một phần
thân). Hiệu ứng rời khỏi thân (vệt vuốt, tan biến) là hình riêng trong VFX: game xoay theo hướng đòn,
vẽ to hơn ô nhân vật, cộng sáng (nền đen thành trong suốt) và dùng lại cho mọi hướng.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WOLF = ROOT / "assets/enemies/wolf"

# Prompt miêu tả: dán một lần ở đầu cuộc trò chuyện với công cụ tạo ảnh (kèm wolf_concept.webp) để công cụ
# nhớ nhân vật, phong cách và quy tắc sprite sheet; sau đó mỗi prompt hành động chỉ cần dán tiếp.
DESCRIPTION = """Character brief for every image in this conversation. Read it fully and follow it for every \
image I ask for. The attached image is the official reference.

CHARACTER: "Spirit Wolf" (Sói yêu), a small chibi spirit-beast wolf from a Chinese xianxia fantasy world. \
Cute but mystical, alert and a little fierce when attacking.

BODY: chibi proportions, the head is about 40% of the total height, short sturdy legs with round paws and \
small lavender claws. Fluffy white fur with a soft lavender tint, shaded in pale lavender-blue, with spiky \
tufts on the head, cheeks, chest and shoulders.

HEAD: large pointed ears with deep purple inner ears and dark violet tips. Big round purple eyes with one \
white highlight each. Small dark nose, tiny mouth.

RUNES: glowing purple swirl runes: one large spiral on the forehead, one on each cheek, two on the body \
and one on a front leg. They glow brighter when the wolf attacks or charges.

ACCESSORIES: a jade bi-disc pendant (round pale jade-green disc with a hole in the middle) hanging at the \
throat on a navy cord with small gold beads, ending in a royal-blue tassel; a navy-blue scarf with thin \
gold trim and gold cloud patterns, tied at the neck and draped over the shoulders.

TAIL: a large fluffy white tail that turns into blue spirit flame toward the tip (white at the base, \
light blue in the middle, royal blue at the edges), with small teardrop-shaped blue flames floating \
around the tail and body.

PALETTE: white and lavender fur, purple runes and eyes, blue spirit flame, navy and gold scarf, jade-green \
pendant, royal-blue tassel. Nothing else: no red, no black fur, no extra colors.

ART STYLE: clean high-detail pixel art for a 2D top-down action game, crisp pixel edges, lavender-blue \
outline (never black), soft cel shading, light from the upper left. Readable when shrunk to 64 pixels.

CAMERA: the game camera looks down at about 30 degrees, like classic top-down action RPGs. The reference \
image shows the three-quarter front view facing down-left. Other directions rotate the same character on \
the spot: up = back view, up-right = three-quarter back view, right = side view, down = front view.

SPRITE SHEET RULES (for every animation): one horizontal row of evenly spaced frames, every frame the same \
size, the wolf at the same scale in every frame, feet on the same ground line, plain white background, no \
ground shadow, no text, no frame borders. Draw only the wolf: no slash trails, motion lines or impact \
effects, unless I explicitly ask for a separate effect sprite on a black background.

KEEP THE SAME: same character, face, markings, accessories, colors and size as the reference in every \
image, every direction and every frame. Never add or remove parts, never change the outfit."""

# Prompt miêu tả hành động: dán sau prompt miêu tả nhân vật, trong cùng cuộc trò chuyện. Mô tả kỹ động tác,
# nhịp và cách đọc ở từng hướng; sau đó mỗi hướng chỉ cần một câu yêu cầu ngắn (ACTION_REQUESTS).
ACTION_BRIEFS = {
    "claw": """Action brief: CLAW SWIPE. Use it for every claw request in this conversation, together with \
the character brief.

PURPOSE IN THE GAME: the wolf's close-range attack. When the player is right next to it, the wolf stops, \
raises one front paw as a warning, then swipes once in front of itself. Frames 1-2 play during a short \
0.3 second wind-up (the player should see it coming and step away), frames 3-4 play as the hit lands and \
the wolf recovers. The animation plays once and does not loop.

4 FRAMES, KEY POSES:
1. ANTICIPATION: the wolf plants its hind legs, leans its weight back slightly and lifts one front paw off \
the ground, claws spreading. Ears go back, eyes narrow, the purple runes start to glow brighter.
2. WIND-UP PEAK: the paw is raised high, level with or above the ear, claws fully out, body coiled and \
leaning back, mouth slightly open showing small fangs. This is the clearest, most readable pose: \
exaggerate it so it reads as "about to strike" even at 64 pixels.
3. STRIKE: the paw has swung down and across the front of the body to the opposite side, claws leading, \
shoulders and head turned into the swipe, body leaning forward, fur and scarf flicked by the motion. \
The runes are at their brightest.
4. RECOVERY: the paw is back on the ground, body upright again, almost the neutral standing pose of the \
reference, runes back to normal glow. This frame must connect smoothly to the walk animation.

MOTION RULES: the wolf attacks in place: the hind paws and the other front paw stay planted, the body \
does not travel. Only the striking leg, the shoulders, head, ears, scarf and tail flame move. The tail \
flame reacts: it flares up a little in frames 2-3. Keep the same size and ground line as the walk \
animation of the same direction.

HOW EACH DIRECTION READS:
- right (side view): the near front paw rises in front of the chest, then swipes forward and down to the \
right, in front of the muzzle.
- down-left (three-quarter front, like the reference): the paw rises beside the face, then swipes down and \
across toward the lower left, in front of the chest.
- down (front view, facing the camera): the paw rises beside the head toward the camera, then swipes \
diagonally down across the chest; we see the paw pads and claws.
- up-right (three-quarter back view): the paw rises above the shoulder, visible past the head, then swipes \
forward and away from the camera toward the upper right.
- up (back view, straight away from the camera, symmetrical like the walk animation): the paw rises above \
one shoulder so it is visible over the head, then swipes forward away from the camera; we mostly see the \
back, the raised elbow and the paw outline.

NO EFFECTS: draw only the wolf. No claw streaks, slash arcs, motion lines or sparks in the air: the slash \
effect is a separate sprite added by the game.""",
}

# (hướng, câu yêu cầu ngắn) cho từng hướng, dùng sau prompt miêu tả nhân vật và hành động.
ACTION_REQUESTS = {
    "claw": {
        "up": "Claw swipe, facing up (back view, straight away from the camera, symmetrical), 4 frames, "
              "following the claw brief. Attached: the walk sheet of the same direction for size and angle.",
        "upright": "Claw swipe, facing up-right (three-quarter back view), 4 frames, following the claw brief. "
                   "Attached: the walk sheet of the same direction for size and angle.",
        "right": "Claw swipe, facing right (side view), 4 frames, following the claw brief. "
                 "Attached: the walk sheet of the same direction for size and angle.",
        "down": "Claw swipe, facing down (front view, toward the camera, symmetrical), 4 frames, following "
                "the claw brief. Attached: the down-left walk sheet for size.",
        "downleft": "Claw swipe, facing down-left (three-quarter front view, same angle as the reference), "
                    "4 frames, following the claw brief. Attached: the walk sheet of the same direction for "
                    "size and angle.",
    },
}

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
    "frames of different sizes, character changing size between frames, "
    "slash trails, claw streaks, motion lines, speed lines, impact effects, sparks away from the body"
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
     "claw swipe attack at close range, character only with no slash effect: 1 rears up slightly and raises "
     "one front paw with claws out, runes glowing, 2 paw pulled back high above the head, ready to strike, "
     "3 paw fully swung down and across the front of the body, claws extended, body leaning into the swipe, "
     "4 paw back on the ground in the neutral pose; body stays in place, no claw streaks or trails in the "
     "air (the slash effect is a separate sprite)", False, 2),
    ("windup", "Gồng", 3,
     "charging up before a dash, a clear warning pose: 1 stops and lowers the front of the body, ears turning "
     "back, 2 crouches deeper with weight on the hind legs, purple runes glowing brighter, 3 fully crouched and "
     "ready to spring, ears flat, eyes glowing intensely, tail flame flaring twice as large; the last frame is "
     "held until the dash starts", False, 2),
    ("recover", "Nghỉ", 4,
     "recovering after a dash: 1 skidding to a stop with front paws braced forward and the body leaning back, "
     "2 small stumble with the head dipping, 3 catching breath with tongue out and runes dimmed, 4 back to the "
     "neutral standing pose of the reference image; tail flame smaller and dimmer than usual", False, 2),
    ("death", "Chết", 3,
     "defeat animation, character only: 1 staggers with eyes squeezed shut and ears flat, 2 collapses onto "
     "its side, 3 lies still on the ground with eyes closed, tail flame small and dim; the body stays fully "
     "opaque in every frame (the game fades it out and plays a separate dissolve effect)", False, 2),
]

# Hiệu ứng tách khỏi nhân vật. Nền đen trơn: game vẽ cộng sáng nên đen thành trong suốt.
VFX_COMMON = (
    "pixel art game visual effect sprite, no character, glowing magical effect only, lavender-white and "
    "purple palette matching the reference image, crisp pixel edges, plain pure black background, no text"
)

# (file, tên tiếng Việt, số khung, mô tả)
VFX = [
    ("vfx_claw_slash.png", "Vệt vuốt", 3,
     "claw slash effect: three parallel curved claw streaks forming a crescent arc that bulges to the right, "
     "as if a paw swiped from top to bottom in front of a creature facing right, bright lavender-white core "
     "with a soft purple glow at the edges; 1 thin streaks just appearing, 2 full bright streaks, 3 streaks "
     "thinning and breaking into a few small sparks; arc centered in each frame with empty space around it"),
    ("vfx_spirit_dissolve.png", "Tan biến", 5,
     "spirit dissolve effect seen from the side, for a defeated spirit beast: 1 a burst of blue spirit flame "
     "wisps and purple rune sparks at ground level, 2 wisps rising and spreading, 3 wisps higher and thinner, "
     "a few spinning purple swirl runes, 4 only scattered small flames and sparks drifting upward, 5 a few "
     "tiny fading sparks; effect grows upward from the bottom center of each frame"),
]

VFX_NEGATIVE = (
    "character, animal, wolf, body, face, paws, realistic, 3d render, blurry, gradient background, white "
    "background, text, watermark, frame, border, frames of different sizes"
)

VFX_SHEET = (
    "sprite sheet, {n} frames in one horizontal row, evenly spaced, every frame the same size, the effect at "
    "the same position and scale in every frame, plays once from left to right"
)

# Sửa dải đã tạo thay vì tạo lại: dùng với công cụ chỉnh ảnh (đính kèm dải cũ).
CLAW_CLEANUP = (
    "edit the attached sprite sheet: remove every claw slash streak, motion trail and floating slash spark "
    "from all frames; keep the wolf, its pose, its blue tail flame and the small floating flames around the "
    "tail exactly as they are; fill the removed areas with the same plain white background; do not change "
    "the image size, the frame layout, or the position and size of the wolf"
)
CLAW_DIRS = ["up", "upright", "right", "down", "downleft"]
CLAW_SENT = {"right": "11", "up": "12", "upright": "13", "down": "14", "downleft": "15"}  # ảnh đã gửi trong chat



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


def vfx_prompts():
    return [{"file": f, "direction": "—", "action": "VFX " + name, "frames": n,
             "prompt": ", ".join([VFX_COMMON, VFX_SHEET.format(n=n), text])} for f, name, n, text in VFX]


def cleanup_prompts():
    """Prompt sửa dải Cào đã có (bỏ vệt vuốt). Đính kèm dải cũ cùng hướng."""
    names = dict((d, n) for d, n, _ in DIRECTIONS)
    return [{"file": f"wolf_{d}_claw.png", "direction": names[d], "action": "Sửa Cào", "frames": 4,
             "attach": f"assets/enemies/wolf/claw/raw/wolf_{d}_claw.webp", "prompt": CLAW_CLEANUP}
            for d in CLAW_DIRS]


def _done(p):
    if p["action"].startswith("VFX"):
        return (ROOT / "assets/vfx" / p["file"]).exists()
    if p["action"] == "Sửa Cào":
        # Dải Cào đã làm sạch được đánh dấu trong report_claw.json ("clean": true) sau khi xử lý lại.
        report = WOLF / "claw/report_claw.json"
        return report.exists() and json.loads(report.read_text()).get("clean", False)
    act = p["file"].rsplit("_", 1)[1].removesuffix(".png")
    return (WOLF / act / p["file"]).exists()


def todo():
    """Các prompt còn cần làm, theo thứ tự ưu tiên: dải giai đoạn 1 còn thiếu, sửa dải Cào và VFX
    (đang dùng trong game), rồi các hành động giai đoạn 2 còn thiếu."""
    p1 = [p for p in prompts(1) if not _done(p)]
    fix = [p for p in cleanup_prompts() + vfx_prompts() if not _done(p)]
    p2 = [p for p in prompts(2) if not _done(p)]
    return p1 + fix + p2


def attach(p):
    """Ảnh cần đính kèm khi chạy prompt này."""
    if p["action"] == "Sửa Cào":
        d = p["file"].split("_")[1]
        return f"chỉ dải Cào cũ hướng này (ảnh {CLAW_SENT[d]}.webp đã gửi, trong repo: `{p['attach']}`)"
    if p["action"].startswith("VFX"):
        return "`wolf_concept.webp` (để lấy màu)"
    if p["file"].startswith("wolf_down_"):
        return "`wolf_concept.webp` + dải Đi chéo xuống-trái"
    return "`wolf_concept.webp` + dải Đi cùng hướng"


def markdown(phase=1):
    items = todo() if phase == "todo" else prompts(phase)
    lines = [
        f"**{len(items)} prompt**. Mỗi khối dưới đây đã ghép đủ, chép nguyên khối dán vào công cụ tạo ảnh "
        "và đính kèm ảnh ghi ở cột \"Đính kèm\".",
        "",
        "| # | Tên file gửi lại | Việc | Hướng | Khung | Đính kèm |",
        "|---|---|---|---|---|---|",
    ]
    for i, p in enumerate(items, 1):
        lines.append(f"| {i} | `{p['file']}` | {p['action']} | {p['direction']} | {p['frames']} | {attach(p)} |")
    lines.append("")
    for i, p in enumerate(items, 1):
        lines += [f"#### {i}. {p['action']} · {p['direction']} → `{p['file']}`", "", "```", p["prompt"], "```", ""]
    lines += ["#### Prompt phủ định cho dải nhân vật (nếu công cụ có ô \"negative prompt\")", "", "```",
              NEGATIVE, "```", "", "#### Prompt phủ định cho VFX", "", "```", VFX_NEGATIVE, "```"]
    return "\n".join(lines)


if __name__ == "__main__":
    if "--json" in sys.argv:
        items = todo()
        for p in items:
            p["attach_note"] = attach(p).replace("`", "")
        print(json.dumps({"description": DESCRIPTION, "briefs": ACTION_BRIEFS, "requests": ACTION_REQUESTS, "negative": NEGATIVE, "vfx_negative": VFX_NEGATIVE, "prompts": prompts(),
                          "vfx": vfx_prompts(), "todo": items}, ensure_ascii=False, indent=1))
    elif "--describe" in sys.argv:
        print(DESCRIPTION)
    elif "--brief" in sys.argv:
        act = sys.argv[sys.argv.index("--brief") + 1]
        print(ACTION_BRIEFS[act])
        print()
        for d, req in ACTION_REQUESTS[act].items():
            print(f"[{d}] wolf_{d}_{act}.png\n{req}\n")
    elif "--todo" in sys.argv:
        print(markdown("todo"))
    else:
        phase = int(sys.argv[sys.argv.index("--phase") + 1]) if "--phase" in sys.argv else 1
        print(markdown(phase))
