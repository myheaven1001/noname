class_name WolfBehavior
extends RefCounted
## Sói yêu: Đuổi → Gồng (khoá hướng) → Lao → Nghỉ. Chỉ chạy trên server.
## Di chuyển, va chạm, sát thương, rơi đồ, hiển thị đều do hệ thống dùng chung lo.
## Hoãn/huỷ khi bị choáng nằm ở World._update_enemies (dùng chung cho mọi đòn có gồng).


static func tick(w: World, i: int) -> void:
	var s := w.store
	var cfg: Dictionary = w.db.rows[s.type[i]]
	match s.state[i]:
		EnemyStore.S_CHASE:
			w.chase(i, w.db.speed[s.type[i]])
			var tgt := s.target[i]
			if tgt < 0 or s.cd[i] > 0.0 or w.attackers >= World.MAX_ATTACKERS:
				return
			var to := w.players[tgt].pos - s.pos[i]
			var trigger: float = cfg["dash_trigger"]
			if to.length_squared() > trigger * trigger:
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
