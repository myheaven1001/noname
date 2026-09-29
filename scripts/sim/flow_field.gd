class_name FlowField
extends RefCounted
## Trường hướng đi: BFS nhiều nguồn từ các ô có người chơi, tính lại mỗi ~0,3 giây.
## Quái chỉ đọc hướng của ô mình đang đứng → đi vòng qua đá mà không phải tìm đường từng con.
## Hướng của một ô chỉ được tính khi có quái hỏi tới (lười), nên chi phí tỉ lệ với số ô có quái.

const UNREACHED := 1 << 30
const N8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

var cell_size: float
var inv_cell: float
var cols: int
var rows: int
var blocked := PackedByteArray()
var rock_at := PackedInt32Array()  # chỉ số đá gần ô + 1 (0 = không có) → đẩy quái khỏi đá chỉ cần xét 1 viên
var dist := PackedInt32Array()
var _dir := PackedVector2Array()
var _dir_version := PackedInt32Array()
var _version := 0
var _queue := PackedInt32Array()


func _init(world_size: Vector2, cell: float) -> void:
	cell_size = cell
	inv_cell = 1.0 / cell
	cols = ceili(world_size.x / cell)
	rows = ceili(world_size.y / cell)
	var n := cols * rows
	blocked.resize(n)
	rock_at.resize(n)
	dist.resize(n)
	dist.fill(UNREACHED)
	_dir.resize(n)
	_dir_version.resize(n)
	_dir_version.fill(-1)
	_queue.resize(n)


func cell_index(p: Vector2) -> int:
	return clampi(int(p.y * inv_cell), 0, rows - 1) * cols + clampi(int(p.x * inv_cell), 0, cols - 1)


func is_blocked(p: Vector2) -> bool:
	return blocked[cell_index(p)] != 0


## rocks: mỗi phần tử (x, y, bán kính).
func mark_rocks(rocks: PackedVector3Array) -> void:
	for ri in rocks.size():
		var rock := rocks[ri]
		var center := Vector2(rock.x, rock.y)
		var reach := rock.z + cell_size
		var x0 := clampi(int((rock.x - reach) * inv_cell), 0, cols - 1)
		var x1 := clampi(int((rock.x + reach) * inv_cell), 0, cols - 1)
		var y0 := clampi(int((rock.y - reach) * inv_cell), 0, rows - 1)
		var y1 := clampi(int((rock.y + reach) * inv_cell), 0, rows - 1)
		for gy in range(y0, y1 + 1):
			for gx in range(x0, x1 + 1):
				var c := gy * cols + gx
				var d := Vector2((gx + 0.5) * cell_size, (gy + 0.5) * cell_size).distance_to(center)
				if d < rock.z:
					blocked[c] = 1
				if d < reach:
					rock_at[c] = ri + 1


func rebuild(sources: PackedVector2Array) -> void:
	_version += 1
	var d := dist
	var q := _queue
	var blk := blocked
	d.fill(UNREACHED)
	var head := 0
	var tail := 0
	for p: Vector2 in sources:
		var c := cell_index(p)
		if d[c] != 0:
			d[c] = 0
			q[tail] = c
			tail += 1
	while head < tail:
		var c := q[head]
		head += 1
		var cx := c % cols
		var nd := d[c] + 1
		var nc := c - 1
		if cx > 0 and blk[nc] == 0 and d[nc] > nd:
			d[nc] = nd
			q[tail] = nc
			tail += 1
		nc = c + 1
		if cx < cols - 1 and blk[nc] == 0 and d[nc] > nd:
			d[nc] = nd
			q[tail] = nc
			tail += 1
		nc = c - cols
		if nc >= 0 and blk[nc] == 0 and d[nc] > nd:
			d[nc] = nd
			q[tail] = nc
			tail += 1
		nc = c + cols
		if nc < cols * rows and blk[nc] == 0 and d[nc] > nd:
			d[nc] = nd
			q[tail] = nc
			tail += 1


## Hướng (đã chuẩn hoá) tới ô lân cận gần người chơi nhất. ZERO = đang ở ô người chơi hoặc không tới được.
func dir_at(p: Vector2) -> Vector2:
	var c := cell_index(p)
	if _dir_version[c] == _version:
		return _dir[c]
	_dir_version[c] = _version
	var best := dist[c]
	var best_dir := Vector2.ZERO
	if best != 0 and best != UNREACHED:
		var cx := c % cols
		var cy := int(float(c) / cols)
		for o: Vector2i in N8:
			var nx := cx + o.x
			var ny := cy + o.y
			if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
				continue
			var nc := ny * cols + nx
			if blocked[nc] != 0:
				continue
			# Không cắt chéo qua góc đá.
			if o.x != 0 and o.y != 0 and (blocked[cy * cols + nx] != 0 or blocked[ny * cols + cx] != 0):
				continue
			if dist[nc] < best:
				best = dist[nc]
				best_dir = Vector2(o)
	_dir[c] = best_dir.normalized()
	return _dir[c]
