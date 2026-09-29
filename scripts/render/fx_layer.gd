class_name FxLayer
extends Node2D
## Lớp vẽ tạm bằng _draw: đá, vạch cảnh báo, đạn, người chơi và các lớp debug.
## Lớp dưới (top = false) nằm dưới quái; lớp trên (top = true) nằm trên quái.

const STATE_NAMES := ["ĐUỔI", "GỒNG", "LAO", "NGHỈ"]
const PLAYER_COLORS := [Color(0.3, 0.9, 1.0), Color(1.0, 0.85, 0.3), Color(0.5, 1.0, 0.5), Color(1.0, 0.5, 0.9)]
const DEBUG_RADIUS := 320.0

var world: World
var top := false
var show_flow := false
var show_states := false


func _process(_delta: float) -> void:
	queue_redraw()


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


func _draw_top(a: float) -> void:
	for k in world.proj_count:
		var p := world.proj_prev[k].lerp(world.proj_pos[k], a)
		var tail := p - world.proj_vel[k].normalized() * 18.0
		draw_line(tail, p, Color(0.75, 1.0, 1.0), 4.0)
	for pl: World.PlayerState in world.players:
		var p := pl.prev_pos.lerp(pl.pos, a)
		var col: Color = PLAYER_COLORS[pl.id % PLAYER_COLORS.size()]
		if pl.iframes > 0.0 and int(pl.iframes * 20.0) % 2 == 0:
			col.a = 0.35
		draw_circle(p, World.PLAYER_RADIUS, col)
		draw_arc(p, World.PLAYER_RADIUS, 0.0, TAU, 24, Color.BLACK, 2.0)
		var bar := Rect2(p + Vector2(-20, -30), Vector2(40, 5))
		draw_rect(bar, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(bar.position, Vector2(40.0 * pl.hp / World.PLAYER_HP, 5)), Color(0.9, 0.2, 0.2))
	if show_states and not world.players.is_empty():
		_draw_states(a)


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
