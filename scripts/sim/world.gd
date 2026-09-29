class_name World
extends RefCounted
## Mô phỏng trận đấu phía server, chạy ở nhịp cố định TICK_RATE.
## Không dùng Node/hình ảnh để chạy được trên server headless.
## Mọi quyết định (máu, chết, gồng/lao) nằm ở đây; `events` của mỗi tick là thứ sẽ gửi cho client.

const TICK_RATE := 30
const DT := 1.0 / TICK_RATE
const ARENA := Vector2(4096, 4096)
const CELL := 64.0  # ô của flow field
const GRID_CELL := 48.0  # ô của spatial hash: ≥ 2 × bán kính quái lớn nhất để 3x3 ô đủ bắt mọi cặp chồng lấn
const MAX_ENEMIES := 4096
const MAX_ATTACKERS := 6  # số quái được gồng/lao cùng lúc, để người chơi còn né được
const SPAWN_PER_TICK := 40
const SPAWN_MIN := 700.0
const SPAWN_MAX := 950.0
const DESPAWN_DIST := 1500.0
const FLOW_EVERY := 9  # tick (~0,3 giây)
const MAX_NEIGHBORS := 10  # số hàng xóm chồng lấn tối đa cộng vào lực tách
const MAX_CANDIDATES := 24  # số hàng xóm tối đa phải xét, giữ chi phí O(n) khi quái dồn đặc
const SEPARATION := 0.5
const KNOCKBACK := 160.0
const KNOCK_DECAY := 0.75
const HP_PER_EXTRA_PLAYER := 0.6
const HP_PER_MINUTE := 0.1

const PLAYER_SPEED := 190.0
const PLAYER_RADIUS := 16.0
const PLAYER_HP := 100.0
const PLAYER_IFRAMES := 0.5

const MAX_PROJ := 512
const PROJ_SPEED := 900.0
const PROJ_LIFE := 0.8
const PROJ_DMG := 12.0
const PROJ_RADIUS := 6.0
const PROJ_PIERCE := 1
const FIRE_INTERVAL := 0.12
const FIRE_RANGE := 520.0


class PlayerState:
	var id := 0
	var pos := Vector2.ZERO
	var prev_pos := Vector2.ZERO
	var input := Vector2.ZERO
	var hp := 0.0
	var iframes := 0.0
	var fire_cd := 0.0
	var deaths := 0


var db: EnemyDB
var store: EnemyStore
var grid: SpatialHash
var flow: FlowField
var players: Array[PlayerState] = []
var rocks := PackedVector3Array()  # (x, y, bán kính)
var events: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var tick := 0
var target_population := 500
var attackers := 0
var kills := 0
var ai_enabled := true
var last_tick_usec := 0

# Đạn kiếm khí của người chơi (SoA, mảng đặc).
var proj_count := 0
var proj_pos := PackedVector2Array()
var proj_prev := PackedVector2Array()
var proj_vel := PackedVector2Array()
var proj_life := PackedFloat32Array()
var proj_pierce := PackedInt32Array()
var proj_last_hit := PackedInt32Array()  # uid quái vừa trúng, tránh trúng lại cùng con

var _total_weight := 0.0
var _flow_sources := PackedVector2Array()


func _init(p_db: EnemyDB, seed_value := 1) -> void:
	db = p_db
	rng.seed = seed_value
	store = EnemyStore.new(MAX_ENEMIES)
	grid = SpatialHash.new(ARENA, GRID_CELL, MAX_ENEMIES)
	flow = FlowField.new(ARENA, CELL)
	proj_pos.resize(MAX_PROJ)
	proj_prev.resize(MAX_PROJ)
	proj_vel.resize(MAX_PROJ)
	proj_life.resize(MAX_PROJ)
	proj_pierce.resize(MAX_PROJ)
	proj_last_hit.resize(MAX_PROJ)
	for w in db.spawn_weight:
		_total_weight += w
	_make_rocks()


func add_player(p: Vector2) -> PlayerState:
	var pl := PlayerState.new()
	pl.id = players.size()
	pl.pos = p
	pl.prev_pos = p
	pl.hp = PLAYER_HP
	players.append(pl)
	return pl


