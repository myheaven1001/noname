# Sói yêu — chuẩn phong cách theo mẫu

`wolf_concept.webp` là mẫu đã chọn. Mọi hướng, mọi hành động của Sói yêu phải khớp mẫu này.
`tools/art/reference_scale.py` khôi phục bản pixel gốc (`wolf_concept_native.png`, 157×150 px),
xoá nền và làm sẵn các cỡ 96 / 64 / 48 px cùng tấm so sánh `wolf_concept_scale_check.png`.

## Đặc điểm nhận dạng (giữ ở mọi hướng, mọi khung)

- Dáng chibi: đầu to, khoảng 40% chiều cao; mắt to màu tím có điểm sáng.
- Lông trắng ánh tím, bóng đổ xanh lavender, viền ngoài xanh tím đậm (không viền đen).
- Phù văn xoắn tím phát sáng: một trên trán, hai trên má, hai trên thân, một trên chân trước.
- Ngọc bội (đĩa ngọc bích có lỗ giữa) treo ở cổ, dây xanh navy hạt vàng, tua rua xanh.
- Khăn xanh navy viền vàng vắt qua vai.
- Đuôi xù chuyển thành ngọn lửa linh hồn xanh lam, có đốm lửa nhỏ bay quanh.
- Hai tai to nhọn, trong tai tím.

## Cỡ đề xuất trong game

| Loại | Cỡ sprite | Ghi chú |
|---|---|---|
| Sói yêu thường | 64 px | Còn đọc được mắt, ngọc bội, lửa. Bán kính va chạm cần tăng từ 14 lên khoảng 20 |
| Sói tinh anh | 96 px | Đủ chi tiết phù văn; có thể đổi màu lửa (vd. tím đỏ) để phân biệt |
| 48 px | Không khuyến nghị | Chỉ còn dáng và màu |

## Hướng và số khung

8 hướng (sơ đồ: `wolf_8_directions_map.png`, tạo bằng `tools/art/direction_map.py`). Ba hướng phía trái
là bản lật ngang của ba hướng phía phải, nên chỉ vẽ 5 hướng. Ảnh mẫu chính là hướng **chéo xuống-trái**
(3/4, mặt về camera, thân sang trái); lật nó ra **chéo xuống-phải**.

| Hướng | Cách có |
|---|---|
| Lên | Vẽ |
| Chéo lên-phải | Vẽ |
| Phải | Vẽ |
| Chéo xuống-phải | Lật từ ảnh mẫu |
| Xuống | Vẽ |
| Chéo xuống-trái | **Ảnh mẫu** |
| Trái | Lật từ phải |
| Chéo lên-trái | Lật từ chéo lên-phải |

Lật ngang làm ngọc bội và khăn đổi sang vai bên kia; chấp nhận được (cách làm phổ biến). Nếu muốn
giữ đúng bên thì phải vẽ đủ 8 hướng (gần gấp đôi số khung).

**Giai đoạn 1 (đang làm):** quái gần như lúc nào cũng đi hoặc chạy, nên chỉ làm hai animation này.
Ảnh tĩnh dùng luôn ảnh concept.

| Hành động | Khi nào dùng | Khung / hướng | 5 hướng vẽ |
|---|---|---|---|
| Ảnh tĩnh | Áp sát người chơi, đứng chờ | (ảnh concept) | 0 |
| **Đi** | Đuổi người chơi (80 px/s), gần như toàn bộ thời gian | **6** | **30** |
| **Chạy** | Cú lao sau khi gồng (750 px/s, ~0,3 giây ≈ 1 vòng) | **6** | **30** |
| **Tổng giai đoạn 1** | | **12** | **60** |

**Giai đoạn 2:** mỗi trạng thái của Sói yêu trong `scripts/sim/behaviors/wolf.gd` có hình riêng,
cộng thêm Chết. Mọi con đều đuổi và cào; chỉ 10% số sói (cột `dash_chance`) biết lao:

- Đuổi → (cách người chơi ≤ tầm cào) Gồng cào 0,3 giây → Cào → Đuổi (hồi 1 giây)
- Đuổi → (con biết lao, cách người chơi ≤ 180 px) Gồng 0,5 giây → Lao 240 px → Nghỉ 0,6 giây → Đuổi

| Hành động | Trạng thái trong game | Khung / hướng | Lặp | 5 hướng vẽ |
|---|---|---|---|---|
| **Cào** | Gồng cào (khung 1–2) + vung vuốt và thu về (khung 3–4); vệt vuốt là VFX riêng | **4** | Không | **20** |
| **Gồng** | Gồng 0,5 giây, khoá hướng, báo trước cú lao | **3** | Không, giữ khung cuối | **15** |
| **Nghỉ** | Nghỉ 0,6 giây sau cú lao | **4** | Không | **20** |
| **Chết** | Bị hạ, nằm xuống; game làm mờ thân và phát VFX tan biến | **3** | Không | **15** |
| **Tổng giai đoạn 2** | | **14** | | **70** |

