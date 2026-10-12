class_name EnemyRenderer
extends MultiMeshInstance2D
## Vẽ toàn bộ quái bằng một MultiMesh (1 draw call), ghi thẳng vào buffer mỗi frame.
## Vị trí được nội suy giữa 2 tick mô phỏng nên hình mượt ở 60/120fps dù logic chạy 30Hz.
## Texture là một atlas: các hàng đầu là Sói yêu (sprites/wolf_atlas.png, từ tools/art/wolf_atlas.py),
## hàng cuối là hình tròn tạm của quái chưa có sprite. custom.y/z = cột/hàng của ô cần vẽ.

const STRIDE := 16  # 8 float Transform2D + 4 màu + 4 custom (x = nháy trắng, y = cột, z = hàng, w = lệch y)
const WINDUP_COLOR := Color(1.0, 0.2, 0.15)
const STUN_COLOR := Color(0.55, 0.85, 1.0)
const ATLAS := "res://sprites/wolf_atlas.png"
const CELL := 128
# Phải khớp tools/art/wolf_atlas.py: hàng = hướng vẽ, cột = khung của các hành động nối nhau.
const WOLF_ROWS := 5  # up, upright, right, down, downleft
const COLS := 23
const ROWS := WOLF_ROWS + 1
const PLACEHOLDER_ROW := WOLF_ROWS
const WALK := 0  # 6 khung
const RUN := 6  # 6 khung
const WINDUP := 12  # 3 khung
const CLAW := 15  # 4 khung: 2 gồng + 2 vung vuốt
const RECOVER := 19  # 4 khung
# 8 cung theo EnemyStore.heading (phải, xuống-phải, xuống, xuống-trái, trái, lên-trái, lên, lên-phải)
# → hàng atlas và có lật ngang không (3 hướng phía trái lật từ phía phải).
const SECTOR_ROW := [2, 4, 3, 4, 2, 1, 0, 1]
const SECTOR_FLIP := [1.0, -1.0, 1.0, 1.0, -1.0, -1.0, 1.0, 1.0]
const SHADER := """
shader_type canvas_item;
uniform vec2 cell_uv;
varying float v_flash;
void vertex() {
	v_flash = INSTANCE_CUSTOM.x;
	UV = (INSTANCE_CUSTOM.yz + UV) * cell_uv;
}
void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), v_flash);
}
"""

var world: World
var last_fill_usec := 0
var _buf := PackedFloat32Array()
var _cells_tick := -1


func setup(w: World) -> void:
	world = w
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = make_quad()
	mm.instance_count = World.MAX_ENEMIES
	mm.visible_instance_count = 0
	multimesh = mm
	texture = _make_atlas()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = SHADER
	mat.set_shader_parameter("cell_uv", Vector2(1.0 / COLS, 1.0 / ROWS))
	material = mat
	_buf.resize(World.MAX_ENEMIES * STRIDE)


func _process(_delta: float) -> void:
	if world == null:
		return
	var t0 := Time.get_ticks_usec()
	# Khung hình, hướng, màu chỉ đổi theo tick mô phỏng (30Hz); mỗi frame chỉ cần ghi lại vị trí nội suy.
	if world.tick != _cells_tick:
		_cells_tick = world.tick
		fill_cells(world, _buf)
	var n := fill_positions(world, Engine.get_physics_interpolation_fraction(), _buf)
	multimesh.buffer = _buf
	multimesh.visible_instance_count = n
	last_fill_usec = Time.get_ticks_usec() - t0


## Ghi đủ n quái vào buf, trả về n. Tách static để đo được ở chế độ headless.
static func fill_buffer(w: World, alpha: float, buf: PackedFloat32Array) -> int:
	fill_cells(w, buf)
	return fill_positions(w, alpha, buf)


## Mỗi frame: chỉ ghi vị trí nội suy giữa 2 tick (cộng độ lệch y đã lưu ở custom.w).
static func fill_positions(w: World, alpha: float, buf: PackedFloat32Array) -> int:
	var s := w.store
	var pos := s.pos
	var prev := s.prev_pos
	var n := s.count
	var o := 0
	for i in n:
		var p := prev[i].lerp(pos[i], alpha)
		buf[o + 3] = p.x
		buf[o + 7] = p.y + buf[o + 15]
		o += STRIDE
	return n


