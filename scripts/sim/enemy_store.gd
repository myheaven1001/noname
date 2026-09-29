class_name EnemyStore
extends RefCounted
## Dữ liệu mọi quái dạng mảng song song (SoA) — không có Node nào cho từng con.
## Mảng luôn "đặc": quái 0..count-1 đều đang tồn tại; xoá bằng cách chuyển con cuối vào chỗ trống.
## Vì chỉ số i thay đổi khi xoá, mạng dùng `uid` (ổn định suốt đời một con quái).
## Trong vòng lặp nóng, lấy mảng ra biến local (var pos := store.pos) — nhanh hơn ~4 lần.

## Trạng thái dùng chung cho mọi hành vi có đòn đánh chuẩn bị (sói lao, tà tu bắn...).
enum { S_CHASE, S_WINDUP, S_DASH, S_RECOVER }

var capacity: int
var count := 0
var next_uid := 1

var uid := PackedInt32Array()
var type := PackedInt32Array()
var pos := PackedVector2Array()
var prev_pos := PackedVector2Array()  # vị trí tick trước, để nội suy khi vẽ
var vel := PackedVector2Array()
var knock := PackedVector2Array()  # vận tốc đẩy lùi, tắt dần
var dir := PackedVector2Array()  # hướng đòn đã khoá (vd. hướng lao)
var facing := PackedFloat32Array()  # 1 hoặc -1, để lật sprite
var hp := PackedFloat32Array()
var state := PackedInt32Array()
var timer := PackedFloat32Array()  # đếm ngược của trạng thái hiện tại
var cd := PackedFloat32Array()  # hồi chiêu đòn đặc biệt
var stun := PackedFloat32Array()  # choáng/đóng băng còn lại
var flash := PackedFloat32Array()  # nháy trắng khi trúng đòn
var hit_mask := PackedInt32Array()  # bit người chơi đã trúng trong cú lao hiện tại
var target := PackedInt32Array()  # chỉ số người chơi đang nhắm


func _init(cap: int) -> void:
	capacity = cap
	uid.resize(cap)
	type.resize(cap)
	pos.resize(cap)
	prev_pos.resize(cap)
	vel.resize(cap)
	knock.resize(cap)
	dir.resize(cap)
	facing.resize(cap)
	hp.resize(cap)
	state.resize(cap)
	timer.resize(cap)
	cd.resize(cap)
	stun.resize(cap)
	flash.resize(cap)
	hit_mask.resize(cap)
	target.resize(cap)


## Trả về chỉ số con mới, hoặc -1 nếu đầy.
func spawn(t: int, p: Vector2, health: float) -> int:
	if count >= capacity:
		return -1
	var i := count
	count += 1
	uid[i] = next_uid
	next_uid += 1
	type[i] = t
	pos[i] = p
	prev_pos[i] = p
	vel[i] = Vector2.ZERO
	knock[i] = Vector2.ZERO
	dir[i] = Vector2.RIGHT
	facing[i] = 1.0
	hp[i] = health
	state[i] = S_CHASE
	timer[i] = 0.0
	cd[i] = 0.0
	stun[i] = 0.0
	flash[i] = 0.0
	hit_mask[i] = 0
	target[i] = -1
	return i


## Xoá con i bằng cách chuyển con cuối vào chỗ của nó. Khi xoá trong vòng lặp, duyệt từ cuối về đầu.
func remove(i: int) -> void:
	count -= 1
	var last := count
	if i == last:
		return
	uid[i] = uid[last]
	type[i] = type[last]
	pos[i] = pos[last]
	prev_pos[i] = prev_pos[last]
	vel[i] = vel[last]
	knock[i] = knock[last]
	dir[i] = dir[last]
	facing[i] = facing[last]
	hp[i] = hp[last]
	state[i] = state[last]
	timer[i] = timer[last]
	cd[i] = cd[last]
	stun[i] = stun[last]
	flash[i] = flash[last]
	hit_mask[i] = hit_mask[last]
	target[i] = target[last]
