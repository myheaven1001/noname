extends SceneTree
## Đo chi phí mô phỏng + ghi buffer MultiMesh, không cần GPU, và kiểm tra các bất biến cơ bản.
##   godot --headless --path . -s res://tools/bench.gd
## Ngân sách: 120fps = 8,33 ms/frame. Tick mô phỏng chạy mỗi 4 frame nên cần nhỏ hơn nhiều so với 8 ms.

const WARMUP_TICKS := 150
const MEASURE_TICKS := 600  # 20 giây trong game
const FRAMES_PER_TICK := 4  # 120fps / 30Hz

var _failed := false


func _init() -> void:
	var db := EnemyDB.load_csv("res://data/enemies.csv")
	print("người chơi | quái | tick TB | tick p99 | tick max | buffer/frame | giết | gồng→lao | huỷ | trúng lao")
	for n_players in [1, 4]:
		for n in [500, 1000, 2000]:
			_run(db, n_players, n)
	_test_cancel(db)
	print("KẾT QUẢ: ", "LỖI" if _failed else "OK")
	quit(1 if _failed else 0)


func _run(db: EnemyDB, n_players: int, population: int) -> void:
	var w := World.new(db, 42)
	for k in n_players:
		w.add_player(World.ARENA * 0.5 + Vector2(k * 80.0, 0.0))
	w.target_population = population
	var buf := PackedFloat32Array()
	buf.resize(World.MAX_ENEMIES * EnemyRenderer.STRIDE)
	for t in WARMUP_TICKS:
		_drive(w, t)
		w.step()
	var ticks := PackedInt64Array()
	var fill_usec := 0
	var dashes := 0
	var cancels := 0
	var dash_hits := 0
	var kills0 := w.kills
	for t in MEASURE_TICKS:
		_drive(w, WARMUP_TICKS + t)
		w.step()
		ticks.append(w.last_tick_usec)
		for e in w.events:
			match e[&"t"]:
				&"dash":
					dashes += 1
				&"attack_cancel":
					cancels += 1
				&"player_hit":
					if e[&"dmg"] >= 12.0:
						dash_hits += 1
		var f0 := Time.get_ticks_usec()
		for f in FRAMES_PER_TICK:
			EnemyRenderer.fill_buffer(w, float(f) / FRAMES_PER_TICK, buf)
		fill_usec += Time.get_ticks_usec() - f0
	_check_invariants(w)
	ticks.sort()
	var avg := 0.0
	for v in ticks:
		avg += v
	avg /= ticks.size()
	print("%10d | %4d | %5.2f ms | %6.2f ms | %6.2f ms | %7.2f ms | %4d | %8d | %4d | %d" % [
		n_players, w.store.count, avg / 1000.0, ticks[int(ticks.size() * 0.99)] / 1000.0,
		ticks[ticks.size() - 1] / 1000.0, fill_usec / 1000.0 / (MEASURE_TICKS * FRAMES_PER_TICK),
		w.kills - kills0, dashes, cancels, dash_hits])
	if dashes == 0:
		_fail("sói không lao lần nào")
	if w.kills == kills0:
		_fail("không giết được quái nào")


## Người chơi chạy vòng tròn để quái phải đổi hướng liên tục.
func _drive(w: World, t: int) -> void:
	for pl in w.players:
		pl.input = Vector2.from_angle(t * 0.02 + pl.id * 1.7)


func _check_invariants(w: World) -> void:
	var s := w.store
	var seen := {}
	for i in s.count:
		var p := s.pos[i]
		if is_nan(p.x) or is_nan(p.y):
			_fail("vị trí NaN tại quái %d" % i)
			return
		if p.x < 0.0 or p.y < 0.0 or p.x > World.ARENA.x or p.y > World.ARENA.y:
			_fail("quái %d ra ngoài đấu trường: %s" % [i, p])
			return
		if seen.has(s.uid[i]):
			_fail("uid trùng: %d" % s.uid[i])
			return
		seen[s.uid[i]] = true
		if s.hp[i] <= 0.0:
			_fail("quái chết chưa bị xoá: %d" % i)
			return
	if w.attackers > World.MAX_ATTACKERS:
		_fail("quá nhiều quái gồng/lao cùng lúc: %d" % w.attackers)


## Một con sói đang gồng bị đóng băng phải huỷ đòn và phát sự kiện attack_cancel.
func _test_cancel(db: EnemyDB) -> void:
	var w := World.new(db, 1)
	var pl := w.add_player(Vector2(1000, 1000))
	w.target_population = 1  # chỉ có đúng con sói này, bộ spawn không thêm con nào
	var wolf := db.type_of("wolf")
	var i := w.store.spawn(wolf, pl.pos + Vector2(150, 0), 1000.0)
	var uid := w.store.uid[i]
	var got_windup := false
	for t in 60:
		w.step()
		if w.store.state[0] == EnemyStore.S_WINDUP:
			got_windup = true
			break
	if not got_windup:
		_fail("sói không vào trạng thái gồng khi người chơi ở gần")
		return
	w.stun_area(pl.pos, 500.0, 1.0)
	w.step()
	var cancelled := false
	for e in w.events:
		if e[&"t"] == &"attack_cancel" and e[&"uid"] == uid:
			cancelled = true
	if not cancelled or w.store.state[0] != EnemyStore.S_CHASE:
		_fail("đóng băng không huỷ được đòn gồng")
	else:
		print("test huỷ đòn khi bị đóng băng: OK")


func _fail(msg: String) -> void:
	_failed = true
	printerr("LỖI: ", msg)