**Tách lớp nhân vật và hiệu ứng** (như timeline của Aseprite: Body, Head, VFX là các lớp riêng, lớp VFX chỉ
có hình ở các khung đánh). Dải nhân vật chỉ vẽ con sói; lửa đuôi và phù văn phát sáng là một phần thân nên
vẫn vẽ chung. Hiệu ứng rời khỏi thân là hình riêng, game xoay theo hướng đòn, vẽ to hơn ô nhân vật, cộng sáng
(nền đen thành trong suốt), và một hình dùng cho mọi hướng:

| VFX | Khung | Dùng khi |
|---|---|---|
| `vfx_claw_slash.png` | 3 | Khung 3 của Cào; vẽ cho hướng phải, game xoay |
| `vfx_spirit_dissolve.png` | 5 | Sau khung 3 của Chết, khi game làm mờ thân |

Dải Cào đã gửi (ảnh 11–15) có vệt vuốt vẽ dính vào thân. Game vẫn dùng được, nhưng nên sửa bằng prompt
"Sửa Cào" (công cụ chỉnh ảnh, đính kèm dải cũ) để bỏ vệt vuốt.

Không vẽ riêng (đã có cách khác rẻ hơn):

| Hành động | Lý do |
|---|---|
| Lao | Dùng dải Chạy: cú lao 0,4 giây ở 750 px/s, đúng một vòng phi |
| Trúng đòn | Renderer đã có nháy trắng (`custom.x`); 1 khung riêng gần như không thấy ở cỡ 64 px |
| Cắn | Đã có Cào làm đòn cận chiến |

Trong game: chọn hướng theo góc vận tốc chia 8 cung 45°; lúc gồng/lao dùng hướng đã khoá (`dir`).
Tốc độ animation Đi tính theo quãng đường (một vòng 6 khung ≈ một sải 32 px) để chân không "trượt
băng"; mỗi con bắt đầu ở khung ngẫu nhiên để đám đông không bước đều.

## Prompt cho công cụ tạo ảnh

### Prompt miêu tả nhân vật (dán một lần ở đầu cuộc trò chuyện)

Sinh từ `tools/art/wolf_prompts.py --describe`. Dán kèm `wolf_concept.webp` ở đầu mỗi cuộc trò chuyện với
công cụ tạo ảnh; công cụ nhớ nhân vật, phong cách, góc camera và quy tắc sprite sheet cho cả cuộc trò
chuyện. Sau đó dán từng prompt hành động như bình thường.

```
Character brief for every image in this conversation. Read it fully and follow it for every image I ask for. The attached image is the official reference.

CHARACTER: "Spirit Wolf" (Sói yêu), a small chibi spirit-beast wolf from a Chinese xianxia fantasy world. Cute but mystical, alert and a little fierce when attacking.

BODY: chibi proportions, the head is about 40% of the total height, short sturdy legs with round paws and small lavender claws. Fluffy white fur with a soft lavender tint, shaded in pale lavender-blue, with spiky tufts on the head, cheeks, chest and shoulders.

HEAD: large pointed ears with deep purple inner ears and dark violet tips. Big round purple eyes with one white highlight each. Small dark nose, tiny mouth.

RUNES: glowing purple swirl runes: one large spiral on the forehead, one on each cheek, two on the body and one on a front leg. They glow brighter when the wolf attacks or charges.

ACCESSORIES: a jade bi-disc pendant (round pale jade-green disc with a hole in the middle) hanging at the throat on a navy cord with small gold beads, ending in a royal-blue tassel; a navy-blue scarf with thin gold trim and gold cloud patterns, tied at the neck and draped over the shoulders.

TAIL: a large fluffy white tail that turns into blue spirit flame toward the tip (white at the base, light blue in the middle, royal blue at the edges), with small teardrop-shaped blue flames floating around the tail and body.

PALETTE: white and lavender fur, purple runes and eyes, blue spirit flame, navy and gold scarf, jade-green pendant, royal-blue tassel. Nothing else: no red, no black fur, no extra colors.

ART STYLE: clean high-detail pixel art for a 2D top-down action game, crisp pixel edges, lavender-blue outline (never black), soft cel shading, light from the upper left. Readable when shrunk to 64 pixels.

CAMERA: the game camera looks down at about 30 degrees, like classic top-down action RPGs. The reference image shows the three-quarter front view facing down-left. Other directions rotate the same character on the spot: up = back view, up-right = three-quarter back view, right = side view, down = front view.

SPRITE SHEET RULES (for every animation): one horizontal row of evenly spaced frames, every frame the same size, the wolf at the same scale in every frame, feet on the same ground line, plain white background, no ground shadow, no text, no frame borders. Draw only the wolf: no slash trails, motion lines or impact effects, unless I explicitly ask for a separate effect sprite on a black background.

KEEP THE SAME: same character, face, markings, accessories, colors and size as the reference in every image, every direction and every frame. Never add or remove parts, never change the outfit.
```

Luôn đính kèm `wolf_concept.webp` làm ảnh tham chiếu nhân vật. Prompt viết bằng tiếng Anh vì đa số
công cụ tạo ảnh hiểu tiếng Anh tốt nhất.

### Bộ prompt giai đoạn 1: Đi + Chạy (chép một lần là dùng được)

Sinh từ `tools/art/wolf_prompts.py` (nguồn duy nhất; sửa prompt ở đó rồi chạy lại để cập nhật mục này).

