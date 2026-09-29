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
var max_radius := 0.0


static func load_csv(path: String) -> EnemyDB:
	var db := EnemyDB.new()
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "Không mở được " + path)
	var header := f.get_csv_line()
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() < header.size() or line[0].is_empty() or line[0].begins_with("#"):
			continue
		var row := {}
		for c in header.size():
			var v := line[c].strip_edges()
			row[header[c]] = v.to_float() if v.is_valid_float() else v
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
	max_radius = maxf(max_radius, row["radius"])
