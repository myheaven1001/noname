class_name DropStore
extends RefCounted
## Vật phẩm rơi (linh khí, linh thạch, tiên linh thạch, Tụ linh phù) dạng SoA, mảng đặc, uid ổn định cho mạng.
## Tụ linh phù: người nhặt hút mọi viên linh khí trên bản đồ về phía mình.
## `owner` = -1: ai nhặt cũng được (linh khí); ≥ 0: phần riêng của người chơi đó (linh thạch),
## client chỉ vẽ vật phẩm của mình nên co-op không ai tranh phần của ai.

enum { QI, STONE, IMMORTAL, VACUUM }

var capacity: int
var count := 0
var next_uid := 1
var uid := PackedInt32Array()
var kind := PackedInt32Array()
var pos := PackedVector2Array()
var prev_pos := PackedVector2Array()
var value := PackedFloat32Array()
var owner := PackedInt32Array()
var pulled := PackedInt32Array()  # người chơi đang hút vật phẩm này, -1 = nằm yên
var speed := PackedFloat32Array()


func _init(cap: int) -> void:
	capacity = cap
	uid.resize(cap)
	kind.resize(cap)
	pos.resize(cap)
	prev_pos.resize(cap)
	value.resize(cap)
	owner.resize(cap)
	pulled.resize(cap)
	speed.resize(cap)


## Trả về chỉ số vật phẩm mới, hoặc -1 nếu đầy.
func spawn(k: int, p: Vector2, v: float, own: int) -> int:
	if count >= capacity:
		return -1
	var i := count
	count += 1
	uid[i] = next_uid
	next_uid += 1
	kind[i] = k
	pos[i] = p
	prev_pos[i] = p
	value[i] = v
	owner[i] = own
	pulled[i] = -1
	speed[i] = 0.0
	return i


func remove(i: int) -> void:
	count -= 1
	var last := count
	if i == last:
		return
	uid[i] = uid[last]
	kind[i] = kind[last]
	pos[i] = pos[last]
	prev_pos[i] = prev_pos[last]
	value[i] = value[last]
	owner[i] = owner[last]
	pulled[i] = pulled[last]
	speed[i] = speed[last]