## Mỗi tick: ghi mọi thứ trừ vị trí (cỡ, lật, màu, nháy, ô atlas, độ lệch y). Thứ tự quái chỉ đổi giữa
## các tick (xoá bằng swap-remove) nên phần này dùng lại được cho mọi frame trong cùng tick.
static func fill_cells(w: World, buf: PackedFloat32Array) -> void:
	var s := w.store
	var db := w.db
	var n := s.count
	var type := s.type
	var facing := s.facing
	var heading := s.heading
	var anim := s.anim
	var dir := s.dir
	var state := s.state
	var timer := s.timer
	var stun := s.stun
	var flash := s.flash
	var radius := db.radius
	var colors := db.color
	var sprite := db.sprite
	var sprite_size := db.sprite_size
	# Màu gốc và độ lệch chân theo loại quái: tính một lần mỗi frame, không tính lại cho từng con.
	var n_types := db.ids.size()
	var base := PackedColorArray()
	var lift := PackedFloat32Array()
	base.resize(n_types)
	lift.resize(n_types)
	for t in n_types:
		if sprite[t] == EnemyDB.SPRITE_WOLF:
			base[t] = Color.WHITE.lerp(colors[t], db.sprite_tint[t])
			# Chân sprite (lề dưới ô 4/128) đặt dưới tâm va chạm một chút để dáng đứng trên vị trí thật.
			lift[t] = radius[t] * 0.5 + sprite_size[t] * (4.0 / CELL - 0.5)
		else:
			base[t] = colors[t]
	var o := 0
	for i in n:
		var t := type[i]
		var lift_y := 0.0
		var st := state[i]
		var sx: float
		var size: float
		var col := 0.0
		var row := float(PLACEHOLDER_ROW)
		if sprite[t] == EnemyDB.SPRITE_WOLF:
			size = sprite_size[t]
			# Lúc gồng/lao/cào nhìn theo hướng đòn đã khoá, còn lại theo hướng di chuyển.
			var sector := heading[i]
			if st != EnemyStore.S_CHASE and st != EnemyStore.S_RECOVER:
				sector = posmod(roundi(dir[i].angle() / (PI / 4.0)), 8)
			row = SECTOR_ROW[sector]
			sx = size * SECTOR_FLIP[sector]
			match st:
				EnemyStore.S_CHASE:
					col = WALK + int(anim[i]) % 6
				EnemyStore.S_DASH:
					col = RUN + int(anim[i]) % 6
				EnemyStore.S_WINDUP:
					col = WINDUP + _progress_frame(timer[i], db.t_windup[t], 3)
				EnemyStore.S_RECOVER:
					col = RECOVER + _progress_frame(timer[i], db.t_recover[t], 4)
				EnemyStore.S_CLAW_WINDUP:
					col = CLAW + _progress_frame(timer[i], db.t_claw_windup[t], 2)
				EnemyStore.S_CLAW:
					col = CLAW + 2 + _progress_frame(timer[i], db.t_claw_recover[t], 2)
			lift_y = lift[t]
		else:
			size = radius[t] * 2.4
			sx = size * facing[i]
		var c := base[t]
		if st == EnemyStore.S_WINDUP:
			c = c.lerp(WINDUP_COLOR, 0.55)
		elif st == EnemyStore.S_CLAW_WINDUP:
			c = c.lerp(WINDUP_COLOR, 0.3)
		elif stun[i] > 0.0:
			c = c.lerp(STUN_COLOR, 0.6)
		buf[o] = sx
		buf[o + 1] = 0.0
		buf[o + 2] = 0.0
		buf[o + 4] = 0.0
		buf[o + 5] = size
		buf[o + 6] = 0.0
		buf[o + 8] = c.r
		buf[o + 9] = c.g
		buf[o + 10] = c.b
		buf[o + 11] = c.a
		buf[o + 12] = flash[i] * 8.0
		buf[o + 13] = col
		buf[o + 14] = row
		buf[o + 15] = lift_y
		o += STRIDE


## Khung thứ mấy trong n khung, theo phần đã trôi của một trạng thái dài `total` giây còn `left` giây.
static func _progress_frame(left: float, total: float, n: int) -> int:
	if total <= 0.0:
		return 0
	return clampi(int((1.0 - left / total) * n), 0, n - 1)


static func make_quad() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([
		Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Atlas Sói yêu + một hàng cuối chứa hình tròn tạm (ô đầu) cho quái chưa có sprite.
static func _make_atlas() -> ImageTexture:
	var wolf: Image = (load(ATLAS) as Texture2D).get_image()
	wolf.decompress()
	wolf.convert(Image.FORMAT_RGBA8)
	assert(wolf.get_width() == COLS * CELL and wolf.get_height() == WOLF_ROWS * CELL,
		"wolf_atlas.png không khớp bố cục trong EnemyRenderer; chạy lại tools/art/wolf_atlas.py")
	var img := Image.create(COLS * CELL, ROWS * CELL, false, Image.FORMAT_RGBA8)
	img.blit_rect(wolf, Rect2i(Vector2i.ZERO, wolf.get_size()), Vector2i.ZERO)
	var circle := _make_placeholder_image()
	circle.resize(CELL, CELL, Image.INTERPOLATE_BILINEAR)
	img.blit_rect(circle, Rect2i(0, 0, CELL, CELL), Vector2i(0, PLACEHOLDER_ROW * CELL))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Hình tròn trắng có viền tối và một "con mắt" lệch phải (để thấy quái quay mặt hướng nào).
static func _make_placeholder_image() -> Image:
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	var eye := center + Vector2(6.5, -3.0)
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(center)
			if d > 15.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d > 13.5 or p.distance_to(eye) < 2.6:
				img.set_pixel(x, y, Color(0.08, 0.08, 0.1))
			else:
				var shade := 1.0 - 0.25 * clampf((p.y - center.y) / 14.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(shade, shade, shade))
	return img