**10 prompt** (2 hành động × 5 hướng). Mỗi khối dưới đây đã ghép đủ, chép nguyên khối dán vào công cụ tạo ảnh, đính kèm `wolf_concept.webp`.

| # | Tên file gửi lại | Hành động | Hướng | Khung |
|---|---|---|---|---|
| 1 | `wolf_up_walk.png` | Đi | Lên | 6 |
| 2 | `wolf_upright_walk.png` | Đi | Chéo lên-phải | 6 |
| 3 | `wolf_right_walk.png` | Đi | Phải | 6 |
| 4 | `wolf_down_walk.png` | Đi | Xuống | 6 |
| 5 | `wolf_downleft_walk.png` | Đi | Chéo xuống-trái | 6 |
| 6 | `wolf_up_run.png` | Chạy | Lên | 6 |
| 7 | `wolf_upright_run.png` | Chạy | Chéo lên-phải | 6 |
| 8 | `wolf_right_run.png` | Chạy | Phải | 6 |
| 9 | `wolf_down_run.png` | Chạy | Xuống | 6 |
| 10 | `wolf_downleft_run.png` | Chạy | Chéo xuống-trái | 6 |

#### 1. Đi · Lên → `wolf_up_walk.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, back view, the wolf faces straight away from the camera, we see the back of the head, both ears from behind, the scarf knot on the back, tail flame rising in front of the body toward the camera, sprite sheet, 6 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, seamless loop where the last frame flows back into the first, walking trot cycle: 1 front-left and hind-right paws step forward, 2 weight shifts onto them and the body dips slightly, 3 legs pass under the body and the body is at its highest, 4 front-right and hind-left paws step forward, 5 weight shifts and the body dips, 6 legs pass under the body; small bouncy chibi steps, head steady, ears and tail flame swaying gently
```

#### 2. Đi · Chéo lên-phải → `wolf_upright_walk.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, three-quarter back view, body turned up and to the right, head turned away from the camera, one ear and part of the cheek visible, tail flame on the lower left, sprite sheet, 6 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, seamless loop where the last frame flows back into the first, walking trot cycle: 1 front-left and hind-right paws step forward, 2 weight shifts onto them and the body dips slightly, 3 legs pass under the body and the body is at its highest, 4 front-right and hind-left paws step forward, 5 weight shifts and the body dips, 6 legs pass under the body; small bouncy chibi steps, head steady, ears and tail flame swaying gently
```

#### 3. Đi · Phải → `wolf_right_walk.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, side view facing right, full profile, only the near eye visible, pendant hanging under the chin, tail flame behind on the left, sprite sheet, 6 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, seamless loop where the last frame flows back into the first, walking trot cycle: 1 front-left and hind-right paws step forward, 2 weight shifts onto them and the body dips slightly, 3 legs pass under the body and the body is at its highest, 4 front-right and hind-left paws step forward, 5 weight shifts and the body dips, 6 legs pass under the body; small bouncy chibi steps, head steady, ears and tail flame swaying gently
```

#### 4. Đi · Xuống → `wolf_down_walk.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, front view facing straight toward the camera, symmetrical, both eyes and the forehead rune clearly visible, pendant centered on the chest, tail flame visible behind the body above the back, sprite sheet, 6 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, seamless loop where the last frame flows back into the first, walking trot cycle: 1 front-left and hind-right paws step forward, 2 weight shifts onto them and the body dips slightly, 3 legs pass under the body and the body is at its highest, 4 front-right and hind-left paws step forward, 5 weight shifts and the body dips, 6 legs pass under the body; small bouncy chibi steps, head steady, ears and tail flame swaying gently
```

#### 5. Đi · Chéo xuống-trái → `wolf_downleft_walk.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, three-quarter front view, body turned down and to the left, same camera angle as the reference image, sprite sheet, 6 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, seamless loop where the last frame flows back into the first, walking trot cycle: 1 front-left and hind-right paws step forward, 2 weight shifts onto them and the body dips slightly, 3 legs pass under the body and the body is at its highest, 4 front-right and hind-left paws step forward, 5 weight shifts and the body dips, 6 legs pass under the body; small bouncy chibi steps, head steady, ears and tail flame swaying gently
```

#### 6. Chạy · Lên → `wolf_up_run.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, back view, the wolf faces straight away from the camera, we see the back of the head, both ears from behind, the scarf knot on the back, tail flame rising in front of the body toward the camera, sprite sheet, 6 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, seamless loop where the last frame flows back into the first, running gallop cycle: 1 gather with legs under the body, 2 hind legs push off, 3 full extension in the air with front legs reaching forward and hind legs stretched back, 4 front paws land, 5 front legs push while hind legs swing forward, 6 hind paws land; ears pinned back, tail flame streaming behind
```

#### 7. Chạy · Chéo lên-phải → `wolf_upright_run.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, three-quarter back view, body turned up and to the right, head turned away from the camera, one ear and part of the cheek visible, tail flame on the lower left, sprite sheet, 6 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, seamless loop where the last frame flows back into the first, running gallop cycle: 1 gather with legs under the body, 2 hind legs push off, 3 full extension in the air with front legs reaching forward and hind legs stretched back, 4 front paws land, 5 front legs push while hind legs swing forward, 6 hind paws land; ears pinned back, tail flame streaming behind
```

#### 8. Chạy · Phải → `wolf_right_run.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, side view facing right, full profile, only the near eye visible, pendant hanging under the chin, tail flame behind on the left, sprite sheet, 6 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, seamless loop where the last frame flows back into the first, running gallop cycle: 1 gather with legs under the body, 2 hind legs push off, 3 full extension in the air with front legs reaching forward and hind legs stretched back, 4 front paws land, 5 front legs push while hind legs swing forward, 6 hind paws land; ears pinned back, tail flame streaming behind
```

#### 9. Chạy · Xuống → `wolf_down_run.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, front view facing straight toward the camera, symmetrical, both eyes and the forehead rune clearly visible, pendant centered on the chest, tail flame visible behind the body above the back, sprite sheet, 6 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, seamless loop where the last frame flows back into the first, running gallop cycle: 1 gather with legs under the body, 2 hind legs push off, 3 full extension in the air with front legs reaching forward and hind legs stretched back, 4 front paws land, 5 front legs push while hind legs swing forward, 6 hind paws land; ears pinned back, tail flame streaming behind
```

#### 10. Chạy · Chéo xuống-trái → `wolf_downleft_run.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, three-quarter front view, body turned down and to the left, same camera angle as the reference image, sprite sheet, 6 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, seamless loop where the last frame flows back into the first, running gallop cycle: 1 gather with legs under the body, 2 hind legs push off, 3 full extension in the air with front legs reaching forward and hind legs stretched back, 4 front paws land, 5 front legs push while hind legs swing forward, 6 hind paws land; ears pinned back, tail flame streaming behind
```

#### Prompt phủ định (dùng chung, nếu công cụ có ô "negative prompt")

```
realistic, 3d render, painterly, blurry, anti-aliased edges, gradient background, ground shadow, cropped, extra limbs, extra tails, different character, different colors, text, watermark, frame, border, frames of different sizes, character changing size between frames
```


**Cách dùng:**

1. Làm **Đi** trước (prompt 1–5), vì sói đi gần như suốt trận.
2. Mỗi lần tạo đính kèm `wolf_concept.webp`. Từ hướng thứ hai trở đi, đính kèm thêm ảnh Đi của hướng
   đã ưng ý để giữ đồng nhất.
3. Giữ cố định: cùng công cụ, cùng seed (nếu công cụ cho đặt), cùng tỉ lệ khung hình, nền trắng trơn.
4. Không vẽ bóng dưới chân. Game tự vẽ bóng, để chung thì bóng bị lặp.
5. Gửi lại ảnh đúng tên file trong bảng.

### Bộ prompt giai đoạn 2: Cào + Gồng + Nghỉ + Chết (chép một lần là dùng được)

Sinh từ `tools/art/wolf_prompts.py --phase 2`. Bốn hành động này chạy một lần, không lặp, nên dòng
sprite sheet thay "seamless loop" bằng "plays once from left to right and does not loop". Danh sách việc
còn lại (kể cả Sửa Cào và VFX) ở `PROMPTS_TODO.md` (`wolf_prompts.py --todo`).

**20 prompt**. Mỗi khối dưới đây đã ghép đủ, chép nguyên khối dán vào công cụ tạo ảnh và đính kèm ảnh ghi ở cột "Đính kèm".

| # | Tên file gửi lại | Việc | Hướng | Khung | Đính kèm |
|---|---|---|---|---|---|
| 1 | `wolf_up_claw.png` | Cào | Lên | 4 | `wolf_concept.webp` + dải Đi cùng hướng |
| 2 | `wolf_upright_claw.png` | Cào | Chéo lên-phải | 4 | `wolf_concept.webp` + dải Đi cùng hướng |
| 3 | `wolf_right_claw.png` | Cào | Phải | 4 | `wolf_concept.webp` + dải Đi cùng hướng |
| 4 | `wolf_down_claw.png` | Cào | Xuống | 4 | `wolf_concept.webp` + dải Đi chéo xuống-trái |
| 5 | `wolf_downleft_claw.png` | Cào | Chéo xuống-trái | 4 | `wolf_concept.webp` + dải Đi cùng hướng |
| 6 | `wolf_up_windup.png` | Gồng | Lên | 3 | `wolf_concept.webp` + dải Đi cùng hướng |
| 7 | `wolf_upright_windup.png` | Gồng | Chéo lên-phải | 3 | `wolf_concept.webp` + dải Đi cùng hướng |
| 8 | `wolf_right_windup.png` | Gồng | Phải | 3 | `wolf_concept.webp` + dải Đi cùng hướng |
| 9 | `wolf_down_windup.png` | Gồng | Xuống | 3 | `wolf_concept.webp` + dải Đi chéo xuống-trái |
| 10 | `wolf_downleft_windup.png` | Gồng | Chéo xuống-trái | 3 | `wolf_concept.webp` + dải Đi cùng hướng |
| 11 | `wolf_up_recover.png` | Nghỉ | Lên | 4 | `wolf_concept.webp` + dải Đi cùng hướng |
| 12 | `wolf_upright_recover.png` | Nghỉ | Chéo lên-phải | 4 | `wolf_concept.webp` + dải Đi cùng hướng |
| 13 | `wolf_right_recover.png` | Nghỉ | Phải | 4 | `wolf_concept.webp` + dải Đi cùng hướng |
| 14 | `wolf_down_recover.png` | Nghỉ | Xuống | 4 | `wolf_concept.webp` + dải Đi chéo xuống-trái |
| 15 | `wolf_downleft_recover.png` | Nghỉ | Chéo xuống-trái | 4 | `wolf_concept.webp` + dải Đi cùng hướng |
| 16 | `wolf_up_death.png` | Chết | Lên | 3 | `wolf_concept.webp` + dải Đi cùng hướng |
| 17 | `wolf_upright_death.png` | Chết | Chéo lên-phải | 3 | `wolf_concept.webp` + dải Đi cùng hướng |
| 18 | `wolf_right_death.png` | Chết | Phải | 3 | `wolf_concept.webp` + dải Đi cùng hướng |
| 19 | `wolf_down_death.png` | Chết | Xuống | 3 | `wolf_concept.webp` + dải Đi chéo xuống-trái |
| 20 | `wolf_downleft_death.png` | Chết | Chéo xuống-trái | 3 | `wolf_concept.webp` + dải Đi cùng hướng |

#### 1. Cào · Lên → `wolf_up_claw.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, back view, the wolf faces straight away from the camera, we see the back of the head, both ears from behind, the scarf knot on the back, tail flame rising in front of the body toward the camera, sprite sheet, 4 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, plays once from left to right and does not loop, claw swipe attack at close range, character only with no slash effect: 1 rears up slightly and raises one front paw with claws out, runes glowing, 2 paw pulled back high above the head, ready to strike, 3 paw fully swung down and across the front of the body, claws extended, body leaning into the swipe, 4 paw back on the ground in the neutral pose; body stays in place, no claw streaks or trails in the air (the slash effect is a separate sprite)
```

#### 2. Cào · Chéo lên-phải → `wolf_upright_claw.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, three-quarter back view, body turned up and to the right, head turned away from the camera, one ear and part of the cheek visible, tail flame on the lower left, sprite sheet, 4 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, plays once from left to right and does not loop, claw swipe attack at close range, character only with no slash effect: 1 rears up slightly and raises one front paw with claws out, runes glowing, 2 paw pulled back high above the head, ready to strike, 3 paw fully swung down and across the front of the body, claws extended, body leaning into the swipe, 4 paw back on the ground in the neutral pose; body stays in place, no claw streaks or trails in the air (the slash effect is a separate sprite)
```

#### 3. Cào · Phải → `wolf_right_claw.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, side view facing right, full profile, only the near eye visible, pendant hanging under the chin, tail flame behind on the left, sprite sheet, 4 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, plays once from left to right and does not loop, claw swipe attack at close range, character only with no slash effect: 1 rears up slightly and raises one front paw with claws out, runes glowing, 2 paw pulled back high above the head, ready to strike, 3 paw fully swung down and across the front of the body, claws extended, body leaning into the swipe, 4 paw back on the ground in the neutral pose; body stays in place, no claw streaks or trails in the air (the slash effect is a separate sprite)
```

#### 4. Cào · Xuống → `wolf_down_claw.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, front view facing straight toward the camera, symmetrical, both eyes and the forehead rune clearly visible, pendant centered on the chest, tail flame visible behind the body above the back, sprite sheet, 4 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, plays once from left to right and does not loop, claw swipe attack at close range, character only with no slash effect: 1 rears up slightly and raises one front paw with claws out, runes glowing, 2 paw pulled back high above the head, ready to strike, 3 paw fully swung down and across the front of the body, claws extended, body leaning into the swipe, 4 paw back on the ground in the neutral pose; body stays in place, no claw streaks or trails in the air (the slash effect is a separate sprite)
```

#### 5. Cào · Chéo xuống-trái → `wolf_downleft_claw.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, three-quarter front view, body turned down and to the left, same camera angle as the reference image, sprite sheet, 4 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, plays once from left to right and does not loop, claw swipe attack at close range, character only with no slash effect: 1 rears up slightly and raises one front paw with claws out, runes glowing, 2 paw pulled back high above the head, ready to strike, 3 paw fully swung down and across the front of the body, claws extended, body leaning into the swipe, 4 paw back on the ground in the neutral pose; body stays in place, no claw streaks or trails in the air (the slash effect is a separate sprite)
```

#### 6. Gồng · Lên → `wolf_up_windup.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, back view, the wolf faces straight away from the camera, we see the back of the head, both ears from behind, the scarf knot on the back, tail flame rising in front of the body toward the camera, sprite sheet, 3 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, plays once from left to right and does not loop, charging up before a dash, a clear warning pose: 1 stops and lowers the front of the body, ears turning back, 2 crouches deeper with weight on the hind legs, purple runes glowing brighter, 3 fully crouched and ready to spring, ears flat, eyes glowing intensely, tail flame flaring twice as large; the last frame is held until the dash starts
```

#### 7. Gồng · Chéo lên-phải → `wolf_upright_windup.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, three-quarter back view, body turned up and to the right, head turned away from the camera, one ear and part of the cheek visible, tail flame on the lower left, sprite sheet, 3 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, plays once from left to right and does not loop, charging up before a dash, a clear warning pose: 1 stops and lowers the front of the body, ears turning back, 2 crouches deeper with weight on the hind legs, purple runes glowing brighter, 3 fully crouched and ready to spring, ears flat, eyes glowing intensely, tail flame flaring twice as large; the last frame is held until the dash starts
```

#### 8. Gồng · Phải → `wolf_right_windup.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, side view facing right, full profile, only the near eye visible, pendant hanging under the chin, tail flame behind on the left, sprite sheet, 3 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, plays once from left to right and does not loop, charging up before a dash, a clear warning pose: 1 stops and lowers the front of the body, ears turning back, 2 crouches deeper with weight on the hind legs, purple runes glowing brighter, 3 fully crouched and ready to spring, ears flat, eyes glowing intensely, tail flame flaring twice as large; the last frame is held until the dash starts
```

#### 9. Gồng · Xuống → `wolf_down_windup.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, front view facing straight toward the camera, symmetrical, both eyes and the forehead rune clearly visible, pendant centered on the chest, tail flame visible behind the body above the back, sprite sheet, 3 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, plays once from left to right and does not loop, charging up before a dash, a clear warning pose: 1 stops and lowers the front of the body, ears turning back, 2 crouches deeper with weight on the hind legs, purple runes glowing brighter, 3 fully crouched and ready to spring, ears flat, eyes glowing intensely, tail flame flaring twice as large; the last frame is held until the dash starts
```

#### 10. Gồng · Chéo xuống-trái → `wolf_downleft_windup.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, three-quarter front view, body turned down and to the left, same camera angle as the reference image, sprite sheet, 3 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, plays once from left to right and does not loop, charging up before a dash, a clear warning pose: 1 stops and lowers the front of the body, ears turning back, 2 crouches deeper with weight on the hind legs, purple runes glowing brighter, 3 fully crouched and ready to spring, ears flat, eyes glowing intensely, tail flame flaring twice as large; the last frame is held until the dash starts
```

#### 11. Nghỉ · Lên → `wolf_up_recover.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, back view, the wolf faces straight away from the camera, we see the back of the head, both ears from behind, the scarf knot on the back, tail flame rising in front of the body toward the camera, sprite sheet, 4 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, plays once from left to right and does not loop, recovering after a dash: 1 skidding to a stop with front paws braced forward and the body leaning back, 2 small stumble with the head dipping, 3 catching breath with tongue out and runes dimmed, 4 back to the neutral standing pose of the reference image; tail flame smaller and dimmer than usual
```

#### 12. Nghỉ · Chéo lên-phải → `wolf_upright_recover.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, three-quarter back view, body turned up and to the right, head turned away from the camera, one ear and part of the cheek visible, tail flame on the lower left, sprite sheet, 4 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, plays once from left to right and does not loop, recovering after a dash: 1 skidding to a stop with front paws braced forward and the body leaning back, 2 small stumble with the head dipping, 3 catching breath with tongue out and runes dimmed, 4 back to the neutral standing pose of the reference image; tail flame smaller and dimmer than usual
```

#### 13. Nghỉ · Phải → `wolf_right_recover.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, side view facing right, full profile, only the near eye visible, pendant hanging under the chin, tail flame behind on the left, sprite sheet, 4 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, plays once from left to right and does not loop, recovering after a dash: 1 skidding to a stop with front paws braced forward and the body leaning back, 2 small stumble with the head dipping, 3 catching breath with tongue out and runes dimmed, 4 back to the neutral standing pose of the reference image; tail flame smaller and dimmer than usual
```

#### 14. Nghỉ · Xuống → `wolf_down_recover.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, front view facing straight toward the camera, symmetrical, both eyes and the forehead rune clearly visible, pendant centered on the chest, tail flame visible behind the body above the back, sprite sheet, 4 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, plays once from left to right and does not loop, recovering after a dash: 1 skidding to a stop with front paws braced forward and the body leaning back, 2 small stumble with the head dipping, 3 catching breath with tongue out and runes dimmed, 4 back to the neutral standing pose of the reference image; tail flame smaller and dimmer than usual
```

#### 15. Nghỉ · Chéo xuống-trái → `wolf_downleft_recover.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, three-quarter front view, body turned down and to the left, same camera angle as the reference image, sprite sheet, 4 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, plays once from left to right and does not loop, recovering after a dash: 1 skidding to a stop with front paws braced forward and the body leaning back, 2 small stumble with the head dipping, 3 catching breath with tongue out and runes dimmed, 4 back to the neutral standing pose of the reference image; tail flame smaller and dimmer than usual
```

#### 16. Chết · Lên → `wolf_up_death.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, back view, the wolf faces straight away from the camera, we see the back of the head, both ears from behind, the scarf knot on the back, tail flame rising in front of the body toward the camera, sprite sheet, 3 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, plays once from left to right and does not loop, defeat animation, character only: 1 staggers with eyes squeezed shut and ears flat, 2 collapses onto its side, 3 lies still on the ground with eyes closed, tail flame small and dim; the body stays fully opaque in every frame (the game fades it out and plays a separate dissolve effect)
```

#### 17. Chết · Chéo lên-phải → `wolf_upright_death.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, three-quarter back view, body turned up and to the right, head turned away from the camera, one ear and part of the cheek visible, tail flame on the lower left, sprite sheet, 3 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, plays once from left to right and does not loop, defeat animation, character only: 1 staggers with eyes squeezed shut and ears flat, 2 collapses onto its side, 3 lies still on the ground with eyes closed, tail flame small and dim; the body stays fully opaque in every frame (the game fades it out and plays a separate dissolve effect)
```

#### 18. Chết · Phải → `wolf_right_death.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, side view facing right, full profile, only the near eye visible, pendant hanging under the chin, tail flame behind on the left, sprite sheet, 3 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, plays once from left to right and does not loop, defeat animation, character only: 1 staggers with eyes squeezed shut and ears flat, 2 collapses onto its side, 3 lies still on the ground with eyes closed, tail flame small and dim; the body stays fully opaque in every frame (the game fades it out and plays a separate dissolve effect)
```

#### 19. Chết · Xuống → `wolf_down_death.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, front view facing straight toward the camera, symmetrical, both eyes and the forehead rune clearly visible, pendant centered on the chest, tail flame visible behind the body above the back, sprite sheet, 3 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, plays once from left to right and does not loop, defeat animation, character only: 1 staggers with eyes squeezed shut and ears flat, 2 collapses onto its side, 3 lies still on the ground with eyes closed, tail flame small and dim; the body stays fully opaque in every frame (the game fades it out and plays a separate dissolve effect)
```

#### 20. Chết · Chéo xuống-trái → `wolf_downleft_death.png`

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf, large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim, large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small floating flames, lavender-blue outline (no black outline), same palette, same proportions (head about 40% of body height), plain white background, no ground shadow, full body, centered, no text, three-quarter front view, body turned down and to the left, same camera angle as the reference image, sprite sheet, 3 frames in one horizontal row, evenly spaced, every frame the same size and the same character scale, feet on the same ground line in every frame, plays once from left to right and does not loop, defeat animation, character only: 1 staggers with eyes squeezed shut and ears flat, 2 collapses onto its side, 3 lies still on the ground with eyes closed, tail flame small and dim; the body stays fully opaque in every frame (the game fades it out and plays a separate dissolve effect)
```

