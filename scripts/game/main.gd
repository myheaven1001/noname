extends Node2D
## Cảnh test: 1 người chơi tự bắn kiếm khí vào quái gần nhất, N quái (dơi, sói yêu, sói tinh anh).
## Mô phỏng chạy trong _physics_process ở 30Hz; hình ảnh nội suy trong _process ở tần số màn hình.

const HELP := "WASD/mũi tên: di chuyển   +/-: ±100 quái   1/2/3: 500/1000/2000 quái\n" \
	+ "F: đóng băng quái quanh người chơi (test huỷ đòn gồng)   F1: flow field   F2: trạng thái   F3: bật/tắt AI   V: vsync"

var world: World
var player: World.PlayerState
var enemies: EnemyRenderer
var fx_ground: FxLayer
var fx_top: FxLayer
var camera: Camera2D
var hud: Label
var _sim_ms := 0.0
var _sim_ms_peak := 0.0
var _hud_timer := 0.0


func _ready() -> void:
	Engine.physics_ticks_per_second = World.TICK_RATE
	var db := EnemyDB.load_csv("res://data/enemies.csv")
	world = World.new(db, 12345)
	player = world.add_player(World.ARENA * 0.5)
	world.target_population = 500

	fx_ground = FxLayer.new()
	fx_ground.world = world
	add_child(fx_ground)
	enemies = EnemyRenderer.new()
	add_child(enemies)
	enemies.setup(world)
	fx_top = FxLayer.new()
	fx_top.top = true
	fx_top.world = world
	add_child(fx_top)

	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(12, 8)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 5)
	layer.add_child(hud)


func _physics_process(_delta: float) -> void:
	player.input = Vector2(
		_axis(KEY_D, KEY_RIGHT) - _axis(KEY_A, KEY_LEFT),
		_axis(KEY_S, KEY_DOWN) - _axis(KEY_W, KEY_UP))
	world.step()
	var ms := world.last_tick_usec / 1000.0
	_sim_ms = lerpf(_sim_ms, ms, 0.1)
	_sim_ms_peak = maxf(_sim_ms_peak, ms)


func _process(delta: float) -> void:
	camera.position = player.prev_pos.lerp(player.pos, Engine.get_physics_interpolation_fraction())
	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.25
		_update_hud()
		_sim_ms_peak = 0.0


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_EQUAL, KEY_KP_ADD:
			world.target_population = mini(world.target_population + 100, World.MAX_ENEMIES)
		KEY_MINUS, KEY_KP_SUBTRACT:
			world.target_population = maxi(world.target_population - 100, 0)
		KEY_1:
			world.target_population = 500
		KEY_2:
			world.target_population = 1000
		KEY_3:
			world.target_population = 2000
		KEY_F:
			world.stun_area(player.pos, 350.0, 1.5)
		KEY_F1:
			fx_ground.show_flow = not fx_ground.show_flow
		KEY_F2:
			fx_top.show_states = not fx_top.show_states
		KEY_F3:
			world.ai_enabled = not world.ai_enabled
		KEY_V:
			var on := DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED if on else DisplayServer.VSYNC_ENABLED)


func _update_hud() -> void:
	var vsync := DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	hud.text = "FPS %d (vsync %s)   frame %.2f ms\n" % [
			Engine.get_frames_per_second(), "bật" if vsync else "tắt",
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0] \
		+ "Mô phỏng 30Hz: %.2f ms/tick (đỉnh %.2f)   buffer MultiMesh: %.2f ms/frame\n" % [
			_sim_ms, _sim_ms_peak, enemies.last_fill_usec / 1000.0] \
		+ "Quái: %d / %d   đang gồng+lao: %d   đã giết: %d   máu: %d   gục: %d\n" % [
			world.store.count, world.target_population, world.attackers, world.kills,
			int(player.hp), player.deaths] \
		+ HELP


func _axis(a: Key, b: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b) else 0.0
