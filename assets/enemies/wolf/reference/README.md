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

| Hành động | Khung / hướng | 5 hướng vẽ |
|---|---|---|
| Chạy | 6 | 30 |
| Cắn | 4 | 20 |
| Gồng (báo trước cú lao) | 3 | 15 |
| Lao | 3 | 15 |
| Nghỉ sau lao | 4 | 20 |
| Trúng đòn | 1 | 5 |
| Chết | 5 | 25 |
| **Tổng** | **26** | **130** |

Trong game: chọn hướng theo góc vận tốc chia 8 cung 45°; lúc gồng/lao dùng hướng đã khoá (`dir`).

## Prompt cho công cụ tạo ảnh

Luôn đính kèm `wolf_concept.webp` làm ảnh tham chiếu nhân vật. Prompt viết bằng tiếng Anh vì đa số
công cụ tạo ảnh hiểu tiếng Anh tốt nhất.

### Quy trình để các ảnh đồng nhất

1. **Ảnh tĩnh từng hướng trước:** tạo 4 hướng còn thiếu (mục A), gửi lại để ghép vào sơ đồ 8 hướng và duyệt.
2. **Animation sau:** mỗi hành động, mỗi hướng một lần tạo (mục B). Đính kèm **cả** `wolf_concept.webp`
   **và** ảnh tĩnh đã duyệt của đúng hướng đó.
3. Giữ cố định: cùng công cụ, cùng seed (nếu công cụ cho đặt), cùng tỉ lệ khung hình, nền trắng trơn.
4. Không vẽ bóng dưới chân. Game tự vẽ bóng, để chung thì bóng bị lặp.

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

### A. Ảnh tĩnh từng hướng (4 ảnh cần tạo)

Mỗi prompt = phần chung + dòng dưới đây.

| Tên file gửi lại | Hướng | Prompt riêng |
|---|---|---|
| `wolf_up_idle.png` | Lên | `back view, the wolf faces straight away from the camera, we see the back of the head, both ears from behind, the scarf knot on the back, tail flame rising in front of the body toward the camera, standing pose` |
| `wolf_upright_idle.png` | Chéo lên-phải | `three-quarter back view, body turned up and to the right, head turned away from the camera, one ear and part of the cheek visible, tail flame on the lower left, standing pose` |
| `wolf_right_idle.png` | Phải | `side view facing right, full profile, both eyes not visible (only the near eye), pendant hanging under the chin, tail flame behind on the left, standing pose` |
| `wolf_down_idle.png` | Xuống | `front view facing straight toward the camera, symmetrical, both eyes and the forehead rune clearly visible, pendant centered on the chest, tail flame visible behind the body above the back, standing pose` |

Hướng chéo xuống-trái đã có (ảnh mẫu). Ba hướng phía trái còn lại lật ngang, không cần tạo.

### B. Animation từng hành động

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

Chạy lại `tools/art/reference_scale.py` cho từng ảnh mới để khôi phục lưới pixel, xoá nền và thu về
cỡ dùng trong game. Bước tiếp theo, chưa làm: khoá các khung về bảng màu của mẫu, xếp vào sprite sheet
(mỗi hàng một hành động, mỗi hướng một sheet) và nối vào renderer qua ô `custom.y`.