#### Prompt phủ định cho dải nhân vật (nếu công cụ có ô "negative prompt")

```
realistic, 3d render, painterly, blurry, anti-aliased edges, gradient background, ground shadow, cropped, extra limbs, extra tails, different character, different colors, text, watermark, frame, border, frames of different sizes, character changing size between frames, slash trails, claw streaks, motion lines, speed lines, impact effects, sparks away from the body
```

#### Prompt phủ định cho VFX

```
character, animal, wolf, body, face, paws, realistic, 3d render, blurry, gradient background, white background, text, watermark, frame, border, frames of different sizes
```


**Cách dùng:**

1. Làm **Cào** trước (prompt 1–5): mọi con sói đều cào, nên đây là đòn người chơi thấy nhiều nhất.
   Rồi tới **Gồng** (prompt 6–10): tín hiệu để người chơi né cú lao.
2. Đính kèm `wolf_concept.webp` **và** dải Đi cùng hướng đã có, để giữ đúng góc nhìn và cỡ.
3. Khung cuối của Gồng là tư thế được giữ cho tới khi lao; khung cuối của Nghỉ phải về tư thế đứng.
4. Chết: khung 5 chỉ còn vài đốm lửa, nhưng vẫn phải còn ít nhất vài điểm ảnh để công cụ tách khung.
5. Gửi lại ảnh đúng tên file trong bảng.

