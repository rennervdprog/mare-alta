extends Control
## Mapa de fases do MARÉ ALTA — 5 abas de área (Praia, Bar, Cozinha, Deck, Palco).
## Cada aba mostra um ScrollContainer vertical com 60 nós em caminho sinuoso
## calculado em código. Fundo = arte `after` da área cobrindo o conteúdo rolável
## (arte pintada tolera a esticada).
## Estados dos nós: dourado = concluída, laranja pulsante = atual,
## cinza = bloqueada. Todos com anel branco.
## Aba bloqueada: cinza; toque mostra toast pedindo a reforma anterior.
## Ao abrir a aba de uma área 2-5 pela primeira vez, mostra o `intro` da área
## (diálogo com retratos) uma única vez.

const STAR_ICON := "res://assets/ui/icons/media-generation-icon-estrela-0-f26c7110-ac23-448a-93d7-821c08f3c61b.webp"
const SHORT_NAMES := ["Praia", "Bar", "Cozinha", "Deck", "Palco"]
const PORTRAITS := {
	"Marina": "res://assets/ui/portraits/media-generation-marina-quiosque-do-sol-concept-0-cab930dd-2db3-4673-b393-6a1d7acd78cf.webp",
	"Seu Toninho": "res://assets/ui/portraits/media-generation-seu-toninho-concept-0-e81f7ffe-8ee6-4871-b5fe-007dfcf8a9a5.webp",
	"Bia": "res://assets/ui/portraits/media-generation-bia-concept-0-23b99e65-ec81-4843-a817-759e2d08225b.webp",
	"Seu Waldomiro": "res://assets/ui/portraits/media-generation-seu-waldomiro-concept-0-e2d6a7f3-a77f-41fc-9573-f39f46eeca1f.webp",
	"Cláudio": "res://assets/ui/portraits/media-generation-claudio-concept-0-e4da328c-d12c-4d4a-9017-6613be600fd9.webp",
}

const NODE_D := 64.0    # diâmetro dos nós
const NODE_GAP := 110.0 # espaçamento vertical entre nós
const CONTENT_H := 6800.0 # altura do conteúdo rolável (60 nós)
const SCROLL_TOP := 176.0
const SCROLL_H := 996.0

var _tab := 1 # aba selecionada (1-5)
var _tab_buttons: Array = []
var _nodes: Array = []
var _scroll: ScrollContainer
var _content: Control
var _stars_label: Label
var _toast_label: Label
var _toast_tween: Tween
# Overlay de intro (áreas 2-5, primeira abertura).
var _intro: Control
var _intro_portrait: TextureRect
var _intro_name: Label
var _intro_text: Label
var _intro_lines: Array = []
var _intro_index := 0


func _ready() -> void:
	_tab = clampi(GameState.area_of_level(GameState.unlocked_level), 1, 5)
	_build_chrome()
	_build_tabs()
	_build_scroll()
	_build_buttons()
	_build_intro_overlay()
	_build_toast()
	_refresh_stars()
	_select_tab(_tab)


func _build_chrome() -> void:
	var sea := ColorRect.new()
	sea.color = Color(0.16, 0.55, 0.72)
	sea.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sea)
	_label("Mapa das Fases", 44, Vector2(0, 16), 720.0)
	# Pílula de estrelas no canto superior direito.
	var pill := PanelContainer.new()
	pill.position = Vector2(512, 20)
	pill.custom_minimum_size = Vector2(184, 60)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.92)
	sb.set_corner_radius_all(30)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 4
	pill.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := TextureRect.new()
	icon.texture = load(STAR_ICON)
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(icon)
	_stars_label = Label.new()
	_stars_label.add_theme_font_size_override("font_size", 34)
	_stars_label.add_theme_color_override("font_color", Color(0.06, 0.28, 0.42))
	hb.add_child(_stars_label)
	pill.add_child(hb)
	add_child(pill)


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


func _build_tabs() -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(8, 92)
	bar.size = Vector2(704, 72)
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	for a in 5:
		var area_id := a + 1
		var b := Button.new()
		b.text = SHORT_NAMES[a]
		b.custom_minimum_size = Vector2(134, 64)
		b.add_theme_font_size_override("font_size", 26)
		b.toggle_mode = true
		var aid := area_id
		b.pressed.connect(func() -> void: _select_tab(aid))
		bar.add_child(b)
		_tab_buttons.append(b)


