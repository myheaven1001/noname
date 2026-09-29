extends SceneTree
## Chạy cảnh test với GPU/màn hình ảo rồi lưu ảnh, để kiểm tra hình mà không cần mở editor.
##   SHOT=shot.png FRAMES=900 xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/screenshot.gd
## Bật sẵn nhãn trạng thái (F2) để thấy ĐUỔI / GỒNG / LAO / NGHỈ.

var main: Node
var frames := 0
var capture_at := int(OS.get_environment("FRAMES")) if OS.has_environment("FRAMES") else 900


func _init() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5:
		main.fx_top.show_states = true
	if frames == capture_at:
		var path := OS.get_environment("SHOT") if OS.has_environment("SHOT") else "user://shot.png"
		root.get_texture().get_image().save_png(path)
		print("đã lưu %s — quái: %d, FPS: %d" % [path, main.world.store.count, Engine.get_frames_per_second()])
		quit()
	return false
