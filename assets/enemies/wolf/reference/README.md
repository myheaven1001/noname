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

4 hướng: phải, trái (= phải lật ngang), đi xuống (mặt về camera), đi lên (quay lưng).
Chỉ cần vẽ 3 hướng. Mẫu hiện tại là góc 3/4 quay sang trái, gần với "trái / đi xuống".

| Hành động | Khung / hướng | 3 hướng vẽ |
|---|---|---|
| Chạy | 6 | 18 |
| Cắn | 4 | 12 |
| Gồng (báo trước cú lao) | 3 | 9 |
| Lao | 3 | 9 |
| Nghỉ sau lao | 4 | 12 |
| Trúng đòn | 1 | 3 |
| Chết | 5 | 15 |
| **Tổng** | **26** | **78** |

## Prompt cho công cụ tạo ảnh (luôn đính kèm `wolf_concept.webp` làm ảnh tham chiếu)

Phần chung, ghép vào đầu mỗi prompt:

> pixel art game sprite, same character as the reference image: chibi white-lavender spirit wolf,
> large purple eyes, glowing purple swirl runes on forehead, cheeks and body, jade bi-disc pendant on a
> navy cord with gold beads and a blue tassel, navy scarf with gold trim, fluffy tail turning into
> blue spirit flame with small floating flames, lavender-blue outline, same palette, same proportions,
> plain white background, full body, centered, no text

Theo hướng:

- **Phải (nhìn ngang):** `side view facing right, standing`
- **Đi xuống:** `front view facing the camera, symmetrical, tail flame visible behind the body`
- **Đi lên:** `back view facing away from the camera, back of the head and ears, tail flame in front`

Theo hành động (thêm sau hướng), ví dụ Chạy:
`running animation, 6 frames in one horizontal row, evenly spaced, gallop cycle: gather, hind push,
full extension, front paws land, front push, hind paws land`

## Xử lý sau khi có ảnh

Chạy lại `tools/art/reference_scale.py` cho từng ảnh mới để khôi phục lưới pixel, xoá nền và thu về
cỡ dùng trong game. Bước tiếp theo, chưa làm: khoá các khung về bảng màu của mẫu, xếp vào sprite sheet
(mỗi hàng một hành động, mỗi hướng một sheet) và nối vào renderer qua ô `custom.y`.
