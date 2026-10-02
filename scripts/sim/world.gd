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
const HP_PER_MINUTE := 0.25
# Quân số tăng dần khi bật wave_ramp (cảnh chơi); bench và các test đặt target_population cố định.
const WAVE_START := 60
const WAVE_PER_MINUTE := 70.0
const WAVE_MAX := 500

const PLAYER_SPEED := 190.0
const PLAYER_RADIUS := 16.0
const PLAYER_HP := 100.0
const PLAYER_IFRAMES := 0.5

const MAX_PROJ := 512
const PROJ_LIFE := 0.8
const PROJ_RADIUS := 6.0

const MAX_DROPS := 1500
const PICKUP_RADIUS := 22.0
const PULL_SPEED := 250.0
const PULL_ACCEL := 1500.0
const PULL_MAX_SPEED := 1100.0

const MAX_STRIKES := 64
const STRIKE_ENEMY_MULT := 3.0  # thiên lôi đánh quái mạnh gấp 3 lần đánh người


class PlayerState:
	var id := 0
	var pos := Vector2.ZERO
	var prev_pos := Vector2.ZERO
	var input := Vector2.ZERO
	var hp := 0.0
	var iframes := 0.0
	var deaths := 0
	# Tu luyện (xem Progression)
	var realm := 0  # chỉ số dòng trong realms.csv
	var qi := 0.0  # linh khí trong tầng hiện tại
	var max_hp := 0.0
	var dmg_mult := 1.0
	var move_mult := 1.0
	var magnet := 0.0  # bán kính hút vật phẩm
	var stones := 0  # linh thạch
	var immortal := 0  # tiên linh thạch
	var skills := {}  # id kỹ năng -> cấp
	var cd := {}  # id kỹ năng -> hồi chiêu còn lại
	var offer := PackedStringArray()  # lượt chọn kỹ năng đang chờ (rỗng = không có)
	var pending_offers := 0  # số lượt chọn còn xếp hàng sau lượt hiện tại
	var trib_level := 0  # 0 = không độ kiếp; 1/2 = tiểu/đại thiên kiếp đang diễn ra
	var trib_time := 0.0
	var trib_next := 0.0


var db: EnemyDB
var realms: RealmDB
var skill_db: SkillDB
var store: EnemyStore
var drops: DropStore
var grid: SpatialHash
var flow: FlowField
var players: Array[PlayerState] = []
var rocks := PackedVector3Array()  # (x, y, bán kính)
var events: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var tick := 0
var target_population := 500
var wave_ramp := false
var attackers := 0
var kills := 0
var ai_enabled := true
var last_tick_usec := 0
var scratch := PackedInt32Array()  # kết quả của query_enemies (bị ghi đè ở lần gọi sau)

# Đạn kiếm khí của người chơi (SoA, mảng đặc).
var proj_count := 0
var proj_pos := PackedVector2Array()
var proj_prev := PackedVector2Array()
var proj_vel := PackedVector2Array()
var proj_life := PackedFloat32Array()
var proj_dmg := PackedFloat32Array()
var proj_pierce := PackedInt32Array()  # số quái còn xuyên được sau lần trúng tới
var proj_last_hit := PackedInt32Array()  # uid quái vừa trúng, tránh trúng lại cùng con

# Tia thiên lôi đang chờ đánh xuống (SoA, mảng đặc). Client vẽ vòng cảnh báo từ đây.
var strike_count := 0
var strike_pos := PackedVector2Array()
var strike_radius := PackedFloat32Array()
var strike_dmg := PackedFloat32Array()
var strike_timer := PackedFloat32Array()  # giây còn lại tới lúc đánh
var strike_warn := PackedFloat32Array()  # tổng thời gian cảnh báo, để vẽ tiến độ
var strike_owner := PackedInt32Array()  # người chơi đang độ kiếp

var _total_weight := 0.0
var _flow_sources := PackedVector2Array()