func step() -> void:
	var t0 := Time.get_ticks_usec()
	tick += 1
	events.clear()
	_save_prev()
	_spawn()
	if tick % FLOW_EVERY == 1:
		_rebuild_flow()
	grid.rebuild(store.pos, store.count)  # hợp lệ tới _remove_dead_and_far()
	_update_players()
	_update_enemies()
	_move_enemies()
	_contact_damage()
	_update_projectiles()
	_remove_dead_and_far()
	last_tick_usec = Time.get_ticks_usec() - t0


# --- API cho các hành vi ------------------------------------------------------

## Đuổi người chơi gần nhất theo flow field; tới gần thì đi thẳng.
func chase(i: int, spd: float) -> void:
	var s := store
	var p := s.pos[i]
	var tgt := nearest_player(p)
	s.target[i] = tgt
	if tgt < 0:
		s.vel[i] = Vector2.ZERO
		return
	var to := players[tgt].pos - p
	var dist2 := to.length_squared()
	var touch := PLAYER_RADIUS + db.radius[s.type[i]]
	if dist2 < touch * touch:
		# Đã chạm người chơi: đứng lại vây quanh thay vì dồn đống vào tâm.
		s.vel[i] = s.vel[i].lerp(Vector2.ZERO, 0.5)
		return
	var d := flow.dir_at(p)
	if d == Vector2.ZERO or dist2 < CELL * CELL * 2.25:
		d = to.normalized()
	s.vel[i] = s.vel[i].lerp(d * spd, 0.25)


func nearest_player(p: Vector2) -> int:
	var best := -1
	var best_d2 := INF
	for k in players.size():
		var d2 := p.distance_squared_to(players[k].pos)
		if d2 < best_d2:
			best_d2 = d2
			best = k
	return best


func is_blocked(p: Vector2) -> bool:
	return p.x < 0.0 or p.y < 0.0 or p.x >= ARENA.x or p.y >= ARENA.y or flow.is_blocked(p)


func emit(kind: StringName, i: int, data := {}) -> void:
	data[&"t"] = kind
	data[&"uid"] = store.uid[i]
	data[&"pos"] = store.pos[i]
	events.append(data)


func damage_enemy(j: int, dmg: float, from_dir: Vector2) -> void:
	var s := store
	s.hp[j] -= dmg
	s.flash[j] = 0.12
	# Siêu giáp khi đang lao: không bị đẩy lùi, cú lao không bị ngắt.
	if s.state[j] != EnemyStore.S_DASH:
		s.knock[j] += from_dir * (KNOCKBACK / db.mass[s.type[j]])
	if s.hp[j] <= 0.0:
		kills += 1
		emit(&"death", j)  # server sẽ sinh linh khí/linh thạch tại đây


## Choáng/đóng băng mọi quái trong bán kính (dùng để test huỷ đòn đang gồng).
func stun_area(center: Vector2, radius: float, duration: float) -> void:
	var s := store
	for i in s.count:
		if s.pos[i].distance_squared_to(center) <= radius * radius:
			s.stun[i] = maxf(s.stun[i], duration)


func hp_scale() -> float:
	var minutes := tick * DT / 60.0
	return (1.0 + HP_PER_EXTRA_PLAYER * (players.size() - 1)) * (1.0 + HP_PER_MINUTE * minutes)


# --- Các bước của một tick ------------------------------------------------------

func _save_prev() -> void:
	var pos := store.pos
	var prev := store.prev_pos
	for i in store.count:
		prev[i] = pos[i]
	for pl: PlayerState in players:
		pl.prev_pos = pl.pos
	for k in proj_count:
		proj_prev[k] = proj_pos[k]


func _spawn() -> void:
	var need := mini(target_population - store.count, SPAWN_PER_TICK)
	if need <= 0 or players.is_empty():
		return
	var scale := hp_scale()
	for k in need:
		var pl := players[rng.randi_range(0, players.size() - 1)]
		var p := pl.pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(SPAWN_MIN, SPAWN_MAX)
		p = p.clamp(Vector2(CELL, CELL), ARENA - Vector2(CELL, CELL))
		if flow.is_blocked(p):
			continue
		var t := _pick_type()
		var i := store.spawn(t, p, db.max_hp[t] * scale)
		if i < 0:
			return
		emit(&"spawn", i, {&"type": t})


