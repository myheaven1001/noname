# Tiên Lộ — prototype

Prototype Godot 4.4 (GDScript, renderer Compatibility để export được web, iOS, Android) cho game
survivors co-op phong cách tiên hiệp. Bản này có phần lõi quái (hàng trăm đến hàng nghìn quái ở
120fps, logic tách khỏi hình ảnh để sau này chạy trên server headless) và vòng chơi cảnh giới:
linh khí → lên tầng → chọn kỹ năng → thiên kiếp → đột phá.

Hình ảnh hiện là hình tròn tạm; art thật chỉ thay texture/sprite sheet, không đổi logic.

## Chạy

```bash
# Mở trong editor Godot 4.4+ rồi F5, hoặc:
godot --path .

# Đo hiệu năng mô phỏng + kiểm tra bất biến (không cần GPU):
godot --headless --path . --import
godot --headless --path . -s res://tools/bench.gd

# Giả lập một trận 6 phút để cân bằng nhịp lên tầng (không cần GPU):
godot --headless --path . -s res://tools/simulate.gd

# Chụp màn hình cảnh chơi trên máy không có màn hình (Linux); DEMO=1 WHEN=trib chụp lúc thiên kiếp:
SHOT=shot.png FRAMES=900 xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/screenshot.gd
```

### Bản web

```bash
GODOT=/đường/dẫn/godot tools/build_web.sh   # cần export template 4.4.1 (web_nothreads_release.zip)
```

Kết quả nằm trong `build/web/`. `play.html` (từ `web/play.html`) là trang chơi riêng: engine được
nén gzip thành `engine.gz.wasm` (~9MB thay vì ~42MB) và trang tự giải nén bằng `DecompressionStream`.
Export tắt đa luồng nên không cần header cross-origin isolation.

Các file `data/*.csv.import` đặt importer là `keep`: mặc định Godot coi `.csv` là bảng dịch và
**không** đóng gói file gốc khi export (web/mobile sẽ không đọc được dữ liệu). Mọi file CSV dữ liệu
mới cũng cần một file `.import` như vậy.

## Vòng chơi cảnh giới

- **Rơi đồ** (`data/enemies.csv`, cột `qi`, `stone_*`, `immortal_chance`, `vacuum_chance`):
  linh khí rơi chung, ai nhặt cũng được; linh thạch và tiên linh thạch rơi **riêng cho từng người chơi**
  (client chỉ vẽ phần của mình). Vật phẩm trong bán kính hút tự bay về người chơi. Tụ linh phù (rơi
  từ quái tinh anh) hút mọi viên linh khí trên bản đồ. Kho đầy thì linh khí mới cộng vào viên gần nhất.
- **Cảnh giới** (`data/realms.csv`): Luyện Khí 1–9 → Trúc Cơ 1–9 → Kết Đan. Mỗi tầng một lượng linh
  khí; thưởng máu / sát thương / tốc độ khi bước vào tầng.
- **Chọn kỹ năng** (`data/skills.csv`): mỗi lần lên tầng chọn 1 trong 3, không tạm dừng trận (co-op
  không pause được); lên nhiều tầng liền thì các lượt chọn xếp hàng. Lựa chọn xáo bằng rng của server.
  Chủ động: Kiếm khí, Hộ thể kiếm, Chưởng tâm lôi (5 cấp). Bị động: Thân pháp, Tụ linh trận, Kim cang thể.
- **Thiên kiếp**: đầy linh khí ở tầng cuối của một cảnh giới thì sét đánh theo đợt, mỗi tia có vòng
  cảnh báo, tia đầu nhắm đúng chỗ người chơi đứng. Sống sót → đột phá + 1 tiên linh thạch. Gục → thất
  bại, giữ 70% linh khí, tích đủ thì độ kiếp lại. Thiên lôi đánh cả quái (gấp 3 sát thương).

Nhịp hiện tại theo `tools/simulate.gd` (bot chạy vòng, ưu tiên kỹ năng chủ động): tiểu thiên kiếp
~1 phút 50, Trúc Cơ 9 ~2 phút 50, Kết Đan ~3 phút 50. Nhịp với người chơi thật cần chơi thử để chốt.

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

Phím trong cảnh chơi (tránh F1–F12 vì trên trình duyệt chúng mở trợ giúp / tải lại trang):

| Phím | Tác dụng |
|---|---|
| WASD / mũi tên | Di chuyển (kỹ năng tự thi triển) |
| `1` / `2` / `3` | Chọn kỹ năng khi lên tầng (hoặc bấm vào thẻ) |
| `8` / `9` / `0` | Cố định 500 / 1000 / 2000 quái |
| `7` | Quân số tăng dần trở lại |
| `+` / `-` | Thêm/bớt 100 quái |
| `F` | Đóng băng quái quanh người chơi 1,5 giây (test huỷ đòn đang gồng) |
| `G` | Hiện flow field |
| `H` | Hiện trạng thái quái quanh người chơi (ĐUỔI / GỒNG / LAO / NGHỈ) |
| `J` | Bật/tắt AI |
| `K` | Ẩn/hiện số liệu hiệu năng |
| `V` | Bật/tắt vsync (tắt để xem FPS tối đa) |

