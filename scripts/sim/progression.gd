class_name Progression
extends RefCounted
## Linh khí, cảnh giới, lựa chọn kỹ năng khi lên tầng và thiên kiếp. Chạy trên server.
## Lựa chọn kỹ năng không tạm dừng trận (co-op không pause được): người chơi chọn trong lúc vẫn chơi,
## lên nhiều tầng liền thì các lượt chọn xếp hàng trong `pending_offers`.

const OFFER_SIZE := 3
const FALLBACK_ID := "linh_thach"  # khi mọi kỹ năng đã tối đa: lựa chọn nhận linh thạch
const FALLBACK_STONES := 20
const STARTING_SKILL := "kiem_khi"
const BASE_MAGNET := 90.0
const TRIB_FAIL_KEEP := 0.7  # độ kiếp thất bại: giữ lại 70% linh khí của tầng
const TRIB_FIRST_WAVE := 1.5  # giây từ lúc bắt đầu tới đợt sét đầu tiên
## Thông số theo cột `tribulation` của realms.csv: 1 = tiểu thiên kiếp, 2 = đại thiên kiếp.
const TRIB := {
	1: {"duration": 15.0, "interval": 0.9, "per_wave": 2, "dmg": 18.0, "radius": 70.0, "warn": 1.0, "spread": 180.0},
	2: {"duration": 20.0, "interval": 0.6, "per_wave": 3, "dmg": 26.0, "radius": 90.0, "warn": 0.9, "spread": 220.0},
}


static func init_player(w: World, pl: World.PlayerState) -> void:
	pl.realm = 0
	pl.qi = 0.0
	pl.skills = {STARTING_SKILL: 1}
	recompute_stats(w, pl)
	pl.hp = pl.max_hp


## Tính lại chỉ số từ cảnh giới + kỹ năng bị động. Máu tối đa tăng thì máu hiện tại tăng theo.
static func recompute_stats(w: World, pl: World.PlayerState) -> void:
	var old_max := pl.max_hp
	pl.max_hp = World.PLAYER_HP + w.realms.cum_hp[pl.realm] + _passive(w, pl, "kim_cang")
	pl.dmg_mult = 1.0 + w.realms.cum_dmg[pl.realm]
	pl.move_mult = 1.0 + w.realms.cum_move[pl.realm] + _passive(w, pl, "than_phap")
	pl.magnet = BASE_MAGNET + _passive(w, pl, "tu_linh")
	if pl.max_hp > old_max:
		pl.hp += pl.max_hp - old_max


static func add_qi(w: World, pl: World.PlayerState, amount: float) -> void:
	pl.qi += amount
	while true:
		var need := w.realms.qi_to_next(pl.realm)
		if need <= 0.0:
			pl.qi = 0.0  # đỉnh cảnh giới của bản demo
			return
		if pl.qi < need:
			return
		var trib := w.realms.tribulation(pl.realm)
		if trib > 0:
			# Đầy linh khí ở tầng cuối: phải độ kiếp mới đột phá được.
			pl.qi = need
			if pl.trib_level == 0:
				_start_tribulation(w, pl, trib)
			return
		pl.qi -= need
		_advance(w, pl)


## Chọn lựa chọn thứ `index` của lượt hiện tại. Trả false nếu không có lượt chọn hoặc sai chỉ số.
static func choose(w: World, pl: World.PlayerState, index: int) -> bool:
	if index < 0 or index >= pl.offer.size():
		return false
	var id := pl.offer[index]
	if id == FALLBACK_ID:
		pl.stones += FALLBACK_STONES
	else:
		pl.skills[id] = int(pl.skills.get(id, 0)) + 1
		recompute_stats(w, pl)
		if id == "kim_cang":
			pl.hp = pl.max_hp
	w.events.append({&"t": &"skill", &"player": pl.id, &"id": id, &"level": int(pl.skills.get(id, 0))})
	pl.offer = PackedStringArray()
	if pl.pending_offers > 0:
		_make_offer(w, pl)
	return true


static func update_tribulation(w: World, pl: World.PlayerState) -> void:
	if pl.trib_level == 0:
		return
	var cfg: Dictionary = TRIB[pl.trib_level]
	pl.trib_time -= World.DT
	pl.trib_next -= World.DT
	if pl.trib_next <= 0.0 and pl.trib_time > cfg["warn"]:
		pl.trib_next = cfg["interval"]
		for k in int(cfg["per_wave"]):
			# Tia đầu nhắm đúng chỗ người chơi đang đứng → buộc phải di chuyển.
			var p := pl.pos
			if k > 0:
				p += Vector2.from_angle(w.rng.randf() * TAU) * w.rng.randf_range(40.0, cfg["spread"])
			w.add_strike(p, cfg["radius"], cfg["dmg"], cfg["warn"], pl.id)
	if pl.trib_time <= 0.0 and not w.has_strikes_of(pl.id):
		pl.trib_level = 0
		pl.immortal += 1
		w.events.append({&"t": &"trib_end", &"player": pl.id, &"success": true})
		pl.qi -= w.realms.qi_to_next(pl.realm)
		_advance(w, pl)
		w.events.append({&"t": &"breakthrough", &"player": pl.id, &"realm": pl.realm})
		add_qi(w, pl, 0.0)  # linh khí thừa có thể lên tiếp


## Gục trong lúc độ kiếp: thất bại, mất một phần linh khí, phải tích lại rồi độ kiếp lần nữa.
static func fail_tribulation(w: World, pl: World.PlayerState) -> void:
	pl.trib_level = 0
	pl.qi = w.realms.qi_to_next(pl.realm) * TRIB_FAIL_KEEP
	w.clear_strikes_of(pl.id)
	w.events.append({&"t": &"trib_end", &"player": pl.id, &"success": false})


static func _start_tribulation(w: World, pl: World.PlayerState, level: int) -> void:
	var cfg: Dictionary = TRIB[level]
	pl.trib_level = level
	pl.trib_time = cfg["duration"]
	pl.trib_next = TRIB_FIRST_WAVE
	w.events.append({&"t": &"trib_start", &"player": pl.id, &"level": level, &"duration": cfg["duration"]})


static func _advance(w: World, pl: World.PlayerState) -> void:
	pl.realm += 1
	recompute_stats(w, pl)
	pl.pending_offers += 1
	w.events.append({&"t": &"level_up", &"player": pl.id, &"realm": pl.realm})
	if pl.offer.is_empty():
		_make_offer(w, pl)


static func _make_offer(w: World, pl: World.PlayerState) -> void:
	var pool := PackedStringArray()
	for id in w.skill_db.ids:
		if int(pl.skills.get(id, 0)) < w.skill_db.max_level(id):
			pool.append(id)
	# Xáo bằng rng của server → mọi client thấy cùng lựa chọn.
	for k in range(pool.size() - 1, 0, -1):
		var r := w.rng.randi_range(0, k)
		var tmp := pool[k]
		pool[k] = pool[r]
		pool[r] = tmp
	pool = pool.slice(0, OFFER_SIZE)
	if pool.is_empty():
		pool.append(FALLBACK_ID)
	pl.offer = pool
	pl.pending_offers -= 1
	w.events.append({&"t": &"offer", &"player": pl.id, &"choices": pool})


static func _passive(w: World, pl: World.PlayerState, id: String) -> float:
	var lv := int(pl.skills.get(id, 0))
	return float(w.skill_db.level(id, lv)["value"]) if lv > 0 else 0.0
