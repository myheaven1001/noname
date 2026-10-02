extends SceneTree
## Chạy cảnh chơi với màn hình ảo rồi lưu ảnh, để kiểm tra hình mà không cần mở editor.
##   SHOT=shot.png FRAMES=900 xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/screenshot.gd
## Biến môi trường:
##   FRAMES=n     chụp ở frame thứ n (mặc định 900)
##   DEMO=1       người chơi tự chạy vòng và tự chọn kỹ năng chủ động, game tua nhanh x3
##   WHEN=trib    (cùng DEMO) chụp lúc thiên kiếp đang có vòng sét thay vì theo FRAMES
##   STATES=1     bật nhãn trạng thái quái (ĐUỔI / GỒNG / LAO / NGHỈ)

var main: Node
var frames := 0
var trib_frames := 0
var capture_at := int(OS.get_environment("FRAMES")) if OS.has_environment("FRAMES") else 900
var demo := OS.get_environment("DEMO") == "1"
var when := OS.get_environment("WHEN")


func _init() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	if demo:
		Engine.time_scale = 3.0
		Engine.max_physics_steps_per_frame = 8


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and OS.get_environment("STATES") == "1":
		main.fx_top.show_states = true
	if demo:
		_drive()
	var ready := frames >= capture_at
	if when == "trib":
		var w: World = main.world
		trib_frames = trib_frames + 1 if main.player.trib_level > 0 and w.strike_count >= 2 else 0
		ready = trib_frames == 12
	if ready:
		var path := OS.get_environment("SHOT") if OS.has_environment("SHOT") else "user://shot.png"
		root.get_texture().get_image().save_png(path)
		print("đã lưu %s — %s, quái: %d, FPS: %d" % [path, main.world.realms.title(main.player.realm),
			main.world.store.count, Engine.get_frames_per_second()])
		quit()
	return false


## Người chơi tự chạy vòng, gặp lượt chọn thì lấy kỹ năng chủ động đầu tiên.
func _drive() -> void:
	var pl: World.PlayerState = main.player
	var w: World = main.world
	pl.input = Vector2.from_angle(w.tick * 0.012)
	if not pl.offer.is_empty():
		var pick := 0
		for k in pl.offer.size():
			if pl.offer[k] != Progression.FALLBACK_ID and not w.skill_db.is_passive(pl.offer[k]):
				pick = k
				break
		Progression.choose(w, pl, pick)
