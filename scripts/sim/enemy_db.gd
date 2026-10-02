class_name EnemyDB
extends RefCounted
## Bảng cấu hình quái đọc từ data/enemies.csv. Type id của một loại quái = số thứ tự dòng.
## Các cột dùng trong vòng lặp nóng được tách ra mảng riêng; cột riêng của từng hành vi
## (dash_*, windup...) nằm trong `rows[type]`.

const BEHAVIOR_CHASE := 0
const BEHAVIOR_WOLF := 1
const BEHAVIORS := {"chase": BEHAVIOR_CHASE, "wolf": BEHAVIOR_WOLF}

var ids := PackedStringArray()
var rows: Array[Dictionary] = []
var behavior := PackedInt32Array()
var spawn_weight := PackedFloat32Array()
var max_hp := PackedFloat32Array()
var speed := PackedFloat32Array()
var radius := PackedFloat32Array()
var mass := PackedFloat32Array()
var contact_dmg := PackedFloat32Array()
var color := PackedColorArray()
# Rơi đồ khi chết
var qi := PackedFloat32Array()  # lượng linh khí của viên rơi ra
var stone_chance := PackedFloat32Array()  # xác suất rơi linh thạch (mỗi người chơi một phần riêng)
var stone_count := PackedFloat32Array()
var immortal_chance := PackedFloat32Array()  # xác suất rơi tiên linh thạch
var vacuum_chance := PackedFloat32Array()  # xác suất rơi Tụ linh phù (hút mọi linh khí)
var max_radius := 0.0


static func load_csv(path: String) -> EnemyDB:
	var db := EnemyDB.new()
	for row in CsvTable.load_rows(path):
		db._add(row)
	return db


func type_of(id: String) -> int:
	return ids.find(id)


func _add(row: Dictionary) -> void:
	assert(BEHAVIORS.has(row["behavior"]), "Hành vi không tồn tại: %s" % row["behavior"])
	ids.append(row["id"])
	rows.append(row)
	behavior.append(BEHAVIORS[row["behavior"]])
	spawn_weight.append(row["spawn_weight"])
	max_hp.append(row["max_hp"])
	speed.append(row["speed"])
	radius.append(row["radius"])
	mass.append(row["mass"])
	contact_dmg.append(row["contact_dmg"])
	color.append(Color.html(row["color"]))
	qi.append(row["qi"])
	stone_chance.append(row["stone_chance"])
	stone_count.append(row["stone_count"])
	immortal_chance.append(row["immortal_chance"])
	vacuum_chance.append(row["vacuum_chance"])
	max_radius = maxf(max_radius, row["radius"])