func _init(p_db: EnemyDB, seed_value := 1) -> void:
	db = p_db
	realms = RealmDB.load_csv("res://data/realms.csv")
	skill_db = SkillDB.load_csv("res://data/skills.csv")
	rng.seed = seed_value
	store = EnemyStore.new(MAX_ENEMIES)
	drops = DropStore.new(MAX_DROPS)
	grid = SpatialHash.new(ARENA, GRID_CELL, MAX_ENEMIES)
	flow = FlowField.new(ARENA, CELL)
	scratch.resize(256)
	proj_pos.resize(MAX_PROJ)
	proj_prev.resize(MAX_PROJ)
	proj_vel.resize(MAX_PROJ)
	proj_life.resize(MAX_PROJ)
	proj_dmg.resize(MAX_PROJ)
	proj_pierce.resize(MAX_PROJ)
	proj_last_hit.resize(MAX_PROJ)
	strike_pos.resize(MAX_STRIKES)
	strike_radius.resize(MAX_STRIKES)
	strike_dmg.resize(MAX_STRIKES)
	strike_timer.resize(MAX_STRIKES)
	strike_warn.resize(MAX_STRIKES)
	strike_owner.resize(MAX_STRIKES)
	for w in db.spawn_weight:
		_total_weight += w
	_make_rocks()


func add_player(p: Vector2) -> PlayerState:
	var pl := PlayerState.new()
	pl.id = players.size()
	pl.pos = p
	pl.prev_pos = p
	players.append(pl)
	Progression.init_player(self, pl)
	return pl


func step() -> void:
	var t0 := Time.get_ticks_usec()
	tick += 1
	events.clear()
	_save_prev()
	if wave_ramp:
		target_population = mini(WAVE_MAX, WAVE_START + int(WAVE_PER_MINUTE * tick * DT / 60.0))
	_spawn()
	if tick % FLOW_EVERY == 1:
		_rebuild_flow()
	grid.rebuild(store.pos, store.count)  # hợp lệ tới _remove_dead_and_far()
	_update_players()
	_update_strikes()
	_update_enemies()
	_move_enemies()
	_contact_damage()
	_update_projectiles()
	_update_drops()
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
	if s.hp[j] <= 0.0:
		return  # đã chết trong tick này (vd. trúng cả kiếm khí lẫn sét): không rơi đồ hai lần
	s.hp[j] -= dmg
	s.flash[j] = 0.12
	# Siêu giáp khi đang lao: không bị đẩy lùi, cú lao không bị ngắt.
	if s.state[j] != EnemyStore.S_DASH:
		s.knock[j] += from_dir * (KNOCKBACK / db.mass[s.type[j]])
	if s.hp[j] <= 0.0:
		kills += 1
		emit(&"death", j)
		_drop_loot(j)


## Quái gần nhất còn sống trong tầm, -1 nếu không có.
func nearest_enemy(p: Vector2, max_range: float) -> int:
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


## Ghi vào `scratch` chỉ số các quái còn sống chạm hình tròn (center, radius), trả về số lượng.
func query_enemies(center: Vector2, radius: float) -> int:
	var s := store
	var start := grid.cell_start
	var items := grid.items
	var out := scratch
	var cap := out.size()
	var n := 0
	var box := grid.cell_box(center, radius + db.max_radius + GRID_CELL * 0.5)
	for cy in range(box.y, box.w + 1):
		for cx in range(box.x, box.z + 1):
			var c := cy * grid.cols + cx
			for k in range(start[c], start[c + 1]):
				var j := items[k]
				if s.hp[j] <= 0.0:
					continue
				var rr := radius + db.radius[s.type[j]]
				if center.distance_squared_to(s.pos[j]) >= rr * rr:
					continue
				out[n] = j
				n += 1
				if n >= cap:
					return n
	return n