### Để sau: các mảnh prompt rời

Dùng khi làm các hành động khác ở giai đoạn sau.

### Phần chung (ghép vào đầu mọi prompt)

```
pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf,
large purple eyes with a white highlight, glowing purple swirl runes on forehead, cheeks and body,
jade bi-disc pendant on a navy cord with gold beads and a blue tassel, navy scarf with gold trim,
large pointed ears with purple inner ear, fluffy tail turning into blue spirit flame with small
floating flames, lavender-blue outline (no black outline), same palette, same proportions
(head about 40% of body height), plain white background, no ground shadow, full body, centered,
no text
```

### Prompt phủ định (nếu công cụ có ô "negative prompt")

```
realistic, 3d render, painterly, blurry, anti-aliased edges, gradient background, ground shadow,
cropped, extra limbs, extra tails, different character, different colors, text, watermark, frame, border
```

### A. Ảnh tĩnh từng hướng (để sau, hiện dùng ảnh concept)

Mỗi prompt = phần chung + dòng dưới đây.

| Tên file gửi lại | Hướng | Prompt riêng |
|---|---|---|
| `wolf_up_idle.png` | Lên | `back view, the wolf faces straight away from the camera, we see the back of the head, both ears from behind, the scarf knot on the back, tail flame rising in front of the body toward the camera, standing pose` |
| `wolf_upright_idle.png` | Chéo lên-phải | `three-quarter back view, body turned up and to the right, head turned away from the camera, one ear and part of the cheek visible, tail flame on the lower left, standing pose` |
| `wolf_right_idle.png` | Phải | `side view facing right, full profile, both eyes not visible (only the near eye), pendant hanging under the chin, tail flame behind on the left, standing pose` |
| `wolf_down_idle.png` | Xuống | `front view facing straight toward the camera, symmetrical, both eyes and the forehead rune clearly visible, pendant centered on the chest, tail flame visible behind the body above the back, standing pose` |