func _style_tab(b: Button, kind: String) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(18)
	match kind:
		"current":
			sb.bg_color = Color(1.0, 0.55, 0.15)
			sb.border_width_bottom = 5
			sb.border_color = Color(0.75, 0.38, 0.08)
			b.add_theme_color_override("font_color", Color.WHITE)
		"open":
			sb.bg_color = Color(1, 1, 1, 0.92)
			b.add_theme_color_override("font_color", Color(0.06, 0.28, 0.42))
		_: # locked
			sb.bg_color = Color(0.55, 0.6, 0.64, 0.85)
			b.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)


func _refresh_tabs() -> void:
	for a in 5:
		var area_id := a + 1
		var b: Button = _tab_buttons[a]
		b.button_pressed = (area_id == _tab)
		var label_text: String = SHORT_NAMES[a]
		if GameState.area_renovation_done(area_id):
			label_text += " ✓"
		b.text = label_text
		if area_id == _tab:
			_style_tab(b, "current")
		elif GameState.area_unlocked(area_id):
			_style_tab(b, "open")
		else:
			_style_tab(b, "locked")


func _build_scroll() -> void:
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, SCROLL_TOP)
	_scroll.size = Vector2(720, SCROLL_H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_content = Control.new()
	_content.custom_minimum_size = Vector2(720, CONTENT_H)
	_content.size = Vector2(720, CONTENT_H)
	_scroll.add_child(_content)


func _rebuild_content() -> void:
	for ch in _content.get_children():
		ch.queue_free()
	_nodes.clear()
	var area: Dictionary = GameState.AREAS[_tab - 1]
	var start: int = int(area["from"])
	var count: int = int(area["to"]) - start + 1
	# Fundo: arte `after` da área cobrindo todo o conteúdo rolável.
	var bg := TextureRect.new()
	bg.texture = load(area["after"])
	bg.position = Vector2.ZERO
	bg.size = Vector2(720, CONTENT_H)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	_content.add_child(bg)
	for i in count:
		_add_node(start + i, i)
	# Rola até o nó atual.
	var idx := clampi(GameState.unlocked_level - start, 0, count - 1)
	var y := CONTENT_H - 150.0 - idx * NODE_GAP
	_scroll.set_deferred("scroll_vertical", int(clampf(y - SCROLL_H * 0.5, 0, CONTENT_H - SCROLL_H)))


func _node_pos(i: int) -> Vector2:
	var y := CONTENT_H - 150.0 - i * NODE_GAP
	var x := 360.0 + 220.0 * sin(i * 0.55)
	return Vector2(x, y)


func _circle_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(NODE_D / 2.0))
	# Anel branco ao redor do nó.
	sb.set_border_width_all(4)
	sb.border_color = Color(1, 1, 1, 0.95)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 6
	return sb


func _add_node(n: int, i: int) -> void:
	var pos := _node_pos(i)
	var b := Button.new()
	b.text = str(n)
	b.custom_minimum_size = Vector2(NODE_D, NODE_D)
	b.size = Vector2(NODE_D, NODE_D)
	b.position = pos - Vector2(NODE_D / 2.0, NODE_D / 2.0)
	b.add_theme_font_size_override("font_size", 34)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.92, 0.94, 0.96))
	b.pivot_offset = Vector2(NODE_D / 2.0, NODE_D / 2.0)
	if GameState.level_won_before(n):
		b.add_theme_stylebox_override("normal", _circle_style(Color(1.0, 0.79, 0.24)))
		b.add_theme_stylebox_override("hover", _circle_style(Color(1.0, 0.83, 0.32)))
		b.add_theme_stylebox_override("pressed", _circle_style(Color(0.9, 0.68, 0.16)))
		_add_star_badge(pos)
	elif n <= GameState.unlocked_level:
		b.add_theme_stylebox_override("normal", _circle_style(Color(1.0, 0.48, 0.11)))
		b.add_theme_stylebox_override("hover", _circle_style(Color(1.0, 0.55, 0.2)))
		b.add_theme_stylebox_override("pressed", _circle_style(Color(0.9, 0.42, 0.08)))
		if n == GameState.unlocked_level:
			# Nó atual pulsa continuamente. O tween é do próprio botão para
			# morrer com ele na troca de aba (tween infinito no mapa ficaria
			# mirando um botão já liberado -> "Infinite loop detected").
			var tw := b.create_tween().set_loops()
			tw.tween_property(b, "scale", Vector2(1.1, 1.1), 0.7).set_trans(Tween.TRANS_SINE)
			tw.tween_property(b, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)
	else:
		b.add_theme_stylebox_override("normal", _circle_style(Color(0.6, 0.65, 0.69)))
		b.modulate = Color(1, 1, 1, 0.78)
		b.disabled = true
	if n <= GameState.unlocked_level:
		var lv := n
		b.pressed.connect(func() -> void: _on_level_pressed(lv))
	_content.add_child(b)
	_nodes.append(b)


