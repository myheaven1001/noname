extends Node2D
## Cảnh chơi demo: 1 người chơi, quân số tăng dần theo thời gian, lên tầng chọn kỹ năng, độ thiên kiếp.
## Mô phỏng chạy trong _physics_process ở 30Hz; hình ảnh nội suy trong _process ở tần số màn hình.
## Phím debug tránh F1–F12 vì trên trình duyệt chúng mở trợ giúp / tải lại trang.

const HELP := "WASD: di chuyển · 1/2/3: chọn kỹ năng\n" \
	+ "8/9/0: 500/1000/2000 quái · 7: tăng dần · +/−: ±100\n" \
	+ "F: đóng băng · G: flow field · H: trạng thái\n" \
	+ "J: bật/tắt AI · K: ẩn số liệu · V: vsync"

var world: World
var player: World.PlayerState
var enemies: EnemyRenderer
var drops: DropRenderer
var fx_ground: FxLayer
var fx_top: FxLayer
var camera: Camera2D
var hud: GameHud
var tint: CanvasModulate
var _sim_ms := 0.0
var _sim_ms_peak := 0.0
var _debug_timer := 0.0


func _ready() -> void:
	Engine.physics_ticks_per_second = World.TICK_RATE
	var db := EnemyDB.load_csv("res://data/enemies.csv")
	world = World.new(db, 12345)
	player = world.add_player(World.ARENA * 0.5)
	world.wave_ramp = true

	tint = CanvasModulate.new()
	add_child(tint)
	fx_ground = FxLayer.new()
	fx_ground.world = world
	add_child(fx_ground)
	drops = DropRenderer.new()
	add_child(drops)
	drops.setup(world)
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

	hud = GameHud.new()
	hud.world = world
	hud.player = player
	hud.show_debug = true
	hud.choose.connect(_choose)
	add_child(hud)


func _physics_process(_delta: float) -> void:
	player.input = Vector2(
		_axis(KEY_D, KEY_RIGHT) - _axis(KEY_A, KEY_LEFT),
		_axis(KEY_S, KEY_DOWN) - _axis(KEY_W, KEY_UP))
	world.step()
	fx_top.on_events(world.events)
	hud.on_events(world.events)
	var ms := world.last_tick_usec / 1000.0
	_sim_ms = lerpf(_sim_ms, ms, 0.1)
	_sim_ms_peak = maxf(_sim_ms_peak, ms)


func _process(delta: float) -> void:
	camera.position = player.prev_pos.lerp(player.pos, Engine.get_physics_interpolation_fraction())
	# Thiên kiếp: trời tối lại, ngả tím.
	var target := Color(0.62, 0.58, 0.8) if player.trib_level > 0 else Color.WHITE
	tint.color = tint.color.lerp(target, minf(delta * 3.0, 1.0))
	_debug_timer -= delta
	if _debug_timer <= 0.0:
		_debug_timer = 0.25
		_update_debug()
		_sim_ms_peak = 0.0


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1, KEY_KP_1:
			_choose(0)
		KEY_2, KEY_KP_2:
			_choose(1)
		KEY_3, KEY_KP_3:
			_choose(2)
		KEY_7:
			world.wave_ramp = true
		KEY_8:
			_fix_population(500)
		KEY_9:
			_fix_population(1000)
		KEY_0:
			_fix_population(2000)
		KEY_EQUAL, KEY_KP_ADD:
			_fix_population(mini(world.target_population + 100, World.MAX_ENEMIES))
		KEY_MINUS, KEY_KP_SUBTRACT:
			_fix_population(maxi(world.target_population - 100, 0))
		KEY_F:
			world.stun_area(player.pos, 350.0, 1.5)
		KEY_G:
			fx_ground.show_flow = not fx_ground.show_flow
		KEY_H:
			fx_top.show_states = not fx_top.show_states
		KEY_J:
			world.ai_enabled = not world.ai_enabled
		KEY_K:
			hud.show_debug = not hud.show_debug
		KEY_V:
			var on := DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED if on else DisplayServer.VSYNC_ENABLED)


## Ở bản mạng đây là gói tin "chọn lựa chọn k" gửi lên server.
func _choose(index: int) -> void:
	Progression.choose(world, player, index)


func _fix_population(n: int) -> void:
	world.wave_ramp = false
	world.target_population = n


func _update_debug() -> void:
	var vsync := DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	hud.debug_text = "FPS %d (vsync %s) · mô phỏng %.2f ms/tick (đỉnh %.2f)\n" % [
			Engine.get_frames_per_second(), "bật" if vsync else "tắt", _sim_ms, _sim_ms_peak] \
		+ "quái %d / %d%s · gồng+lao %d · vật phẩm %d\n" % [
			world.store.count, world.target_population, " (tăng dần)" if world.wave_ramp else "",
			world.attackers, world.drops.count] \
		+ HELP


func _axis(a: Key, b: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b) else 0.0
