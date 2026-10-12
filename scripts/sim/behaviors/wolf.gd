class_name WolfBehavior
extends RefCounted
## Sói yêu, chỉ chạy trên server. Mọi con đều đuổi và cào; chỉ con biết lao (dash_chance, gieo lúc sinh)
## mới lao, và chỉ khi đã vào gần người chơi:
##   Đuổi → (vào tầm cào)  Gồng cào → Cào → Đuổi
##   Đuổi → (vào tầm lao, con biết lao) Gồng (khoá hướng) → Lao → Nghỉ → Đuổi
## Di chuyển, va chạm, sát thương lao, rơi đồ, hiển thị đều do hệ thống dùng chung lo.
## Hoãn/huỷ khi bị choáng nằm ở World._update_enemies.

## Nửa góc của vùng cào phía trước mặt sói (cos 60° = 0,5 → hình quạt 120°).
const CLAW_CONE_COS := 0.5


static func tick(w: World, i: int) -> void:
	var s := w.store
	var cfg: Dictionary = w.db.rows[s.type[i]]
	match s.state[i]:
		EnemyStore.S_CHASE:
			w.chase(i, w.db.speed[s.type[i]])
			var tgt := s.target[i]
			if tgt < 0:
				return
			var to := w.players[tgt].pos - s.pos[i]
			var dist2 := to.length_squared()
			# Cào: áp sát người chơi (chạm + tầm vươn) thì dừng lại vung vuốt.
			var reach := claw_reach(w, i)
			if dist2 <= reach * reach and s.claw_cd[i] <= 0.0:
				s.state[i] = EnemyStore.S_CLAW_WINDUP
				s.timer[i] = cfg["claw_windup"]
				s.dir[i] = to.normalized()
				s.vel[i] = Vector2.ZERO
				w.emit(&"claw_windup", i, {&"dir": s.dir[i]})
				return
			# Lao: chỉ con biết lao, chỉ khi người chơi đã trong tầm, và không quá số con lao cùng lúc.
			var trigger: float = cfg["dash_trigger"]
			if not s.dasher[i] or s.cd[i] > 0.0 or dist2 > trigger * trigger \
					or w.attackers >= World.MAX_ATTACKERS:
				return
			s.state[i] = EnemyStore.S_WINDUP
			s.timer[i] = cfg["windup"]
			s.dir[i] = to.normalized()  # khoá hướng lúc bắt đầu gồng → người chơi né được
			s.vel[i] = Vector2.ZERO
			w.attackers += 1
			w.emit(&"windup", i, {&"dir": s.dir[i]})  # client hiện vạch cảnh báo + tiếng gầm
		EnemyStore.S_WINDUP:
			s.vel[i] = Vector2.ZERO
			if s.timer[i] <= 0.0:
				var dash_speed: float = cfg["dash_speed"]
				s.state[i] = EnemyStore.S_DASH
				s.timer[i] = cfg["dash_dist"] / dash_speed
				s.hit_mask[i] = 0
				w.emit(&"dash", i, {&"dir": s.dir[i]})
		EnemyStore.S_DASH:
			var v: Vector2 = s.dir[i] * cfg["dash_speed"]
			if s.timer[i] <= 0.0 or w.is_blocked(s.pos[i] + v * World.DT):
				s.state[i] = EnemyStore.S_RECOVER
				s.timer[i] = cfg["recover"]
				s.vel[i] = v * 0.3  # trượt nhẹ rồi dừng
			else:
				s.vel[i] = v
		EnemyStore.S_RECOVER:
			s.vel[i] = s.vel[i].move_toward(Vector2.ZERO, w.db.speed[s.type[i]] * 4.0 * World.DT)
			if s.timer[i] <= 0.0:
				s.state[i] = EnemyStore.S_CHASE
				s.cd[i] = cfg["dash_cooldown"]
		EnemyStore.S_CLAW_WINDUP:
			s.vel[i] = Vector2.ZERO
			if s.timer[i] <= 0.0:
				_claw(w, i, cfg)
				s.state[i] = EnemyStore.S_CLAW
				s.timer[i] = cfg["claw_recover"]
		EnemyStore.S_CLAW:
			s.vel[i] = Vector2.ZERO
			if s.timer[i] <= 0.0:
				s.state[i] = EnemyStore.S_CHASE
				s.claw_cd[i] = cfg["claw_cooldown"]


## Tầm cào tính từ tâm sói tới tâm người chơi.
static func claw_reach(w: World, i: int) -> float:
	var extra: float = w.db.rows[w.store.type[i]]["claw_range"]
	return World.PLAYER_RADIUS + w.db.radius[w.store.type[i]] + extra


## Vung vuốt theo hướng đã khoá lúc gồng: trúng mọi người chơi trong tầm và trong hình quạt phía trước.
## Người chơi lùi ra khỏi tầm hoặc vòng ra sau lưng trong lúc sói gồng thì né được.
static func _claw(w: World, i: int, cfg: Dictionary) -> void:
	var s := w.store
	var reach := claw_reach(w, i)
	w.emit(&"claw", i, {&"dir": s.dir[i]})
	for pl: World.PlayerState in w.players:
		var to := pl.pos - s.pos[i]
		var d2 := to.length_squared()
		if d2 > reach * reach:
			continue
		if d2 > 1.0 and to.normalized().dot(s.dir[i]) < CLAW_CONE_COS:
			continue
		w.hurt_player(pl, cfg["claw_dmg"], false, &"claw")
