# Tiên Lộ — prototype hệ thống quái

Prototype Godot 4.4 (GDScript, renderer Compatibility để export được web, iOS, Android) cho game
survivors co-op phong cách tiên hiệp. Mục tiêu của bản này là kiểm chứng phần lõi: hàng trăm đến
hàng nghìn quái ở 120fps, logic tách khỏi hình ảnh để sau này chạy trên server headless.

Hình ảnh hiện là hình tròn tạm; art thật chỉ thay texture/sprite sheet, không đổi logic.

## Chạy

```bash
# Mở trong editor Godot 4.4+ rồi F5, hoặc:
godot --path .

# Đo hiệu năng mô phỏng + kiểm tra bất biến (không cần GPU):
godot --headless --path . --import
godot --headless --path . -s res://tools/bench.gd

# Chụp màn hình cảnh test trên máy không có màn hình (Linux):
SHOT=shot.png FRAMES=900 xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/screenshot.gd
```

`data/enemies.csv.import` đặt importer là `keep`: mặc định Godot coi `.csv` là bảng dịch và
**không** đóng gói file gốc khi export (web/mobile sẽ không đọc được bảng quái). Mọi file CSV dữ liệu
mới cũng cần một file `.import` như vậy.

## Hiệu năng đo được

Godot 4.4.1, GDScript, CPU container 4 nhân (không GPU), người chơi chạy vòng tròn, 20 giây đo:

| Người chơi | Quái | Tick TB | Tick p99 | Ghi buffer MultiMesh / frame |
|---|---|---|---|---|
| 1 | 500 | 4,1 ms | 8,4 ms | 0,22 ms |
| 1 | 1000 | 7,7 ms | 14,2 ms | 0,44 ms |
| 1 | 2000 | 13,5 ms | 21,3 ms | 0,85 ms |
| 4 | 500 | 5,3 ms | 10,7 ms | 0,24 ms |
| 4 | 2000 | 16,5 ms | 26,2 ms | 0,90 ms |

Cảnh test có hình (renderer phần mềm, không GPU): 126 FPS với 500 quái khi tắt vsync.

Chi phí lớn nhất là bước tách quái khỏi nhau (`_move_enemies`), sau đó là hành vi (`_update_enemies`).
Đã áp dụng: ô lưới 48px, tính lực tách mỗi 2 tick, giới hạn 24 hàng xóm phải xét (thứ tự quét xoay
vòng để không lệch hướng), viết thẳng hàm đuổi vào vòng lặp.

Ở 120fps một frame chỉ có 8,33 ms và tick 30Hz rơi vào một frame, nên với GDScript thuần:
~500 quái là mức an toàn cho mobile, ~1000 cho web/PC. Muốn 2000 quái trở lên cần chuyển
`_move_enemies` + `_update_enemies` sang GDExtension (C++, chạy được cả web), hoặc chạy mô phỏng
trên luồng riêng ở bản native.

Phím trong cảnh test:

| Phím | Tác dụng |
|---|---|
| WASD / mũi tên | Di chuyển (tự bắn kiếm khí vào quái gần nhất) |
| `+` / `-` | Thêm/bớt 100 quái |
| `1` / `2` / `3` | 500 / 1000 / 2000 quái |
| `F` | Đóng băng quái quanh người chơi 1,5 giây (test huỷ đòn đang gồng) |
| `F1` | Hiện flow field |
| `F2` | Hiện trạng thái quái quanh người chơi (ĐUỔI / GỒNG / LAO / NGHỈ) |
| `F3` | Bật/tắt AI |
| `V` | Bật/tắt vsync (tắt để xem FPS tối đa) |

## Cấu trúc