Hướng chéo xuống-trái đã có (ảnh mẫu). Ba hướng phía trái còn lại lật ngang, không cần tạo.

### B. Animation các hành động khác

Mỗi prompt = phần chung + dòng hướng (cột "Prompt riêng" ở mục A, bỏ phần `standing pose`) + dòng
hành động dưới đây. Mọi animation đều thêm:

```
sprite sheet, N frames in one horizontal row, evenly spaced, every frame the same size and the same
character scale, feet on the same ground line in every frame
```

(thay `N` bằng số khung của hành động)

| Tên file gửi lại | Hành động | N | Prompt hành động |
|---|---|---|---|
| `wolf_<hướng>_run.png` | Chạy (lặp) | 6 | `running gallop cycle: 1 gather with legs under the body, 2 hind legs push off, 3 full extension in the air with front legs reaching forward and hind legs stretched back, 4 front paws land, 5 front legs push while hind legs swing forward, 6 hind paws land; ears back, tail flame streaming behind` |
| `wolf_<hướng>_bite.png` | Cắn (lặp) | 4 | `biting attack loop: 1 head pulled back, 2 lunge forward with mouth open showing small fangs, 3 jaws snap shut, 4 recover to neutral; body stays in place` |
| `wolf_<hướng>_windup.png` | Gồng (báo trước cú lao) | 3 | `charging up before a dash: 1 lowers the body, 2 crouches deeper with ears flat and runes glowing brighter, 3 fully crouched and ready to spring, eyes glowing intensely, tail flame flaring larger; this pose must read clearly as a warning` |
| `wolf_<hướng>_dash.png` | Lao (lặp) | 3 | `high-speed dash: body stretched long and low, legs tucked, ears pinned back, tail flame trailing far behind as a streak; 3 frames with small variations of the stretch` |
| `wolf_<hướng>_recover.png` | Nghỉ sau lao | 4 | `recovering after a dash: 1 skidding to a stop with front paws braced, 2 stumbling slightly, 3 panting with tongue out, 4 back to a neutral stance; tail flame smaller and dimmer` |
| `wolf_<hướng>_hurt.png` | Trúng đòn | 1 | `hit reaction: flinching backward, eyes squeezed shut, ears flat, body recoiling away from the hit` |
| `wolf_<hướng>_death.png` | Chết | 5 | `defeat animation: 1 staggers, 2 collapses onto its side, 3 lies down as the body starts to fade, 4 dissolves into blue spirit flame particles and purple rune sparks, 5 only a few fading sparks remain` |

