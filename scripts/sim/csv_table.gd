class_name CsvTable
extends RefCounted
## Đọc file CSV dữ liệu thành mảng Dictionary: ô là số → float, còn lại → String (ô trống → "").
## Mỗi file CSV dữ liệu cần một file .import với importer="keep", nếu không Godot coi nó là bảng dịch
## và không đóng gói file gốc khi export.


static func load_rows(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
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
		rows.append(row)
	return rows