## Bắn một luồng kiếm khí. `pierce` = tổng số quái luồng này trúng được.
func fire(from: Vector2, d: Vector2, spd: float, dmg: float, pierce: int) -> void:
	if proj_count >= MAX_PROJ:
		return
	var k := proj_count
	proj_count += 1
	proj_pos[k] = from
	proj_prev[k] = from
	proj_vel[k] = d * spd
	proj_life[k] = PROJ_LIFE
	proj_dmg[k] = dmg
	proj_pierce[k] = pierce - 1
	proj_last_hit[k] = -1


## Thêm một tia thiên lôi: cảnh báo `warn` giây rồi đánh xuống vùng (pos, radius).
func add_strike(p: Vector2, radius: float, dmg: float, warn: float, owner_id: int) -> void:
	if strike_count >= MAX_STRIKES:
		return
	var k := strike_count
	strike_count += 1
	strike_pos[k] = p
	strike_radius[k] = radius
	strike_dmg[k] = dmg
	strike_timer[k] = warn
	strike_warn[k] = warn
	strike_owner[k] = owner_id
	events.append({&"t": &"strike_warn", &"pos": p, &"radius": radius, &"delay": warn, &"player": owner_id})


func has_strikes_of(owner_id: int) -> bool:
	for k in strike_count:
		if strike_owner[k] == owner_id:
			return true
	return false


func clear_strikes_of(owner_id: int) -> void:
	var k := strike_count - 1
	while k >= 0:
		if strike_owner[k] == owner_id:
			_remove_strike(k)
		k -= 1


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
	var dpos := drops.pos
	var dprev := drops.prev_pos
	for i in drops.count:
		dprev[i] = dpos[i]


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
		var spd := PLAYER_SPEED * pl.move_mult
		pl.pos = _resolve_static(pl.pos + pl.input.limit_length(1.0) * spd * DT, PLAYER_RADIUS)
		Skills.update(self, pl)
		Progression.update_tribulation(self, pl)


## Đếm ngược các tia thiên lôi; tia tới hạn đánh người chơi (tính bất tử) và quái trong vùng.
## Gom tia tới hạn ra trước rồi mới gây sát thương: người chơi gục giữa chừng làm
## fail_tribulation xoá các tia còn lại, không được xoá trong lúc đang duyệt mảng.
func _update_strikes() -> void:
	var due: Array[Vector4] = []  # (x, y, bán kính, sát thương)
	var k := strike_count - 1
	while k >= 0:
		strike_timer[k] -= DT
		if strike_timer[k] <= 0.0:
			due.append(Vector4(strike_pos[k].x, strike_pos[k].y, strike_radius[k], strike_dmg[k]))
			_remove_strike(k)
		k -= 1
	for st in due:
		var p := Vector2(st.x, st.y)
		for pl: PlayerState in players:
			var rr := st.z + PLAYER_RADIUS
			if pl.pos.distance_squared_to(p) < rr * rr:
				_hurt_player(pl, st.w, false)
		var n := query_enemies(p, st.z)
		for q in n:
			var j := scratch[q]
			damage_enemy(j, st.w * STRIKE_ENEMY_MULT, (store.pos[j] - p).normalized())
		events.append({&"t": &"strike", &"pos": p, &"radius": st.z})


func _remove_strike(k: int) -> void:
	strike_count -= 1
	var last := strike_count
	if k == last:
		return
	strike_pos[k] = strike_pos[last]
	strike_radius[k] = strike_radius[last]
	strike_dmg[k] = strike_dmg[last]
	strike_timer[k] = strike_timer[last]
	strike_warn[k] = strike_warn[last]
	strike_owner[k] = strike_owner[last]


func _update_enemies() -> void:
	var s := store
	var n := s.count
	var state := s.state
	var timer := s.timer
	var cd := s.cd
	var stun := s.stun
	var flash := s.flash
	var orbit_cd := s.orbit_cd
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
		if orbit_cd[i] > 0.0:
			orbit_cd[i] -= DT
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
		if pl.trib_level > 0:
			Progression.fail_tribulation(self, pl)
		pl.hp = pl.max_hp  # bản demo: hồi sinh tại chỗ


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
				damage_enemy(j, proj_dmg[k], d)
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
	proj_dmg[k] = proj_dmg[last]
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


