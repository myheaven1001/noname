extends SceneTree
## Giả lập một trận để cân bằng nhịp lên tầng (không cần GPU):
##   godot --headless --path . -s res://tools/simulate.gd
## Quân số tăng dần như cảnh chơi; người chơi chạy vòng và ưu tiên chọn kỹ năng chủ động.
## In ra mốc lên tầng, thiên kiếp và tổng kết mỗi phút. Đổi MINUTES / SEED bằng biến môi trường.

func _init() -> void:
	var minutes := int(OS.get_environment("MINUTES")) if OS.has_environment("MINUTES") else 6
	var seed_value := int(OS.get_environment("SEED")) if OS.has_environment("SEED") else 77
	var db := EnemyDB.load_csv("res://data/enemies.csv")
	var w := World.new(db, seed_value)
	var pl := w.add_player(World.ARENA * 0.5)
	w.wave_ramp = true
	var last_realm := -1
	for t in World.TICK_RATE * 60 * minutes:
		pl.input = Vector2.from_angle(t * 0.012)
		if not pl.offer.is_empty():
			Progression.choose(w, pl, _pick(w, pl))
		w.step()
		var secs := t * World.DT
		for e in w.events:
			if e.get(&"player", -1) != pl.id:
				continue
			match e[&"t"]:
				&"trib_start":
					print("%6.1fs  bắt đầu thiên kiếp" % secs)
				&"trib_end":
					print("%6.1fs  thiên kiếp %s" % [secs, "thành công" if e[&"success"] else "thất bại"])
		if pl.realm != last_realm:
			last_realm = pl.realm
			print("%6.1fs  %s  (quái %d, giết %d, gục %d, kỹ năng %s)"
				% [secs, w.realms.title(pl.realm), w.store.count, w.kills, pl.deaths, pl.skills])
		if t % (World.TICK_RATE * 60) == 0:
			print("%6.1fs  -- quái %d, giết %d, máu %d/%d, linh thạch %d, tiên linh thạch %d, vật phẩm %d"
				% [secs, w.store.count, w.kills, pl.hp, pl.max_hp, pl.stones, pl.immortal, w.drops.count])
	quit()


## Ưu tiên kỹ năng chủ động, không có thì lấy lựa chọn đầu.
func _pick(w: World, pl: World.PlayerState) -> int:
	for k in pl.offer.size():
		if pl.offer[k] != Progression.FALLBACK_ID and not w.skill_db.is_passive(pl.offer[k]):
			return k
	return 0
