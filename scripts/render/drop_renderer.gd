class_name DropRenderer
extends MultiMeshInstance2D
## Vẽ vật phẩm rơi bằng một MultiMesh. Chỉ vẽ vật phẩm chung và phần riêng của người chơi local
## (linh thạch của người khác vô hình với mình, đúng như luật co-op).

const STRIDE := 12  # 8 float Transform2D + 4 màu
const QI_SMALL := Color(0.44, 0.83, 0.69)  # ngọc bích
const QI_MID := Color(0.42, 0.72, 1.0)
const QI_BIG := Color(0.74, 0.55, 1.0)
const STONE := Color(0.82, 0.92, 1.0)
const IMMORTAL := Color(1.0, 0.83, 0.42)
const VACUUM := Color(1.0, 0.48, 0.27)

var world: World
var local_player := 0
var _buf := PackedFloat32Array()


func setup(w: World) -> void:
	world = w
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = EnemyRenderer.make_quad()
	mm.instance_count = World.MAX_DROPS
	mm.visible_instance_count = 0
	multimesh = mm
	texture = _make_texture()
	_buf.resize(World.MAX_DROPS * STRIDE)


func _process(_delta: float) -> void:
	if world == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var n := fill_buffer(world, Engine.get_physics_interpolation_fraction(), t, local_player, _buf)
	multimesh.buffer = _buf
	multimesh.visible_instance_count = n


static func fill_buffer(w: World, alpha: float, time: float, local: int, buf: PackedFloat32Array) -> int:
	var d := w.drops
	var pos := d.pos
	var prev := d.prev_pos
	var kind := d.kind
	var value := d.value
	var owner := d.owner
	var uid := d.uid
	var o := 0
	var n := 0
	for i in d.count:
		if owner[i] >= 0 and owner[i] != local:
			continue
		var c: Color
		var size: float
		match kind[i]:
			DropStore.QI:
				if value[i] >= 10.0:
					c = QI_BIG
					size = 15.0
				elif value[i] >= 3.0:
					c = QI_MID
					size = 11.0
				else:
					c = QI_SMALL
					size = 8.0
			DropStore.STONE:
				c = STONE
				size = 13.0
			DropStore.IMMORTAL:
				c = IMMORTAL
				size = 17.0
			_:
				c = VACUUM
				size = 17.0
		# Nhấp nhô nhẹ, lệch pha theo uid để cả đám không nhún cùng nhịp.
		var p := prev[i].lerp(pos[i], alpha) + Vector2(0.0, sin(time * 4.0 + uid[i]) * 2.0)
		buf[o] = size
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
		o += STRIDE
		n += 1
	return n


## Viên đá hình thoi trắng có viền tối và vệt sáng góc trên, tô màu bằng màu instance.
static func _make_texture() -> ImageTexture:
	var size := 24
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := absf(x - c) + absf(y - c)
			if d > c:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d > c - 1.6:
				img.set_pixel(x, y, Color(0.06, 0.08, 0.07))
			else:
				var shine := 1.0 if (x < c and y < c and d < c * 0.55) else 0.82
				img.set_pixel(x, y, Color(shine, shine, shine))
	return ImageTexture.create_from_image(img)
