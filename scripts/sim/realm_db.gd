class_name RealmDB
extends RefCounted
## Bảng cảnh giới đọc từ data/realms.csv: mỗi dòng là một tầng, chỉ số dòng = `PlayerState.realm`.
## Cột thưởng (máu, sát thương, tốc độ) áp dụng khi bước VÀO tầng đó; `cum_*` là tổng dồn tới tầng i.
## `tribulation` > 0 ở tầng cuối của một cảnh giới: đầy linh khí thì phải độ kiếp mới lên được.

var rows: Array[Dictionary] = []
var cum_hp := PackedFloat32Array()
var cum_dmg := PackedFloat32Array()
var cum_move := PackedFloat32Array()


static func load_csv(path: String) -> RealmDB:
	var db := RealmDB.new()
	db.rows = CsvTable.load_rows(path)
	var hp := 0.0
	var dmg := 0.0
	var move := 0.0
	for row in db.rows:
		hp += float(row["max_hp_bonus"])
		dmg += float(row["dmg_bonus"])
		move += float(row["move_bonus"])
		db.cum_hp.append(hp)
		db.cum_dmg.append(dmg)
		db.cum_move.append(move)
	return db


func count() -> int:
	return rows.size()


## "Luyện Khí tầng 7"
func title(i: int) -> String:
	return "%s tầng %d" % [rows[i]["realm"], int(rows[i]["tier"])]


func realm_name(i: int) -> String:
	return rows[i]["realm"]


## Linh khí cần để lên tầng tiếp theo; 0 = đỉnh, không lên nữa.
func qi_to_next(i: int) -> float:
	return rows[i]["qi_to_next"]


func tribulation(i: int) -> int:
	return int(rows[i]["tribulation"])