func _pick_type() -> int:
	var r := rng.randf() * _total_weight
	for t in db.spawn_weight.size():
		r -= db.spawn_weight[t]
		if r <= 0.0:
			return t
	return 0


func _rebuild_flow() -> void:
	_flow_sources.resize(players.size())
	for k in players.size():
		_flow_sources[k] = players[k].pos
	flow.rebuild(_flow_sources)


func _update_players() -> void:
	for pl: PlayerState in players:
		pl.iframes = maxf(pl.iframes - DT, 0.0)
		pl.pos = _resolve_static(pl.pos + pl.input.limit_length(1.0) * PLAYER_SPEED * DT, PLAYER_RADIUS)
		pl.fire_cd -= DT
		if pl.fire_cd <= 0.0:
			var j := _nearest_enemy(pl.pos, FIRE_RANGE)
			if j >= 0:
				_fire(pl.pos, (store.pos[j] - pl.pos).normalized())
				pl.fire_cd = FIRE_INTERVAL


func _update_enemies() -> void:
	var s := store
	var n := s.count
	var state := s.state
	var timer := s.timer
	var cd := s.cd
	var stun := s.stun
	var flash := s.flash
	var vel := s.vel
	var type := s.type
	var beh := db.behavior
	var spd := db.speed
	var radius := db.radius
	var pos := s.pos
	var target := s.target
	var n_players := players.size()
	var close2 := CELL * CELL * 2.25
	attackers = 0
	for i in n:
		if state[i] == EnemyStore.S_WINDUP or state[i] == EnemyStore.S_DASH:
			attackers += 1
	for i in n:
		timer[i] -= DT
		cd[i] -= DT
		if flash[i] > 0.0:
			flash[i] = maxf(flash[i] - DT, 0.0)
		if stun[i] > 0.0:
			stun[i] -= DT
			if state[i] == EnemyStore.S_WINDUP or state[i] == EnemyStore.S_DASH:
				_cancel_attack(i)
			vel[i] = Vector2.ZERO
			continue
		if not ai_enabled:
			vel[i] = Vector2.ZERO
			continue
		if beh[type[i]] == EnemyDB.BEHAVIOR_WOLF:
			WolfBehavior.tick(self, i)
			continue
		# Đuổi theo (giống chase(), viết thẳng vào vòng lặp vì đây là đường nóng nhất).
		var p := pos[i]
		var tgt := 0
		if n_players > 1:
			tgt = nearest_player(p)
		elif n_players == 0:
			tgt = -1
		target[i] = tgt
		if tgt < 0:
			vel[i] = Vector2.ZERO
			continue
		var to := players[tgt].pos - p
		var dist2 := to.length_squared()
		var touch := PLAYER_RADIUS + radius[type[i]]
		if dist2 < touch * touch:
			vel[i] = vel[i].lerp(Vector2.ZERO, 0.5)
			continue
		var d := flow.dir_at(p)
		if d == Vector2.ZERO or dist2 < close2:
			d = to.normalized()
		vel[i] = vel[i].lerp(d * spd[type[i]], 0.25)


func _cancel_attack(i: int) -> void:
	store.state[i] = EnemyStore.S_CHASE
	store.cd[i] = maxf(store.cd[i], 1.0)
	attackers -= 1
	emit(&"attack_cancel", i)  # client phải gỡ vạch cảnh báo