`<hướng>` là một trong: `up`, `upright`, `right`, `down`, `downleft`.

Ví dụ một prompt hoàn chỉnh (Chạy, hướng phải) = phần chung + `side view facing right, full profile,
both eyes not visible (only the near eye), pendant hanging under the chin, tail flame behind on the left`
+ dòng sprite sheet với N = 6 + prompt hành động của Chạy.

### C. Sói tinh anh (Huyết Lang Vương)

Dùng lại toàn bộ ảnh của sói thường. Chỉ cần một ảnh mẫu để chốt màu, game sẽ tự đổi màu theo bảng này:

```
same character and pose as the reference image, elite variant: crimson-violet spirit flame instead of
blue, glowing red-violet runes, deep violet outline, a small golden crown-shaped flame above the head,
fiercer narrowed eyes, everything else identical
```

### D. Bản "yêu hoá" cho quái (tuỳ chọn)

Nếu muốn giữ mẫu dễ thương cho linh thú đồng hành và làm quái trông dữ hơn:

```
same character and pose as the reference image, corrupted demon version: red glowing eyes with slit
pupils, bared fangs, ragged fur, darker grey-violet fur, runes glowing red, tail flame dark purple
with black smoke, no pendant, torn scarf
```

## Xử lý sau khi có ảnh

Dải animation: `tools/art/sheet_frames.py <thư_mục> hướng=ảnh ... --action <mã> --frames <N> --scale 0.531`
(xoá nền, tách khung, căn chân, thu về ô 256 và cỡ 64; `--scale` giữ mọi hành động cùng một cỡ).
Đưa vào game: `python3 tools/art/wolf_atlas.py` gom mọi dải đã có thành `sprites/wolf_atlas.png`
(hàng = 5 hướng vẽ, cột = khung của Đi, Chạy, Gồng, Cào, Nghỉ nối nhau; ô 128 px). Dải còn thiếu được
thay tạm và liệt kê trong `sprites/wolf_atlas.json`. Có ảnh mới thì chạy lại lệnh này, game tự dùng.
Ảnh đơn: `tools/art/reference_scale.py` để khôi phục lưới pixel, xoá nền và thu về cỡ dùng trong game. Chưa làm: khoá các khung về bảng màu của mẫu.
