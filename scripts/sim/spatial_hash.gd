class_name SpatialHash
extends RefCounted
## Lưới đều + counting sort, dựng lại mỗi tick trong O(n), không cấp phát bộ nhớ.
## Quái trong ô c là items[cell_start[c] .. cell_start[c + 1] - 1].
## Chỉ số trong `items` chỉ hợp lệ tới khi EnemyStore xoá quái (cuối tick).

var cell_size: float
var inv_cell: float
var cols: int
var rows: int
var cell_start := PackedInt32Array()
var items := PackedInt32Array()
var _cell_of := PackedInt32Array()
var _fill := PackedInt32Array()


func _init(world_size: Vector2, cell: float, capacity: int) -> void:
	cell_size = cell
	inv_cell = 1.0 / cell
	cols = ceili(world_size.x / cell)
	rows = ceili(world_size.y / cell)
	cell_start.resize(cols * rows + 1)
	_fill.resize(cols * rows)
	items.resize(capacity)
	_cell_of.resize(capacity)


func rebuild(pos: PackedVector2Array, count: int) -> void:
	var n_cells := cols * rows
	var start := cell_start
	var cell_of := _cell_of
	start.fill(0)
	for i in count:
		var p := pos[i]
		var c := clampi(int(p.y * inv_cell), 0, rows - 1) * cols + clampi(int(p.x * inv_cell), 0, cols - 1)
		cell_of[i] = c
		start[c + 1] += 1
	for c in n_cells:
		start[c + 1] += start[c]
	var fill := _fill
	for c in n_cells:
		fill[c] = start[c]
	var out := items
	for i in count:
		var c := cell_of[i]
		out[fill[c]] = i
		fill[c] += 1


## Hộp ô bao quanh hình tròn (center, radius): Vector4i(x0, y0, x1, y1), đã kẹp trong lưới.
func cell_box(center: Vector2, radius: float) -> Vector4i:
	return Vector4i(
		clampi(int((center.x - radius) * inv_cell), 0, cols - 1),
		clampi(int((center.y - radius) * inv_cell), 0, rows - 1),
		clampi(int((center.x + radius) * inv_cell), 0, cols - 1),
		clampi(int((center.y + radius) * inv_cell), 0, rows - 1))