func _move_enemies() -> void:
	var s := store
	var n := s.count
	var pos := s.pos
	var vel := s.vel
	var knock := s.knock
	var type := s.type
	var facing := s.facing
	var sep := s.sep
	var radius := db.radius
	var start := grid.cell_start
	var items := grid.items
	var cols := grid.cols
	var rows := grid.rows
	var inv := grid.inv_cell
	var rock_at := flow.rock_at
	var rock_inv := flow.inv_cell
	var rock_cols := flow.cols
	var rock_rows := flow.rows
	var lo := Vector2(8, 8)
	var hi := ARENA - lo
	var parity := tick & 1
	for i in n:
		var p := pos[i]
		var r := radius[type[i]]
		# Tách nhau: mỗi con tính lại lực tách mỗi 2 tick (xen kẽ theo chẵn/lẻ), tick kia dùng lại.
		# Lực tách là hiệu ứng mềm nên trễ 1 tick không nhìn thấy được, còn chi phí giảm một nửa.
		if (i & 1) == parity:
			var cx := clampi(int(p.x * inv), 0, cols - 1)
			var cy := clampi(int(p.y * inv), 0, rows - 1)
			var push := Vector2.ZERO
			var seen := 0
			var budget := MAX_CANDIDATES
			# Duyệt 9 ô bắt đầu từ một ô xoay vòng theo (i, tick): khi hết ngân sách giữa chừng,
			# phần bị bỏ qua đổi hướng liên tục nên không làm cả đám trôi lệch về một phía.
			var first := (i * 7 + tick) % 9
			for q in 9:
				var o := first + q
				if o >= 9:
					o -= 9
				var gx := cx + o % 3 - 1
				@warning_ignore("integer_division")
				var gy := cy + o / 3 - 1
				if gx < 0 or gy < 0 or gx >= cols or gy >= rows:
					continue
				var c := gy * cols + gx
				for k in range(start[c], start[c + 1]):
					var j := items[k]
					budget -= 1
					var d := p - pos[j]
					var rr := r + radius[type[j]]
					var d2 := d.length_squared()
					if d2 < rr * rr and j != i:
						if d2 < 0.0001:
							push += Vector2.from_angle(float(i)) * (rr * 0.5)
						else:
							var dl := sqrt(d2)
							push += d * ((rr - dl) / dl)
						seen += 1
					if seen >= MAX_NEIGHBORS or budget <= 0:
						break
				if seen >= MAX_NEIGHBORS or budget <= 0:
					break
			sep[i] = push
		var v := vel[i] + knock[i]
		knock[i] = knock[i] * KNOCK_DECAY
		if absf(v.x) > 5.0:
			facing[i] = signf(v.x)
		var np := p + v * DT + sep[i] * SEPARATION
		var rk := rock_at[clampi(int(p.y * rock_inv), 0, rock_rows - 1) * rock_cols
			+ clampi(int(p.x * rock_inv), 0, rock_cols - 1)]
		if rk > 0:
			np = _push_out_rock(np, r, rk - 1)
		pos[i] = np.clamp(lo, hi)


func _contact_damage() -> void:
	var s := store
	var start := grid.cell_start
	var items := grid.items
	for pl: PlayerState in players:
		var box := grid.cell_box(pl.pos, PLAYER_RADIUS + db.max_radius + CELL * 0.5)
		for cy in range(box.y, box.w + 1):
			for cx in range(box.x, box.z + 1):
				var c := cy * grid.cols + cx
				for k in range(start[c], start[c + 1]):
					var j := items[k]
					if s.hp[j] <= 0.0:
						continue
					var rr := PLAYER_RADIUS + db.radius[s.type[j]]
					if pl.pos.distance_squared_to(s.pos[j]) >= rr * rr:
						continue
					if s.state[j] == EnemyStore.S_DASH:
						# Mỗi cú lao chỉ gây sát thương 1 lần cho mỗi người, bỏ qua bất tử.
						var bit := 1 << pl.id
						if s.hit_mask[j] & bit:
							continue
						s.hit_mask[j] |= bit
						_hurt_player(pl, db.rows[s.type[j]]["dash_dmg"], true)
					else:
						_hurt_player(pl, db.contact_dmg[s.type[j]], false)


func _hurt_player(pl: PlayerState, dmg: float, ignore_iframes: bool) -> void:
	if pl.iframes > 0.0 and not ignore_iframes:
		return
	pl.hp -= dmg
	pl.iframes = PLAYER_IFRAMES
	events.append({&"t": &"player_hit", &"player": pl.id, &"dmg": dmg})
	if pl.hp <= 0.0:
		pl.deaths += 1
		pl.hp = PLAYER_HP  # cảnh test: hồi sinh tại chỗ


func _fire(from: Vector2, d: Vector2) -> void:
	if proj_count >= MAX_PROJ:
		return
	var k := proj_count
	proj_count += 1
	proj_pos[k] = from
	proj_prev[k] = from
	proj_vel[k] = d * PROJ_SPEED
	proj_life[k] = PROJ_LIFE
	proj_pierce[k] = PROJ_PIERCE
	proj_last_hit[k] = -1


func _update_projectiles() -> void:
	var k := 0
	while k < proj_count:
		var a := proj_pos[k]
		var b := a + proj_vel[k] * DT
		proj_pos[k] = b
		proj_life[k] -= DT
		if proj_life[k] > 0.0 and _projectile_hits(k, a, b):
			k += 1
		else:
			_remove_projectile(k)


