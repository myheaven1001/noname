class_name SkillDB
extends RefCounted
## Bảng kỹ năng đọc từ data/skills.csv: mỗi dòng là một cấp của một kỹ năng.
## Kỹ năng chủ động dùng dmg/cooldown/count/area/pierce/speed; bị động dùng `value` (tổng tại cấp đó).

var ids := PackedStringArray()  # theo thứ tự xuất hiện trong file
var _levels := {}  # id -> Array[Dictionary], phần tử k là cấp k + 1


static func load_csv(path: String) -> SkillDB:
	var db := SkillDB.new()
	for row in CsvTable.load_rows(path):
		var id: String = row["id"]
		if not db._levels.has(id):
			db.ids.append(id)
			db._levels[id] = []
		db._levels[id].append(row)
		assert(int(row["level"]) == db._levels[id].size(), "Cấp của %s phải liên tục từ 1" % id)
	return db


func max_level(id: String) -> int:
	return _levels[id].size()


## Dòng cấu hình của kỹ năng `id` ở cấp `lv` (bắt đầu từ 1).
func level(id: String, lv: int) -> Dictionary:
	return _levels[id][lv - 1]


func display_name(id: String) -> String:
	return _levels[id][0]["name"]


func is_passive(id: String) -> bool:
	return _levels[id][0]["kind"] == "passive"
