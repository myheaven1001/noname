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
```

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
```

## Thứ tự một tick (30Hz)

1. Lưu vị trí cũ (để nội suy khi vẽ)
2. Spawn bù quân số ngoài tầm nhìn; máu tăng theo số người chơi và thời gian
3. Flow field (mỗi 9 tick ≈ 0,3 giây)
4. Dựng lại spatial hash
5. Người chơi: di chuyển, tự bắn
6. Quái: đếm giờ, choáng (huỷ đòn đang gồng/lao), hành vi theo loại
7. Di chuyển quái: vận tốc + đẩy lùi + tách nhau (tối đa 10 hàng xóm) + đẩy khỏi đá
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