## Cấu trúc

```
data/enemies.csv                 Bảng quái: máu, tốc độ, bán kính, thông số lao, rơi đồ (không viết cứng trong code)
data/realms.csv                  Bảng cảnh giới: linh khí mỗi tầng, thưởng khi vào tầng, tầng nào phải độ kiếp
data/skills.csv                  Bảng kỹ năng: mỗi dòng là một cấp, kèm mô tả hiện trên thẻ chọn
scripts/sim/                     Mô phỏng phía server — không dùng Node, chạy headless được
  csv_table.gd                   Đọc CSV dữ liệu thành mảng Dictionary
  enemy_db.gd                    Bảng quái → mảng cấu hình theo type id
  realm_db.gd, skill_db.gd       Bảng cảnh giới, bảng kỹ năng
  enemy_store.gd                 Dữ liệu quái dạng SoA, mảng đặc, xoá bằng swap-remove, uid ổn định cho mạng
  drop_store.gd                  Vật phẩm rơi dạng SoA, có chủ sở hữu (phần riêng từng người chơi)
  progression.gd                 Linh khí, lên tầng, lượt chọn kỹ năng, thiên kiếp
  skills.gd                      Kỹ năng chủ động: Kiếm khí, Hộ thể kiếm, Chưởng tâm lôi
  spatial_hash.gd                Lưới đều + counting sort, dựng lại mỗi tick O(n), không cấp phát
  flow_field.gd                  BFS nhiều nguồn từ người chơi, hướng từng ô tính lười
  world.gd                       Thứ tự tick, người chơi, đạn, tia thiên lôi, rơi/nhặt đồ, spawn/despawn, sự kiện mạng
  behaviors/wolf.gd              Sói yêu: Đuổi → Gồng (khoá hướng) → Lao → Nghỉ
scripts/render/
  enemy_renderer.gd              MultiMeshInstance2D, 1 draw call, nội suy 30Hz → tần số màn hình
  drop_renderer.gd               MultiMesh cho vật phẩm rơi, chỉ vẽ phần của người chơi local
  fx_layer.gd                    Vạch cảnh báo, vòng thiên lôi, đạn, kiếm, người chơi, hiệu ứng từ sự kiện
scripts/game/
  main.gd                        Cảnh chơi: nhập phím, nối World với renderer và HUD
  hud.gd                         Cảnh giới, linh khí, máu, tiền, thẻ chọn kỹ năng, banner thiên kiếp
tools/bench.gd                   Benchmark headless + kiểm tra bất biến + test vòng cảnh giới
tools/simulate.gd                Giả lập một trận để cân bằng nhịp lên tầng
tools/screenshot.gd              Chạy cảnh chơi và lưu ảnh (dùng với xvfb-run)
tools/build_web.sh               Export bản web + chuẩn bị file để đăng
```

## Thứ tự một tick (30Hz)

1. Lưu vị trí cũ (để nội suy khi vẽ)
2. Spawn bù quân số ngoài tầm nhìn; máu tăng theo số người chơi và thời gian
3. Flow field (mỗi 9 tick ≈ 0,3 giây)
4. Dựng lại spatial hash
5. Người chơi: di chuyển, kỹ năng chủ động, thiên kiếp (sinh tia sét)
6. Tia thiên lôi tới hạn: đánh người chơi và quái trong vùng
7. Quái: đếm giờ, choáng (huỷ đòn đang gồng/lao), hành vi theo loại
8. Di chuyển quái: vận tốc + đẩy lùi + tách nhau (mỗi 2 tick, xét tối đa 24 hàng xóm) + đẩy khỏi đá
9. Va chạm quái → người chơi (cú lao chỉ trúng mỗi người 1 lần)
10. Đạn: kiểm tra theo cả đoạn đường bay, xuyên theo cấp kỹ năng
11. Vật phẩm: hút về người chơi trong bán kính, chạm thì nhặt (linh khí có thể làm lên tầng)
12. Xoá quái chết / quá xa (duyệt ngược, swap-remove)

`World.events` sau mỗi tick là danh sách sự kiện server sẽ gửi cho client: `spawn`, `windup`,
`dash`, `attack_cancel`, `death`, `player_hit`, `drop`, `pickup`, `level_up`, `offer`, `skill`,
`lightning`, `strike_warn`, `strike`, `trib_start`, `trib_end`, `breakthrough`.

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

- Mạng: server headless gửi `events` + hiệu chỉnh vị trí qua WebSocket; client chạy cùng code di chuyển;
  lựa chọn kỹ năng thành gói tin gửi server (đã tách qua tín hiệu `GameHud.choose`).
- Cửa hàng giữa các trận tiêu linh thạch / tiên linh thạch (hiện chỉ tích luỹ trong trận).
- Điều khiển cảm ứng (joystick ảo), sprite sheet và animation thật.
