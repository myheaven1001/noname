class_name GameHud
extends CanvasLayer
## HUD của người chơi local: cảnh giới, linh khí, máu, linh thạch, thời gian, ba thẻ chọn kỹ năng,
## banner thiên kiếp và thông báo ngắn. Chỉ đọc trạng thái World và sự kiện; lựa chọn kỹ năng đi qua
## tín hiệu `choose` (ở bản mạng sẽ thành gói tin gửi server).

signal choose(index: int)

const INK := Color(0.07, 0.1, 0.08, 0.86)
const LINE := Color(0.2, 0.27, 0.22)
const PAPER := Color(0.91, 0.93, 0.89)
const MUTED := Color(0.6, 0.66, 0.61)
const JADE := Color(0.44, 0.83, 0.69)
const CINNABAR := Color(0.88, 0.33, 0.25)
const HEAVEN := Color(0.86, 0.74, 1.0)
const GOLD := Color(1.0, 0.83, 0.42)

var world: World
var player: World.PlayerState
var show_debug := false
var debug_text := ""

var _realm: Label
var _qi_bar: ProgressBar
var _qi_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _money: Label
var _clock: Label
var _trib: Label
var _toast: Label
var _toast_until := 0.0
var _offer_box: VBoxContainer
var _offer_title: Label
var _cards: Array[Button] = []
var _shown_offer := PackedStringArray()
var _debug: Label


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Góc trên trái: cảnh giới, linh khí, máu, tiền.
	var panel := _panel()
	panel.position = Vector2(12, 12)
	root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	_realm = _label(22, PAPER)
	col.add_child(_realm)
	_qi_bar = _bar(JADE)
	col.add_child(_qi_bar)
	_qi_label = _label(12, MUTED)
	col.add_child(_qi_label)
	_hp_bar = _bar(CINNABAR)
	col.add_child(_hp_bar)
	_hp_label = _label(12, MUTED)
	col.add_child(_hp_label)
	_money = _label(14, GOLD)
	col.add_child(_money)

	# Giữa trên: thời gian + số quái đã giết.
	_clock = _label(16, PAPER)
	_clock.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.position = Vector2(-120, 14)
	_clock.size = Vector2(240, 24)
	root.add_child(_clock)

	# Banner thiên kiếp + thông báo ngắn ở giữa phía trên.
	_trib = _label(24, HEAVEN)
	_trib.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_trib.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trib.position = Vector2(-300, 56)
	_trib.size = Vector2(600, 64)
	root.add_child(_trib)
	_toast = _label(28, GOLD)
	_toast.set_anchors_preset(Control.PRESET_CENTER)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.position = Vector2(-320, -150)
	_toast.size = Vector2(640, 40)
	root.add_child(_toast)

	# Dưới giữa: ba thẻ chọn kỹ năng (không tạm dừng trận).
	_offer_box = VBoxContainer.new()
	_offer_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_offer_box.alignment = BoxContainer.ALIGNMENT_END
	_offer_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_offer_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_offer_box.position = Vector2(-390, -20)
	_offer_box.size = Vector2(780, 0)
	_offer_box.add_theme_constant_override("separation", 6)
	root.add_child(_offer_box)
	_offer_title = _label(14, JADE)
	_offer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_offer_box.add_child(_offer_title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	_offer_box.add_child(row)
	for k in Progression.OFFER_SIZE:
		var b := _card()
		b.pressed.connect(func() -> void: choose.emit(k))
		row.add_child(b)
		_cards.append(b)
	_offer_box.visible = false

	# Góc trên phải: số liệu debug (phím K).
	_debug = _label(11, MUTED)
	_debug.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_debug.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_debug.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_debug.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_debug.offset_left = -400
	_debug.offset_right = -12
	_debug.offset_top = 12
	root.add_child(_debug)


func on_events(events: Array[Dictionary]) -> void:
	for e in events:
		if not e.has(&"player") or e[&"player"] != player.id:
			continue
		match e[&"t"]:
			&"breakthrough":
				_show_toast("Đột phá — " + world.realms.realm_name(e[&"realm"]), 2.5)
			&"trib_start":
				_show_toast("Thiên kiếp giáng xuống!", 2.0)
			&"trib_end":
				if not e[&"success"]:
					_show_toast("Độ kiếp thất bại — tích lại linh khí rồi thử lần nữa", 3.0)


func _process(_delta: float) -> void:
	if world == null:
		return
	var pl := player
	_realm.text = world.realms.title(pl.realm)
	var need := world.realms.qi_to_next(pl.realm)
	if need > 0.0:
		_qi_bar.value = pl.qi / need * 100.0
		_qi_label.text = "Linh khí %d / %d" % [int(pl.qi), int(need)]
		if pl.trib_level == 0 and world.realms.tribulation(pl.realm) > 0:
			_qi_label.text += " · đầy thì độ kiếp"
	else:
		_qi_bar.value = 100.0
		_qi_label.text = "Đỉnh cảnh giới của bản demo"
	_hp_bar.value = pl.hp / pl.max_hp * 100.0
	_hp_label.text = "Máu %d / %d" % [ceili(pl.hp), int(pl.max_hp)]
	_money.text = "Linh thạch %d   ·   Tiên linh thạch %d" % [pl.stones, pl.immortal]
	var secs := int(world.tick * World.DT)
	_clock.text = "%02d:%02d   ·   đã giết %d" % [int(secs / 60.0), secs % 60, world.kills]

	if pl.trib_level > 0:
		var name := "Tiểu thiên kiếp" if pl.trib_level == 1 else "Đại thiên kiếp"
		_trib.text = "%s\nNé các vòng sét — còn %d giây" % [name, ceili(maxf(pl.trib_time, 0.0))]
	else:
		_trib.text = ""
	_toast.visible = _now() < _toast_until

	_update_offer(pl)
	_debug.visible = show_debug
	_debug.text = debug_text


func _update_offer(pl: World.PlayerState) -> void:
	_offer_box.visible = not pl.offer.is_empty()
	if pl.offer == _shown_offer:
		if _offer_box.visible:
			_offer_title.text = _offer_heading(pl)
		return
	_shown_offer = pl.offer.duplicate()
	if pl.offer.is_empty():
		return
	_offer_title.text = _offer_heading(pl)
	for k in _cards.size():
		var b := _cards[k]
		b.visible = k < pl.offer.size()
		if not b.visible:
			continue
		var id := pl.offer[k]
		if id == Progression.FALLBACK_ID:
			b.text = "%d   Linh thạch\n+%d linh thạch." % [k + 1, Progression.FALLBACK_STONES]
			continue
		var lv := int(pl.skills.get(id, 0))
		var row := world.skill_db.level(id, lv + 1)
		var tag := "mới" if lv == 0 else "cấp %d → %d" % [lv, lv + 1]
		var kind := "bị động" if world.skill_db.is_passive(id) else "công pháp"
		b.text = "%d   %s  ·  %s\n%s\n%s" % [k + 1, world.skill_db.display_name(id), tag, row["desc"], kind]


func _offer_heading(pl: World.PlayerState) -> String:
	var text := "Lên tầng — chọn bằng phím 1 / 2 / 3 hoặc bấm vào thẻ"
	if pl.pending_offers > 0:
		text += "   (còn %d lượt chờ)" % pl.pending_offers
	return text


func _show_toast(text: String, seconds: float) -> void:
	_toast.text = text
	_toast_until = _now() + seconds


# --- Dựng widget ------------------------------------------------------------------

func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = INK
	sb.border_color = LINE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(250, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bar(fill: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(226, 8)
	var bg := StyleBoxFlat.new()
	bg.bg_color = LINE
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _card() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(250, 92)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.focus_mode = Control.FOCUS_NONE  # để Space/Enter không bấm nhầm thẻ
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", PAPER)
	b.add_theme_color_override("font_hover_color", PAPER)
	b.add_theme_color_override("font_pressed_color", PAPER)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = INK if state == "normal" else Color(0.1, 0.17, 0.13, 0.95)
		sb.border_color = JADE if state != "normal" else LINE
		sb.set_border_width_all(1 if state == "normal" else 2)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		b.add_theme_stylebox_override(state, sb)
	return b


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