## Vật phẩm trong bán kính hút của người chơi bay về phía người đó, chạm thì được nhặt.
func _update_drops() -> void:
	var d := drops
	var pos := d.pos
	var owner := d.owner
	var pulled := d.pulled
	var speed := d.speed
	var i := d.count - 1
	while i >= 0:
		var who := pulled[i]
		if who < 0:
			for pl: PlayerState in players:
				if owner[i] >= 0 and owner[i] != pl.id:
					continue
				if pos[i].distance_squared_to(pl.pos) < pl.magnet * pl.magnet:
					who = pl.id
					pulled[i] = who
					speed[i] = PULL_SPEED
					break
		if who >= 0:
			var pl := players[who]
			var to := pl.pos - pos[i]
			var dist := to.length()
			if dist < PICKUP_RADIUS:
				_collect(pl, i)
				d.remove(i)
			else:
				speed[i] = minf(speed[i] + PULL_ACCEL * DT, PULL_MAX_SPEED)
				pos[i] += to * (minf(speed[i] * DT, dist) / dist)
		i -= 1


func _collect(pl: PlayerState, i: int) -> void:
	var v := drops.value[i]
	match drops.kind[i]:
		DropStore.QI:
			Progression.add_qi(self, pl, v)
		DropStore.STONE:
			pl.stones += int(v)
		DropStore.IMMORTAL:
			pl.immortal += int(v)
		DropStore.VACUUM:
			# Mọi viên linh khí chưa ai hút bay về người nhặt.
			var pulled := drops.pulled
			var speed := drops.speed
			var kind := drops.kind
			for k in drops.count:
				if kind[k] == DropStore.QI and pulled[k] < 0:
					pulled[k] = pl.id
					speed[k] = PULL_SPEED
	events.append({&"t": &"pickup", &"drop": drops.uid[i], &"player": pl.id, &"kind": drops.kind[i], &"value": v})


## Rơi đồ khi quái chết: linh khí chung, linh thạch và tiên linh thạch rơi riêng cho từng người chơi.
func _drop_loot(j: int) -> void:
	var t := store.type[j]
	var p := store.pos[j]
	spawn_drop(DropStore.QI, p, db.qi[t], -1)
	if rng.randf() < db.stone_chance[t]:
		for pl: PlayerState in players:
			spawn_drop(DropStore.STONE, p + Vector2(10, 0), db.stone_count[t], pl.id)
	if rng.randf() < db.immortal_chance[t]:
		for pl: PlayerState in players:
			spawn_drop(DropStore.IMMORTAL, p - Vector2(10, 0), 1.0, pl.id)
	if rng.randf() < db.vacuum_chance[t]:
		spawn_drop(DropStore.VACUUM, p + Vector2(0, 10), 1.0, -1)


## Khi kho vật phẩm đầy, linh khí mới được cộng dồn vào viên linh khí gần chỗ quái chết nhất
## (vẫn nằm nơi người chơi vừa đánh) thay vì mất đi.
func spawn_drop(kind: int, p: Vector2, value: float, owner_id: int) -> void:
	if value <= 0.0:
		return
	var i := drops.spawn(kind, p, value, owner_id)
	if i >= 0:
		events.append({&"t": &"drop", &"drop": drops.uid[i], &"kind": kind, &"pos": p, &"value": value, &"owner": owner_id})
		return
	if kind != DropStore.QI:
		return
	var best := -1
	var best_d2 := INF
	var dpos := drops.pos
	var dkind := drops.kind
	for k in drops.count:
		if dkind[k] != DropStore.QI:
			continue
		var d2 := p.distance_squared_to(dpos[k])
		if d2 < best_d2:
			best_d2 = d2
			best = k
	if best >= 0:
		drops.value[best] += value
		events.append({&"t": &"drop_merge", &"drop": drops.uid[best], &"value": drops.value[best]})


# --- Tiện ích ------------------------------------------------------------------

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
