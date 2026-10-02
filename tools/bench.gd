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
	print("người chơi | quái | tick TB | tick p99 | tick max | buffer/frame | giết | gồng→lao | huỷ | trúng lao | cảnh giới P1")
	for n_players in [1, 4]:
		for n in [500, 1000, 2000]:
			_run(db, n_players, n)
	_test_cancel(db)
	_test_level_up(db)
	_test_tribulation(db, true)
	_test_tribulation(db, false)
	_test_owned_drops(db)
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
	print("%10d | %4d | %5.2f ms | %6.2f ms | %6.2f ms | %7.2f ms | %4d | %8d | %4d | %9d | %s" % [
		n_players, w.store.count, avg / 1000.0, ticks[int(ticks.size() * 0.99)] / 1000.0,
		ticks[ticks.size() - 1] / 1000.0, fill_usec / 1000.0 / (MEASURE_TICKS * FRAMES_PER_TICK),
		w.kills - kills0, dashes, cancels, dash_hits, w.realms.title(w.players[0].realm)])
	if dashes == 0:
		_fail("sói không lao lần nào")
	if w.kills == kills0:
		_fail("không giết được quái nào")


## Người chơi chạy vòng tròn để quái phải đổi hướng liên tục, có lượt chọn kỹ năng thì chọn ngay.
func _drive(w: World, t: int) -> void:
	for pl in w.players:
		pl.input = Vector2.from_angle(t * 0.02 + pl.id * 1.7)
		if not pl.offer.is_empty():
			Progression.choose(w, pl, t % pl.offer.size())


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
	for pl in w.players:
		if pl.hp <= 0.0 or pl.hp > pl.max_hp + 0.001:
			_fail("máu người chơi %d ngoài khoảng: %.1f / %.1f" % [pl.id, pl.hp, pl.max_hp])
		var need := w.realms.qi_to_next(pl.realm)
		if pl.qi < 0.0 or (need > 0.0 and pl.qi > need):
			_fail("linh khí người chơi %d ngoài khoảng: %.1f / %.1f" % [pl.id, pl.qi, need])
		for id in pl.skills:
			if pl.skills[id] > w.skill_db.max_level(id):
				_fail("kỹ năng %s vượt cấp tối đa" % id)
	for i in w.drops.count:
		if w.drops.value[i] <= 0.0:
			_fail("vật phẩm rơi giá trị không dương")
			return


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


## Đủ linh khí thì lên tầng và có lượt chọn 3 kỹ năng; chọn thì kỹ năng tăng cấp.
func _test_level_up(db: EnemyDB) -> void:
	var w := World.new(db, 3)
	var pl := w.add_player(Vector2(1000, 1000))
	w.target_population = 0
	Progression.add_qi(w, pl, w.realms.qi_to_next(0) + w.realms.qi_to_next(1))
	if pl.realm != 2 or pl.offer.size() != Progression.OFFER_SIZE or pl.pending_offers != 1:
		_fail("lên 2 tầng phải ở tầng 3 với 1 lượt chọn đang mở và 1 lượt chờ (realm=%d, offer=%d, chờ=%d)"
			% [pl.realm, pl.offer.size(), pl.pending_offers])
		return
	var id := pl.offer[0]
	var before := int(pl.skills.get(id, 0))
	Progression.choose(w, pl, 0)
	if int(pl.skills.get(id, 0)) != before + 1 or pl.offer.size() != Progression.OFFER_SIZE or pl.pending_offers != 0:
		_fail("chọn kỹ năng không tăng cấp hoặc không mở lượt chọn tiếp theo")
		return
	print("test lên tầng + chọn kỹ năng: OK")


## Đầy linh khí ở Luyện Khí 9 thì độ kiếp. Sống sót → Trúc Cơ 1 + 1 tiên linh thạch;
## gục → vẫn Luyện Khí 9, còn 70% linh khí, không còn tia sét nào.
func _test_tribulation(db: EnemyDB, survive: bool) -> void:
	var w := World.new(db, 5)
	var pl := w.add_player(Vector2(1000, 1000))
	w.target_population = 0
	var lk9 := 8
	pl.realm = lk9
	Progression.recompute_stats(w, pl)
	if survive:
		pl.max_hp = 100000.0
	pl.hp = pl.max_hp if survive else 1.0
	Progression.add_qi(w, pl, w.realms.qi_to_next(lk9))
	if pl.trib_level != 1:
		_fail("đầy linh khí ở Luyện Khí 9 không bắt đầu thiên kiếp")
		return
	var ended := false
	var success := false
	for t in 30 * 25:
		w.step()
		for e in w.events:
			if e[&"t"] == &"trib_end":
				ended = true
				success = e[&"success"]
		if ended:
			break
	var name := "thành công" if survive else "thất bại"
	if not ended or success != survive:
		_fail("thiên kiếp %s: kết thúc=%s, thành công=%s" % [name, ended, success])
		return
	if survive and (w.realms.title(pl.realm) != "Trúc Cơ tầng 1" or pl.immortal != 1):
		_fail("độ kiếp xong phải lên Trúc Cơ tầng 1 và nhận 1 tiên linh thạch (%s, %d)"
			% [w.realms.title(pl.realm), pl.immortal])
		return
	if not survive and (pl.realm != lk9 or absf(pl.qi - w.realms.qi_to_next(lk9) * Progression.TRIB_FAIL_KEEP) > 0.01
			or w.has_strikes_of(pl.id)):
		_fail("độ kiếp thất bại phải ở lại Luyện Khí 9 với 70% linh khí và không còn tia sét")
		return
	print("test thiên kiếp %s: OK" % name)


## Linh thạch rơi riêng: người chơi khác đứng ngay cạnh cũng không nhặt được phần của người kia.
func _test_owned_drops(db: EnemyDB) -> void:
	var w := World.new(db, 9)
	var a := w.add_player(Vector2(1000, 1000))
	var b := w.add_player(Vector2(1300, 1000))
	w.target_population = 0
	w.spawn_drop(DropStore.STONE, b.pos, 5.0, a.id)
	w.spawn_drop(DropStore.STONE, b.pos, 7.0, b.id)
	w.step()
	if b.stones != 7 or a.stones != 0 or w.drops.count != 1:
		_fail("linh thạch riêng bị nhặt sai (a=%d, b=%d, còn %d)" % [a.stones, b.stones, w.drops.count])
		return
	a.input = Vector2.RIGHT  # a đi về phía vật phẩm của mình
	for t in 90:
		w.step()
	if a.stones != 5 or w.drops.count != 0:
		_fail("phần linh thạch của người chơi a không bay về a (a=%d, còn %d)" % [a.stones, w.drops.count])
		return
	print("test linh thạch rơi riêng: OK")