```
data/enemies.csv                 Bảng quái: máu, tốc độ, bán kính, thông số lao... (không viết cứng trong code)
scripts/sim/                     Mô phỏng phía server — không dùng Node, chạy headless được
  enemy_db.gd                    Đọc CSV → mảng cấu hình theo type id
  enemy_store.gd                 Dữ liệu quái dạng SoA, mảng đặc, xoá bằng swap-remove, uid ổn định cho mạng
  spatial_hash.gd                Lưới đều + counting sort, dựng lại mỗi tick O(n), không cấp phát
  flow_field.gd                  BFS nhiều nguồn từ người chơi, hướng từng ô tính lười
  world.gd                       Thứ tự tick, người chơi, đạn, sát thương, spawn/despawn, sự kiện mạng
  behaviors/wolf.gd              Sói yêu: Đuổi → Gồng (khoá hướng) → Lao → Nghỉ
scripts/render/
  enemy_renderer.gd              MultiMeshInstance2D, 1 draw call, nội suy 30Hz → tần số màn hình
  fx_layer.gd                    Vạch cảnh báo, đạn, người chơi, debug (vẽ tạm bằng _draw)
scripts/game/main.gd             Cảnh test + HUD hiệu năng
tools/bench.gd                   Benchmark headless + kiểm tra bất biến
tools/screenshot.gd              Chạy cảnh test và lưu ảnh (dùng với xvfb-run)
```

## Thứ tự một tick (30Hz)

1. Lưu vị trí cũ (để nội suy khi vẽ)
2. Spawn bù quân số ngoài tầm nhìn; máu tăng theo số người chơi và thời gian
3. Flow field (mỗi 9 tick ≈ 0,3 giây)
4. Dựng lại spatial hash
5. Người chơi: di chuyển, tự bắn
6. Quái: đếm giờ, choáng (huỷ đòn đang gồng/lao), hành vi theo loại
7. Di chuyển quái: vận tốc + đẩy lùi + tách nhau (mỗi 2 tick, xét tối đa 24 hàng xóm) + đẩy khỏi đá
8. Va chạm quái → người chơi (cú lao chỉ trúng mỗi người 1 lần)
9. Đạn: kiểm tra theo cả đoạn đường bay, xuyên 1 mục tiêu
10. Xoá quái chết / quá xa (duyệt ngược, swap-remove)

`World.events` sau mỗi tick là danh sách sự kiện server sẽ gửi cho client: `spawn`, `windup`,
`dash`, `attack_cancel`, `death`, `player_hit`.

## Tình huống biên đã xử lý

- Mục tiêu chạy đi trong lúc gồng → sói vẫn lao theo hướng đã khoá.
- Bị đóng băng/choáng khi đang gồng hoặc lao → huỷ đòn, phát `attack_cancel`, hồi chiêu ≥ 1 giây.
- Đang lao → siêu giáp (không bị đẩy lùi).
- Lao vào đá hoặc biên đấu trường → dừng lao, chuyển sang nghỉ.
- Mỗi cú lao gây sát thương 1 lần cho mỗi người chơi (`hit_mask`).
- Tối đa 6 quái gồng/lao cùng lúc (`MAX_ATTACKERS`).
- Quái cách mọi người chơi > 1500px bị xoá và spawn bù gần người chơi.
- Quái đã chạm người chơi thì đứng lại vây quanh, không cố lao vào tâm.
- Đạn nhanh không bay xuyên quái (kiểm tra theo đoạn thẳng).

## Thêm một loại quái

1. Thêm dòng vào `data/enemies.csv`. Nếu chỉ đuổi theo (`behavior = chase`) thì xong.
2. Nếu có đòn riêng: tạo `scripts/sim/behaviors/<ten>.gd` với `static func tick(w: World, i: int)`,
   dùng các trạng thái chung trong `EnemyStore` (`S_CHASE`, `S_WINDUP`, `S_DASH`, `S_RECOVER`),
   thêm hằng số hành vi trong `EnemyDB.BEHAVIORS` và một nhánh `match` trong `World._update_enemies`.
3. Quái tinh anh chỉ là một dòng CSV khác (xem `wolf_elite`).

## Chưa có (bước tiếp theo)

- Mạng: server headless gửi `events` + hiệu chỉnh vị trí qua WebSocket; client chạy cùng code di chuyển.
- Rơi linh khí / linh thạch / tiên linh thạch khi quái chết (hook sẵn ở sự kiện `death`).
- Điều khiển cảm ứng (joystick ảo), sprite sheet và animation thật.
