class_name FxLayer
extends Node2D
## Lớp vẽ tạm bằng _draw: đá, vạch cảnh báo, vòng thiên lôi, đạn, kiếm, người chơi và các lớp debug.
## Lớp dưới (top = false) nằm dưới quái; lớp trên (top = true) nằm trên quái.
## Hiệu ứng ngắn (sét, lên tầng, đột phá) sinh từ `World.events` qua on_events() — đúng như client mạng
## sẽ làm khi nhận sự kiện từ server.

const STATE_NAMES := ["ĐUỔI", "GỒNG", "LAO", "NGHỈ"]
const PLAYER_COLORS := [Color(0.3, 0.9, 1.0), Color(1.0, 0.85, 0.3), Color(0.5, 1.0, 0.5), Color(1.0, 0.5, 0.9)]
const DEBUG_RADIUS := 320.0
const JADE := Color(0.44, 0.83, 0.69)
const LIGHTNING := Color(0.78, 0.86, 1.0)
const HEAVEN := Color(0.86, 0.74, 1.0)  # thiên lôi: tím nhạt
const GOLD := Color(1.0, 0.83, 0.42)

var world: World
var top := false
var show_flow := false
var show_states := false
var _effects: Array[Dictionary] = []  # {k, pos, r, t0, life, player, seed}


func _process(_delta: float) -> void:
	if not _effects.is_empty():
		var now := _now()
		var alive: Array[Dictionary] = []
		for e in _effects:
			if now - float(e["t0"]) < float(e["life"]):
				alive.append(e)
		_effects = alive
	queue_redraw()


## Nhận sự kiện của tick vừa chạy và tạo hiệu ứng tương ứng (chỉ lớp trên dùng).
func on_events(events: Array[Dictionary]) -> void:
	var now := _now()
	for e in events:
		match e[&"t"]:
			&"lightning":
				_effects.append({"k": "lightning", "pos": e[&"pos"], "r": e[&"radius"], "t0": now, "life": 0.28, "seed": randi()})
			&"strike":
				_effects.append({"k": "strike", "pos": e[&"pos"], "r": e[&"radius"], "t0": now, "life": 0.4, "seed": randi()})
			&"level_up":
				_effects.append({"k": "ring", "player": e[&"player"], "r": 90.0, "t0": now, "life": 0.6, "color": JADE})
			&"breakthrough":
				_effects.append({"k": "ring", "player": e[&"player"], "r": 260.0, "t0": now, "life": 1.3, "color": GOLD})


func _draw() -> void:
	if world == null:
		return
	var a := Engine.get_physics_interpolation_fraction()
	if top:
		_draw_top(a)
	else:
		_draw_ground(a)


func _draw_ground(a: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, World.ARENA), Color(1, 1, 1, 0.3), false, 6.0)
	for rock: Vector3 in world.rocks:
		var c := Vector2(rock.x, rock.y)
		draw_circle(c, rock.z, Color(0.33, 0.34, 0.31))
		draw_arc(c, rock.z, 0.0, TAU, 32, Color(0.18, 0.19, 0.17), 3.0)
	if show_flow:
		_draw_flow()
	# Vạch cảnh báo của quái đang gồng: nền mờ = đường lao, phần đậm = tiến độ gồng.
	var s := world.store
	for i in s.count:
		if s.state[i] != EnemyStore.S_WINDUP:
			continue
		var cfg: Dictionary = world.db.rows[s.type[i]]
		var p := s.prev_pos[i].lerp(s.pos[i], a)
		var end := p + s.dir[i] * float(cfg["dash_dist"])
		var width := world.db.radius[s.type[i]] * 2.0
		var progress := clampf(1.0 - s.timer[i] / float(cfg["windup"]), 0.0, 1.0)
		draw_line(p, end, Color(1.0, 0.15, 0.1, 0.22), width)
		draw_line(p, p.lerp(end, progress), Color(1.0, 0.2, 0.1, 0.5), width)
	# Vòng cảnh báo thiên lôi: viền + đĩa lớn dần tới lúc sét đánh.
	for k in world.strike_count:
		var p := world.strike_pos[k]
		var r := world.strike_radius[k]
		var progress := clampf(1.0 - world.strike_timer[k] / world.strike_warn[k], 0.0, 1.0)
		draw_circle(p, r, Color(HEAVEN, 0.12))
		draw_circle(p, r * progress, Color(HEAVEN, 0.28))
		draw_arc(p, r, 0.0, TAU, 40, Color(HEAVEN, 0.85), 2.5)


