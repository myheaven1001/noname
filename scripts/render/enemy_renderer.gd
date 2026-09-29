class_name EnemyRenderer
extends MultiMeshInstance2D
## Vẽ toàn bộ quái bằng một MultiMesh (1 draw call), ghi thẳng vào buffer mỗi frame.
## Vị trí được nội suy giữa 2 tick mô phỏng nên hình mượt ở 60/120fps dù logic chạy 30Hz.
## Texture hiện là hình tròn tạm; khi có sprite sheet thì dùng custom.y làm chỉ số khung hình.

const STRIDE := 16  # 8 float Transform2D + 4 màu + 4 custom (x = nháy trắng, y = khung hình)
const WINDUP_COLOR := Color(1.0, 0.2, 0.15)
const STUN_COLOR := Color(0.55, 0.85, 1.0)
const SHADER := """
shader_type canvas_item;
varying float v_flash;
void vertex() {
	v_flash = INSTANCE_CUSTOM.x;
}
void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), v_flash);
}
"""

var world: World
var last_fill_usec := 0
var _buf := PackedFloat32Array()


func setup(w: World) -> void:
	world = w
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _make_quad()
	mm.instance_count = World.MAX_ENEMIES
	mm.visible_instance_count = 0
	multimesh = mm
	texture = _make_placeholder_texture()
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = SHADER
	material = mat
	_buf.resize(World.MAX_ENEMIES * STRIDE)


func _process(_delta: float) -> void:
	if world == null:
		return
	var t0 := Time.get_ticks_usec()
	var n := fill_buffer(world, Engine.get_physics_interpolation_fraction(), _buf)
	multimesh.buffer = _buf
	multimesh.visible_instance_count = n
	last_fill_usec = Time.get_ticks_usec() - t0


## Ghi n quái vào buf, trả về n. Tách static để đo được ở chế độ headless.
static func fill_buffer(w: World, alpha: float, buf: PackedFloat32Array) -> int:
	var s := w.store
	var db := w.db
	var n := s.count
	var pos := s.pos
	var prev := s.prev_pos
	var type := s.type
	var facing := s.facing
	var state := s.state
	var stun := s.stun
	var flash := s.flash
	var radius := db.radius
	var colors := db.color
	var o := 0
	for i in n:
		var t := type[i]
		var p := prev[i].lerp(pos[i], alpha)
		var size := radius[t] * 2.4
		var c := colors[t]
		if state[i] == EnemyStore.S_WINDUP:
			c = c.lerp(WINDUP_COLOR, 0.7)
		elif stun[i] > 0.0:
			c = c.lerp(STUN_COLOR, 0.6)
		buf[o] = size * facing[i]
		buf[o + 1] = 0.0
		buf[o + 2] = 0.0
		buf[o + 3] = p.x
		buf[o + 4] = 0.0
		buf[o + 5] = size
		buf[o + 6] = 0.0
		buf[o + 7] = p.y
		buf[o + 8] = c.r
		buf[o + 9] = c.g
		buf[o + 10] = c.b
		buf[o + 11] = c.a
		buf[o + 12] = flash[i] * 8.0
		buf[o + 13] = 0.0
		o += STRIDE
	return n


static func _make_quad() -> ArrayMesh:
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


## Hình tròn trắng có viền tối và một "con mắt" lệch phải (để thấy quái quay mặt hướng nào).
static func _make_placeholder_texture() -> ImageTexture:
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
	return ImageTexture.create_from_image(img)
