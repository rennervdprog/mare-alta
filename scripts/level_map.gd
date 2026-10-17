extends Control
## Mapa de fases do MARÉ ALTA: arte ilustrada única estilo jogo de tabuleiro
## (caminho de areia em S do quiosque até as falésias) + 10 nós circulares
## sobre o caminho: dourado = concluída, laranja pulsante = atual,
## cinza = bloqueada.

const STAR_ICON := "res://assets/ui/icons/media-generation-icon-estrela-0-f26c7110-ac23-448a-93d7-821c08f3c61b.webp"
const MAP_BG := "res://assets/ui/map/media-generation-mapa-fases-bg-0-a5dea7de-4f1e-44b2-813e-0046519912a3.webp"

const NODE_R := 45.0  # raio dos nós (~90px de diâmetro)
# Posições normalizadas (0-1) sobre o caminho pintado na arte.
const NODE_POS := [
	Vector2(0.60, 0.895),
	Vector2(0.44, 0.84),
	Vector2(0.36, 0.72),
	Vector2(0.42, 0.60),
	Vector2(0.55, 0.52),
	Vector2(0.50, 0.42),
	Vector2(0.42, 0.33),
	Vector2(0.55, 0.26),
	Vector2(0.48, 0.17),
	Vector2(0.54, 0.10),
]

var _nodes: Array = []


func _ready() -> void:
	_build_background()
	_build_topbar()
	_build_nodes()
	_build_buttons()


func _build_background() -> void:
	var bg := TextureRect.new()
	bg.texture = load(MAP_BG)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	# A arte é 1:2 e a tela 9:16: SCALE preenche sem cortar os nós das pontas
	# (leve esticada horizontal, imperceptível na arte pintada).
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
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
	_label("Mapa das Fases", 44, Vector2(0, 20), 720.0)
	# Pílula de estrelas no canto superior direito (nó 10 fica no centro-topo).
	var pill := PanelContainer.new()
	pill.position = Vector2(512, 24)
	pill.custom_minimum_size = Vector2(184, 64)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.92)
	sb.set_corner_radius_all(32)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 4
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
	var n: Vector2 = NODE_POS[i]
	return Vector2(n.x * 720.0, n.y * 1280.0)


func _circle_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(NODE_R))
	# Anel branco de 4px ao redor do nó.
	sb.set_border_width_all(4)
	sb.border_color = Color(1, 1, 1, 0.95)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 6
	return sb


func _build_nodes() -> void:
	for i in 10:
		var n := i + 1
		var pos := _node_pos(i)
		var b := Button.new()
		b.text = str(n)
		b.custom_minimum_size = Vector2(NODE_R * 2, NODE_R * 2)
		b.size = Vector2(NODE_R * 2, NODE_R * 2)
		b.position = pos - Vector2(NODE_R, NODE_R)
		b.add_theme_font_size_override("font_size", 42)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_disabled_color", Color(0.3, 0.33, 0.37))
		b.pivot_offset = Vector2(NODE_R, NODE_R)
		if GameState.level_won_before(n):
			b.add_theme_stylebox_override("normal", _circle_style(Color(1.0, 0.79, 0.24)))
			b.add_theme_stylebox_override("hover", _circle_style(Color(1.0, 0.83, 0.32)))
			b.add_theme_stylebox_override("pressed", _circle_style(Color(0.9, 0.68, 0.16)))
			_add_star_badge(pos)
		elif n <= GameState.unlocked_level:
			b.add_theme_stylebox_override("normal", _circle_style(Color(1.0, 0.48, 0.11)))
			b.add_theme_stylebox_override("hover", _circle_style(Color(1.0, 0.55, 0.2)))
			b.add_theme_stylebox_override("pressed", _circle_style(Color(0.9, 0.42, 0.08)))
			# Nó atual pulsa continuamente.
			var tw := create_tween().set_loops()
			tw.tween_property(b, "scale", Vector2(1.1, 1.1), 0.7).set_trans(Tween.TRANS_SINE)
			tw.tween_property(b, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)
		else:
			b.add_theme_stylebox_override("normal", _circle_style(Color(0.6, 0.65, 0.69)))
			b.modulate = Color(1, 1, 1, 0.78)
			b.disabled = true
		if n <= GameState.unlocked_level:
			var lv := n
			b.pressed.connect(func() -> void: _on_level_pressed(lv))
		else:
			b.pressed.connect(func() -> void: _toast("Complete a fase anterior!"))
		add_child(b)
		_nodes.append(b)


func _build_buttons() -> void:
	# Faixa inferior enxuta: o nó 1 fica logo acima.
	var ref := Button.new()
	ref.text = "Reformar o quiosque"
	ref.add_theme_font_size_override("font_size", 32)
	ref.add_theme_color_override("font_color", Color.WHITE)
	ref.add_theme_stylebox_override("normal", _rect_style(Color(0.15, 0.65, 0.55)))
	ref.add_theme_stylebox_override("hover", _rect_style(Color(0.18, 0.72, 0.6)))
	ref.add_theme_stylebox_override("pressed", _rect_style(Color(0.12, 0.55, 0.46)))
	ref.position = Vector2(150, 1196)
	ref.size = Vector2(420, 68)
	ref.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/renovation.tscn"))
	add_child(ref)
	var back := Button.new()
	back.text = "Início"
	back.add_theme_font_size_override("font_size", 24)
	back.add_theme_color_override("font_color", Color(0.06, 0.28, 0.42))
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(1, 1, 1, 0.85)
	bsb.set_corner_radius_all(20)
	back.add_theme_stylebox_override("normal", bsb)
	back.position = Vector2(24, 1204)
	back.size = Vector2(110, 56)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/start_screen.tscn"))
	add_child(back)


func _rect_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(22)
	sb.border_width_bottom = 5
	sb.border_color = color.darkened(0.25)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	return sb


func _add_star_badge(pos: Vector2) -> void:
	var icon := TextureRect.new()
	icon.texture = load(STAR_ICON)
	icon.custom_minimum_size = Vector2(38, 38)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = pos + Vector2(26, -68)
	add_child(icon)


func _toast(msg: String) -> void:
	var t := Label.new()
	t.text = msg
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Color.WHITE)
	t.add_theme_color_override("font_outline_color", Color(0.06, 0.28, 0.42))
	t.add_theme_constant_override("outline_size", 8)
	t.set_anchors_preset(Control.PRESET_CENTER)
	t.position = Vector2(60, 560)
	t.size = Vector2(600, 60)
	add_child(t)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(t, "modulate:a", 0.0, 0.4)
	tw.tween_callback(t.queue_free)


func _on_level_pressed(n: int) -> void:
	GameState.current_level = n
	get_tree().change_scene_to_file("res://main.tscn")