func _draw_top(a: float) -> void:
	for k in world.proj_count:
		var p := world.proj_prev[k].lerp(world.proj_pos[k], a)
		var tail := p - world.proj_vel[k].normalized() * 18.0
		draw_line(tail, p, Color(0.75, 1.0, 1.0), 4.0)
	var time := (world.tick - 1 + a) * World.DT
	for pl: World.PlayerState in world.players:
		var p := pl.prev_pos.lerp(pl.pos, a)
		_draw_swords(pl, p, time)
		var col: Color = PLAYER_COLORS[pl.id % PLAYER_COLORS.size()]
		if pl.iframes > 0.0 and int(pl.iframes * 20.0) % 2 == 0:
			col.a = 0.35
		if pl.trib_level > 0:
			draw_arc(p, World.PLAYER_RADIUS + 6.0, 0.0, TAU, 24, Color(HEAVEN, 0.9), 2.0)
		draw_circle(p, World.PLAYER_RADIUS, col)
		draw_arc(p, World.PLAYER_RADIUS, 0.0, TAU, 24, Color.BLACK, 2.0)
		var bar := Rect2(p + Vector2(-20, -30), Vector2(40, 5))
		draw_rect(bar, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(bar.position, Vector2(40.0 * clampf(pl.hp / pl.max_hp, 0.0, 1.0), 5)), Color(0.9, 0.2, 0.2))
	_draw_effects(a)
	if show_states and not world.players.is_empty():
		_draw_states(a)


## Hộ thể kiếm: lưỡi kiếm nằm dọc theo quỹ đạo, vị trí tính bằng đúng hàm server dùng để gây sát thương.
func _draw_swords(pl: World.PlayerState, center: Vector2, time: float) -> void:
	var lv := int(pl.skills.get("ho_the_kiem", 0))
	if lv == 0:
		return
	var row := world.skill_db.level("ho_the_kiem", lv)
	for sp in Skills.sword_positions(center, time, row):
		var tangent := (sp - center).orthogonal().normalized()
		var side := tangent.orthogonal() * 2.5
		var tip := sp + tangent * 13.0
		var hilt := sp - tangent * 9.0
		draw_colored_polygon(PackedVector2Array([tip, sp + side, hilt, sp - side]), Color(0.86, 0.98, 0.95))
		draw_line(hilt + side * 1.6, hilt - side * 1.6, GOLD, 2.0)


func _draw_effects(a: float) -> void:
	var now := _now()
	for e in _effects:
		var t: float = (now - e["t0"]) / e["life"]
		match e["k"]:
			"lightning":
				_draw_bolt(e["pos"], 240.0, e["seed"], Color(LIGHTNING, 1.0 - t), 3.0)
				draw_circle(e["pos"], e["r"] * (0.6 + 0.4 * t), Color(LIGHTNING, 0.35 * (1.0 - t)))
			"strike":
				_draw_bolt(e["pos"], 420.0, e["seed"], Color(HEAVEN, 1.0 - t), 6.0)
				draw_circle(e["pos"], e["r"], Color(1, 1, 1, 0.5 * (1.0 - t)))
				draw_arc(e["pos"], e["r"] * (1.0 + 0.5 * t), 0.0, TAU, 40, Color(HEAVEN, 1.0 - t), 3.0)
			"ring":
				var who: int = e["player"]
				if who < world.players.size():
					var pl := world.players[who]
					var p := pl.prev_pos.lerp(pl.pos, a)
					var col: Color = e["color"]
					draw_arc(p, e["r"] * t, 0.0, TAU, 48, Color(col, 1.0 - t), 4.0)


## Tia sét gấp khúc từ trên trời xuống `target`, hình dạng cố định theo seed của hiệu ứng.
func _draw_bolt(target: Vector2, height: float, seed_value: int, col: Color, width: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pts := PackedVector2Array()
	var segments := 7
	for k in segments + 1:
		var f := float(k) / segments
		var jitter := 0.0 if k == segments else rng.randf_range(-22.0, 22.0)
		pts.append(target + Vector2(jitter, -height * (1.0 - f)))
	draw_polyline(pts, col, width)


func _draw_states(a: float) -> void:
	var s := world.store
	var font := ThemeDB.fallback_font
	var center := world.players[0].pos
	for i in s.count:
		if s.pos[i].distance_squared_to(center) > DEBUG_RADIUS * DEBUG_RADIUS:
			continue
		var p := s.prev_pos[i].lerp(s.pos[i], a)
		var label: String = STATE_NAMES[s.state[i]]
		if s.stun[i] > 0.0:
			label = "CHOÁNG"
		draw_string(font, p + Vector2(-14, -world.db.radius[s.type[i]] - 4), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)


func _draw_flow() -> void:
	if world.players.is_empty():
		return
	var f := world.flow
	var center := world.players[0].pos
	var span := 14
	var cx := int(center.x / f.cell_size)
	var cy := int(center.y / f.cell_size)
	for gy in range(maxi(cy - span, 0), mini(cy + span + 1, f.rows)):
		for gx in range(maxi(cx - span, 0), mini(cx + span + 1, f.cols)):
			var c := Vector2((gx + 0.5) * f.cell_size, (gy + 0.5) * f.cell_size)
			if f.blocked[gy * f.cols + gx] != 0:
				draw_rect(Rect2(c - Vector2(30, 30), Vector2(60, 60)), Color(1, 0, 0, 0.12))
				continue
			var d := f.dir_at(c)
			if d != Vector2.ZERO:
				draw_line(c - d * 12.0, c + d * 12.0, Color(1, 1, 1, 0.35), 2.0)
				draw_circle(c + d * 12.0, 3.0, Color(1, 1, 1, 0.35))


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