## Kiểm tra va chạm theo cả đoạn a→b (đạn nhanh không xuyên qua quái). Trả false nếu đạn đã hết xuyên.
func _projectile_hits(k: int, a: Vector2, b: Vector2) -> bool:
	var s := store
	var start := grid.cell_start
	var items := grid.items
	var d := proj_vel[k].normalized()
	var box := grid.cell_box((a + b) * 0.5, a.distance_to(b) * 0.5 + PROJ_RADIUS + db.max_radius + CELL * 0.5)
	for cy in range(box.y, box.w + 1):
		for cx in range(box.x, box.z + 1):
			var c := cy * grid.cols + cx
			for kk in range(start[c], start[c + 1]):
				var j := items[kk]
				if s.hp[j] <= 0.0 or s.uid[j] == proj_last_hit[k]:
					continue
				var rr := PROJ_RADIUS + db.radius[s.type[j]]
				var q := Geometry2D.get_closest_point_to_segment(s.pos[j], a, b)
				if q.distance_squared_to(s.pos[j]) >= rr * rr:
					continue
				damage_enemy(j, PROJ_DMG, d)
				proj_last_hit[k] = s.uid[j]
				proj_pierce[k] -= 1
				if proj_pierce[k] < 0:
					return false
	return true


func _remove_projectile(k: int) -> void:
	proj_count -= 1
	var last := proj_count
	if k == last:
		return
	proj_pos[k] = proj_pos[last]
	proj_prev[k] = proj_prev[last]
	proj_vel[k] = proj_vel[last]
	proj_life[k] = proj_life[last]
	proj_pierce[k] = proj_pierce[last]
	proj_last_hit[k] = proj_last_hit[last]


func _remove_dead_and_far() -> void:
	var s := store
	var far2 := DESPAWN_DIST * DESPAWN_DIST
	var excess := s.count - target_population  # khi giảm mật độ trong lúc test
	var i := s.count - 1
	while i >= 0:
		var remove := s.hp[i] <= 0.0
		if not remove:
			remove = true
			for pl: PlayerState in players:
				if pl.pos.distance_squared_to(s.pos[i]) < far2:
					remove = false
					break
			# Quái ở quá xa bị xoá; bộ spawn sẽ bù lại con mới gần người chơi.
		if not remove and excess > 0:
			remove = true
			excess -= 1
		if remove:
			s.remove(i)
		i -= 1


# --- Tiện ích ------------------------------------------------------------------

func _nearest_enemy(p: Vector2, max_range: float) -> int:
	var s := store
	var start := grid.cell_start
	var items := grid.items
	var best := -1
	var best_d2 := max_range * max_range
	var box := grid.cell_box(p, max_range)
	for cy in range(box.y, box.w + 1):
		for cx in range(box.x, box.z + 1):
			var c := cy * grid.cols + cx
			for k in range(start[c], start[c + 1]):
				var j := items[k]
				if s.hp[j] <= 0.0:
					continue
				var d2 := p.distance_squared_to(s.pos[j])
				if d2 < best_d2:
					best_d2 = d2
					best = j
	return best


func _resolve_static(p: Vector2, r: float) -> Vector2:
	var rk := flow.rock_at[flow.cell_index(p)]
	if rk > 0:
		p = _push_out_rock(p, r, rk - 1)
	return p.clamp(Vector2(r, r), ARENA - Vector2(r, r))


func _push_out_rock(p: Vector2, r: float, rock_index: int) -> Vector2:
	var rock := rocks[rock_index]
	var c := Vector2(rock.x, rock.y)
	var d := p - c
	var min_d := rock.z + r
	var d2 := d.length_squared()
	if d2 >= min_d * min_d:
		return p
	if d2 < 0.0001:
		return c + Vector2(min_d, 0.0)
	return c + d * (min_d / sqrt(d2))


func _make_rocks() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var center := ARENA * 0.5
	for k in 14:
		var p := center + Vector2.from_angle(r.randf() * TAU) * r.randf_range(260.0, 1400.0)
		rocks.append(Vector3(p.x, p.y, r.randf_range(40.0, 90.0)))
	flow.mark_rocks(rocks)