func _add_star_badge(pos: Vector2) -> void:
	var icon := TextureRect.new()
	icon.texture = load(STAR_ICON)
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = pos + Vector2(20, -54)
	_content.add_child(icon)


func _build_buttons() -> void:
	var ref := Button.new()
	ref.text = "Reformar o quiosque"
	ref.add_theme_font_size_override("font_size", 32)
	ref.add_theme_color_override("font_color", Color.WHITE)
	ref.add_theme_stylebox_override("normal", _rect_style(Color(0.15, 0.65, 0.55)))
	ref.add_theme_stylebox_override("hover", _rect_style(Color(0.18, 0.72, 0.6)))
	ref.add_theme_stylebox_override("pressed", _rect_style(Color(0.12, 0.55, 0.46)))
	ref.position = Vector2(150, 1196)
	ref.size = Vector2(420, 68)
	ref.pressed.connect(_on_reform_pressed)
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


func _refresh_stars() -> void:
	_stars_label.text = str(GameState.stars)


func _build_toast() -> void:
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.position = Vector2(60, 560)
	_toast_label.size = Vector2(600, 120)
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.add_theme_font_size_override("font_size", 30)
	_toast_label.add_theme_color_override("font_color", Color.WHITE)
	_toast_label.add_theme_color_override("font_outline_color", Color(0.06, 0.28, 0.42))
	_toast_label.add_theme_constant_override("outline_size", 8)
	_toast_label.modulate.a = 0.0
	add_child(_toast_label)


func _toast(msg: String) -> void:
	_toast_label.text = msg
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_label.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_label, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.3)


# ------------------------------------------------------------- troca de aba

func _select_tab(a: int) -> void:
	if not GameState.area_unlocked(a):
		_toast("Complete a reforma da área anterior!")
		_refresh_tabs()
		return
	_tab = a
	_refresh_tabs()
	_rebuild_content()
	if a >= 2 and not GameState.intro_seen(a):
		_show_intro(a)


func _on_reform_pressed() -> void:
	if not GameState.area_unlocked(_tab):
		_toast("Complete a reforma da área anterior!")
		return
	GameState.current_area = _tab
	get_tree().change_scene_to_file("res://scenes/renovation.tscn")


func _on_level_pressed(n: int) -> void:
	GameState.current_level = n
	get_tree().change_scene_to_file("res://main.tscn")


# ------------------------------------------------------------- intro da área

func _build_intro_overlay() -> void:
	_intro = Control.new()
	_intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro.visible = false
	add_child(_intro)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro.add_child(dim)
	var dlg := PanelContainer.new()
	dlg.name = "Dialog"
	dlg.position = Vector2(40, 780)
	dlg.size = Vector2(640, 380)
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(1, 1, 1, 0.97)
	dsb.set_corner_radius_all(24)
	dlg.add_theme_stylebox_override("panel", dsb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	_intro_portrait = TextureRect.new()
	_intro_portrait.custom_minimum_size = Vector2(200, 200)
	_intro_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_intro_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(_intro_portrait)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_intro_name = Label.new()
	_intro_name.add_theme_font_size_override("font_size", 32)
	_intro_name.add_theme_color_override("font_color", Color(0.06, 0.28, 0.42))
	vb.add_child(_intro_name)
	_intro_text = Label.new()
	_intro_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro_text.custom_minimum_size = Vector2(380, 220)
	_intro_text.add_theme_font_size_override("font_size", 27)
	_intro_text.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	vb.add_child(_intro_text)
	var hint := Label.new()
	hint.text = "toque para continuar"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	vb.add_child(hint)
	hb.add_child(vb)
	dlg.add_child(hb)
	_intro.add_child(dlg)
	var tap := Button.new()
	tap.set_anchors_preset(Control.PRESET_FULL_RECT)
	tap.flat = true
	tap.text = ""
	tap.pressed.connect(_on_intro_tap)
	_intro.add_child(tap)
	_intro.move_child(tap, 1) # atrás do diálogo, na frente do dim


func _show_intro(a: int) -> void:
	_intro_lines = GameState.area_intro(a)
	if _intro_lines.is_empty():
		GameState.mark_intro_seen(a)
		return
	_intro_index = 0
	_intro.visible = true
	_show_intro_line()


func _show_intro_line() -> void:
	var line: Array = _intro_lines[_intro_index]
	_intro_name.text = line[0]
	_intro_text.text = line[1]
	_intro_portrait.texture = load(PORTRAITS[line[0]])


func _on_intro_tap() -> void:
	_intro_index += 1
	if _intro_index >= _intro_lines.size():
		_intro.visible = false
		GameState.mark_intro_seen(_tab)
	else:
		_show_intro_line()
