class_name Skills
extends RefCounted
## Kỹ năng chủ động của người chơi, chạy trên server mỗi tick. Số liệu từng cấp nằm trong data/skills.csv;
## kỹ năng bị động chỉ đổi chỉ số (xem Progression.recompute_stats).

const FIRE_RANGE := 520.0
const SPREAD := 0.16  # góc (rad) giữa các luồng kiếm khí
const SWORD_RADIUS := 12.0
const LIGHTNING_RANGE := 450.0


static func update(w: World, pl: World.PlayerState) -> void:
	for id: String in pl.skills:
		if w.skill_db.is_passive(id):
			continue
		var row := w.skill_db.level(id, pl.skills[id])
		var cd: float = pl.cd.get(id, 0.0)
		cd = maxf(cd - World.DT, 0.0)
		match id:
			"kiem_khi":
				if cd <= 0.0 and _kiem_khi(w, pl, row):
					cd = row["cooldown"]
			"ho_the_kiem":
				_ho_the_kiem(w, pl, row)
			"chuong_tam_loi":
				if cd <= 0.0 and _chuong_tam_loi(w, pl, row):
					cd = row["cooldown"]
		pl.cd[id] = cd


## Vị trí các thanh Hộ thể kiếm tại thời điểm `time` (giây). Client dùng cùng hàm để vẽ.
static func sword_positions(center: Vector2, time: float, row: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := int(row["count"])
	var base := time * float(row["speed"])
	for k in n:
		out.append(center + Vector2.from_angle(base + TAU * k / n) * float(row["area"]))
	return out


## Kiếm khí: bắn `count` luồng toả quạt vào quái gần nhất. Không có mục tiêu thì chưa tính hồi chiêu.
static func _kiem_khi(w: World, pl: World.PlayerState, row: Dictionary) -> bool:
	var j := w.nearest_enemy(pl.pos, FIRE_RANGE)
	if j < 0:
		return false
	var base := (w.store.pos[j] - pl.pos).angle()
	var n := int(row["count"])
	var dmg := float(row["dmg"]) * pl.dmg_mult
	for k in n:
		var a := base + (k - (n - 1) * 0.5) * SPREAD
		w.fire(pl.pos, Vector2.from_angle(a), float(row["speed"]), dmg, int(row["pierce"]))
	return true


## Hộ thể kiếm: kiếm xoay quanh người, mỗi quái chỉ bị kiếm chém lại sau `cooldown` giây.
static func _ho_the_kiem(w: World, pl: World.PlayerState, row: Dictionary) -> void:
	var s := w.store
	var dmg := float(row["dmg"]) * pl.dmg_mult
	var hit_cd := float(row["cooldown"])
	for sp in sword_positions(pl.pos, w.tick * World.DT, row):
		var n := w.query_enemies(sp, SWORD_RADIUS)
		for q in n:
			var j := w.scratch[q]
			if s.orbit_cd[j] > 0.0:
				continue
			s.orbit_cd[j] = hit_cd
			w.damage_enemy(j, dmg, (s.pos[j] - pl.pos).normalized())


## Chưởng tâm lôi: sét đánh `count` quái ngẫu nhiên trong tầm, nổ vùng bán kính `area`.
static func _chuong_tam_loi(w: World, pl: World.PlayerState, row: Dictionary) -> bool:
	var n := w.query_enemies(pl.pos, LIGHTNING_RANGE)
	if n == 0:
		return false
	# Chép vị trí mục tiêu ra trước vì mỗi lần query_enemies ghi đè `scratch`.
	var targets := PackedVector2Array()
	for k in mini(int(row["count"]), n):
		var r := w.rng.randi_range(k, n - 1)
		var tmp := w.scratch[k]
		w.scratch[k] = w.scratch[r]
		w.scratch[r] = tmp
		targets.append(w.store.pos[w.scratch[k]])
	var dmg := float(row["dmg"]) * pl.dmg_mult
	var area := float(row["area"])
	for t: Vector2 in targets:
		var m := w.query_enemies(t, area)
		for q in m:
			var j := w.scratch[q]
			w.damage_enemy(j, dmg, (w.store.pos[j] - t).normalized())
		w.events.append({&"t": &"lightning", &"pos": t, &"radius": area, &"player": pl.id})
	return true
