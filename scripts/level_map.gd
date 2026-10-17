extends Control
## Mapa de fases do MARÉ ALTA: caminho sinuoso com 10 nós (bloqueado /
## desbloqueado / concluído), total de estrelas, botão Reformar e voltar.

const STAR_ICON := "res://assets/ui/icons/media-generation-icon-estrela-0-f26c7110-ac23-448a-93d7-821c08f3c61b.webp"

var _nodes: Array = []


func _ready() -> void:
	_build_background()
	_build_topbar()
	_build_path()
	_build_buttons()


func _build_background() -> void:
	var grad := GradientTexture2D.new()
	grad.width = 720
	grad.height = 1280
	grad.fill_from = Vector2(0.5, 0.0)
	grad.fill_to = Vector2(0.5, 1.0)
	var g := Gradient.new()
	g.set_color(0, Color(0.15, 0.60, 0.76))
	g.set_color(1, Color(0.96, 0.87, 0.66))
	g.add_point(0.55, Color(0.55, 0.84, 0.87))
	grad.gradient = g
	var bg := TextureRect.new()
	bg.texture = grad
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


func _label(text: String, size: int, pos: Vector2, w: float) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = pos
	l.size = Vector2(w, size * 1.6)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.28, 0.42))
	l.add_theme_constant_override("outline_size", 8)
	add_child(l)
	return l


func _build_topbar() -> void:
	_label("Mapa das Fases", 52, Vector2(0, 30), 720.0)
	var pill := PanelContainer.new()
	pill.position = Vector2(268, 110)
	pill.custom_minimum_size = Vector2(184, 64)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.92)
	sb.set_corner_radius_all(32)
	pill.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := TextureRect.new()
	icon.texture = load(STAR_ICON)
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(icon)
	var lab := Label.new()
	lab.text = str(GameState.stars)
	lab.add_theme_font_size_override("font_size", 36)
	lab.add_theme_color_override("font_color", Color(0.06, 0.28, 0.42))
	hb.add_child(lab)
	pill.add_child(hb)
	add_child(pill)


func _node_pos(i: int) -> Vector2:
	# i: 0..9 (fase i+1). Curva sinuosa de baixo (fase 1) para cima (fase 10).
	var y := 1050.0 - float(i) * 86.0
	var x := 360.0 + 215.0 * sin(float(i) * 0.85)
	return Vector2(x, y)


func _build_path() -> void:
	var line := Line2D.new()
	line.width = 10.0
	line.default_color = Color(1, 1, 1, 0.55)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	for i in 10:
		line.add_point(_node_pos(i))
	add_child(line)


func _circle_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(52)
	sb.border_width_bottom = 6
	sb.border_color = color.darkened(0.25)
	return sb


func _build_buttons() -> void:
	for i in 10:
		var n := i + 1
		var pos := _node_pos(i)
		var b := Button.new()
		b.text = str(n)
		b.custom_minimum_size = Vector2(104, 104)
		b.size = Vector2(104, 104)
		b.position = pos - Vector2(52, 52)
		b.add_theme_font_size_override("font_size", 44)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
		if GameState.level_won_before(n):
			b.add_theme_stylebox_override("normal", _circle_style(Color(1.0, 0.78, 0.15)))
			b.add_theme_stylebox_override("hover", _circle_style(Color(1.0, 0.82, 0.25)))
			b.add_theme_stylebox_override("pressed", _circle_style(Color(0.9, 0.68, 0.1)))
			_add_star_badge(pos)
		elif n <= GameState.unlocked_level:
			b.add_theme_stylebox_override("normal", _circle_style(Color(1.0, 0.55, 0.15)))
			b.add_theme_stylebox_override("hover", _circle_style(Color(1.0, 0.62, 0.25)))
			b.add_theme_stylebox_override("pressed", _circle_style(Color(0.9, 0.48, 0.1)))
			# Nó atual pulsa.
			var tw := create_tween().set_loops()
			tw.tween_property(b, "scale", Vector2(1.1, 1.1), 0.7).set_trans(Tween.TRANS_SINE)
			tw.tween_property(b, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)
			b.pivot_offset = Vector2(52, 52)
		else:
			b.add_theme_stylebox_override("normal", _circle_style(Color(0.55, 0.6, 0.65)))
			b.disabled = true
		if n <= GameState.unlocked_level:
			var lv := n
			b.pressed.connect(func() -> void: _on_level_pressed(lv))
		add_child(b)
		_nodes.append(b)
	# Botão Reformar (chunky, embaixo).
	var ref := Button.new()
	ref.text = "Reformar o quiosque"
	ref.add_theme_font_size_override("font_size", 34)
	ref.add_theme_color_override("font_color", Color.WHITE)
	ref.add_theme_stylebox_override("normal", _rect_style(Color(0.15, 0.65, 0.55)))
	ref.add_theme_stylebox_override("hover", _rect_style(Color(0.18, 0.72, 0.6)))
	ref.add_theme_stylebox_override("pressed", _rect_style(Color(0.12, 0.55, 0.46)))
	ref.position = Vector2(140, 1150)
	ref.size = Vector2(440, 84)
	ref.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/renovation.tscn"))
	add_child(ref)
	# Voltar.
	var back := Button.new()
	back.text = "Início"
	back.add_theme_font_size_override("font_size", 26)
	back.add_theme_color_override("font_color", Color(0.06, 0.28, 0.42))
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(1, 1, 1, 0.85)
	bsb.set_corner_radius_all(20)
	back.add_theme_stylebox_override("normal", bsb)
	back.position = Vector2(24, 1180)
	back.size = Vector2(120, 60)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/start_screen.tscn"))
	add_child(back)


func _rect_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(24)
	sb.border_width_bottom = 6
	sb.border_color = color.darkened(0.25)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	return sb


func _add_star_badge(pos: Vector2) -> void:
	var icon := TextureRect.new()
	icon.texture = load(STAR_ICON)
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = pos + Vector2(28, -72)
	add_child(icon)


func _on_level_pressed(n: int) -> void:
	GameState.current_level = n
	get_tree().change_scene_to_file("res://main.tscn")
