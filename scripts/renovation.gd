extends Control
## Tela de reforma parametrizada por GameState.current_area (1-5).
## Título/subtítulo, artes before/after, 8 tarefas, intro e capítulo vêm de
## GameState.AREAS. 8 tarefas de 1 estrela cada; sparkle por tarefa concluída;
## ao completar as 8, crossfade para o DEPOIS, diálogo do capítulo `story`
## da área (com retratos) e baú (+100 moedas, claim_chest_area).
## Após o baú da ÁREA 5: tela final ("A história da Marina continua...").
## SEM EMOJI (a fonte do Godot não tem glifos de emoji — só texto).

const STAR_ICON := "res://assets/ui/icons/media-generation-icon-estrela-0-f26c7110-ac23-448a-93d7-821c08f3c61b.webp"
const GIFT_ICON := "res://assets/ui/icons/media-generation-icon-presente-0-9bbdb947-3fc7-4a0a-b2a7-acd94afb67d3.webp"
const PORTRAITS := {
	"Marina": "res://assets/ui/portraits/media-generation-marina-quiosque-do-sol-concept-0-cab930dd-2db3-4673-b393-6a1d7acd78cf.webp",
	"Seu Toninho": "res://assets/ui/portraits/media-generation-seu-toninho-concept-0-e81f7ffe-8ee6-4871-b5fe-007dfcf8a9a5.webp",
	"Bia": "res://assets/ui/portraits/media-generation-bia-concept-0-23b99e65-ec81-4843-a817-759e2d08225b.webp",
	"Seu Waldomiro": "res://assets/ui/portraits/media-generation-seu-waldomiro-concept-0-e2d6a7f3-a77f-41fc-9573-f39f46eeca1f.webp",
	"Cláudio": "res://assets/ui/portraits/media-generation-claudio-concept-0-e4da328c-d12c-4d4a-9017-6613be600fd9.webp",
}

var _area := 1
var _cfg: Dictionary = {}
var _tasks: Array = []
var _story: Array = []

var _art_after: TextureRect
var _stars_label: Label
var _task_rows: Dictionary = {} # task_id -> {button, status}
var _overlay: Control
var _dlg_portrait: TextureRect
var _dlg_name: Label
var _dlg_text: Label
var _dlg_index := 0
var _chest_opened := false
var _finale: Control
var _toast_label: Label
var _toast_tween: Tween


func _ready() -> void:
	_area = clampi(int(GameState.current_area), 1, 5)
	_cfg = GameState.AREAS[_area - 1]
	_tasks = GameState.area_tasks(_area)
	_story = GameState.area_story(_area)
	_build_scene()
	_build_finale()
	_refresh_tasks()
	_refresh_stars()
	if not GameState.area_unlocked(_area):
		_toast("Complete a reforma da área anterior!")
		await get_tree().create_timer(1.2).timeout
		get_tree().change_scene_to_file("res://scenes/level_map.tscn")
		return
	if _all_done():
		_show_after_instant()
		if not _chest_done():
			_show_chest()
		elif _area == 5:
			_show_finale()


func _chest_done() -> bool:
	return bool(GameState.chests_claimed.get(_area, false))


func _build_scene() -> void:
	var before := TextureRect.new()
	before.texture = load(_cfg["before"])
	before.set_anchors_preset(Control.PRESET_FULL_RECT)
	before.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	before.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(before)
	_art_after = TextureRect.new()
	_art_after.texture = load(_cfg["after"])
	_art_after.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art_after.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_after.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art_after.modulate.a = 0.0
	add_child(_art_after)
	# Título da área.
	var title := Label.new()
	title.text = "Área %d — %s" % [int(_cfg["id"]), str(_cfg["name"])]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 36)
	title.size = Vector2(720, 70)
	_style_label(title, 52)
	add_child(title)
	var sub := Label.new()
	sub.text = str(_cfg["subtitle"])
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 104)
	sub.size = Vector2(720, 50)
	_style_label(sub, 32)
	add_child(sub)
	# Pílula de estrelas: canto superior direito, livre do bloco de título.
	var pill := PanelContainer.new()
	pill.position = Vector2(528, 168)
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
	_stars_label = Label.new()
	_stars_label.add_theme_font_size_override("font_size", 36)
	_stars_label.add_theme_color_override("font_color", Color(0.06, 0.28, 0.42))
	hb.add_child(_stars_label)
	pill.add_child(hb)
	add_child(pill)
	# Lista de tarefas (8).
	var list := VBoxContainer.new()
	list.position = Vector2(40, 250)
	list.size = Vector2(640, 700)
	list.add_theme_constant_override("separation", 10)
	add_child(list)
	for t in _tasks:
		list.add_child(_make_task_row(t[0], t[1]))
	# Voltar.
	var back := Button.new()
	back.text = "Mapa"
	back.add_theme_font_size_override("font_size", 26)
	back.add_theme_color_override("font_color", Color(0.06, 0.28, 0.42))
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(1, 1, 1, 0.85)
	bsb.set_corner_radius_all(20)
	back.add_theme_stylebox_override("normal", bsb)
	back.position = Vector2(24, 1180)
	back.size = Vector2(120, 60)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/level_map.tscn"))
	add_child(back)
	# Toast.
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.position = Vector2(60, 990)
	_toast_label.size = Vector2(600, 60)
	_style_label(_toast_label, 30)
	_toast_label.modulate.a = 0.0
	add_child(_toast_label)
	_build_overlay()


func _style_label(l: Label, size: int) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.28, 0.42))
	l.add_theme_constant_override("outline_size", 8)


func _make_task_row(task_id: String, text: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(640, 76)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.94)
	sb.set_corner_radius_all(20)
	sb.border_width_bottom = 5
	sb.border_color = Color(0.06, 0.28, 0.42, 0.25)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 12)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var cost_icon := TextureRect.new()
	cost_icon.texture = load(STAR_ICON)
	cost_icon.custom_minimum_size = Vector2(44, 44)
	cost_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cost_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cost_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(cost_icon)
	var cost := Label.new()
	cost.text = "1"
	cost.add_theme_font_size_override("font_size", 30)
	cost.add_theme_color_override("font_color", Color(0.06, 0.28, 0.42))
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(cost)
	var lab := Label.new()
	lab.text = text
	lab.custom_minimum_size = Vector2(400, 0)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.add_theme_font_size_override("font_size", 26)
	lab.add_theme_color_override("font_color", Color(0.06, 0.28, 0.42))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(lab)
	var status := Label.new()
	status.name = "Status"
	status.text = ""
	status.add_theme_font_size_override("font_size", 38)
	status.add_theme_color_override("font_color", Color(0.15, 0.65, 0.3))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(status)
	b.add_child(hb)
	var tid := task_id
	b.pressed.connect(func() -> void: _on_task_pressed(tid, b))
	_task_rows[task_id] = {"button": b, "status": status}
	return b


func _refresh_stars() -> void:
	_stars_label.text = str(GameState.stars)


func _refresh_tasks() -> void:
	for t in _tasks:
		var task_id: String = t[0]
		var status: Label = _task_rows[task_id]["status"]
		status.text = "✓" if GameState.task_done(task_id) else ""


func _all_done() -> bool:
	for t in _tasks:
		if not GameState.task_done(t[0]):
			return false
	return true


func _on_task_pressed(task_id: String, button: Button) -> void:
	if GameState.task_done(task_id):
		_toast("Tarefa já concluída!")
		return
	if not GameState.spend_star():
		_toast("Vença fases para ganhar estrelas!")
		return
	GameState.complete_task(task_id)
	_refresh_stars()
	_refresh_tasks()
	_sparkle(button.get_global_rect().get_center())
	if _all_done():
		await get_tree().create_timer(0.8).timeout
		_crossfade_to_after()


func _crossfade_to_after() -> void:
	var tw := create_tween()
	tw.tween_property(_art_after, "modulate:a", 1.0, 1.4)
	await tw.finished
	await get_tree().create_timer(0.4).timeout
	_show_story()


func _show_after_instant() -> void:
	_art_after.modulate.a = 1.0


func _sparkle(pos: Vector2) -> void:
	for i in 8:
		var s := TextureRect.new()
		s.texture = load(STAR_ICON)
		s.custom_minimum_size = Vector2(36, 36)
		s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		s.position = pos - Vector2(18, 18)
		add_child(s)
		var ang := TAU * float(i) / 8.0
		var target := pos + Vector2(cos(ang), sin(ang)) * 110.0 - Vector2(18, 18)
		var tw := create_tween().set_parallel()
		tw.tween_property(s, "position", target, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "modulate:a", 0.0, 0.6)
		tw.chain().tween_callback(s.queue_free)


func _toast(msg: String) -> void:
	_toast_label.text = msg
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_label.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_label, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.3)


# ------------------------------------------------------------- overlay: história + baú

func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	# Caixa de diálogo.
	var dlg := PanelContainer.new()
	dlg.position = Vector2(40, 780)
	dlg.size = Vector2(640, 380)
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(1, 1, 1, 0.97)
	dsb.set_corner_radius_all(24)
	dlg.add_theme_stylebox_override("panel", dsb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	_dlg_portrait = TextureRect.new()
	_dlg_portrait.custom_minimum_size = Vector2(200, 200)
	_dlg_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dlg_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(_dlg_portrait)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dlg_name = Label.new()
	_dlg_name.add_theme_font_size_override("font_size", 32)
	_dlg_name.add_theme_color_override("font_color", Color(0.06, 0.28, 0.42))
	vb.add_child(_dlg_name)
	_dlg_text = Label.new()
	_dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dlg_text.custom_minimum_size = Vector2(380, 220)
	_dlg_text.add_theme_font_size_override("font_size", 27)
	_dlg_text.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	vb.add_child(_dlg_text)
	var hint := Label.new()
	hint.text = "toque para continuar"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	vb.add_child(hint)
	hb.add_child(vb)
	dlg.add_child(hb)
	_overlay.add_child(dlg)
	dlg.name = "Dialog"
	# Baú (escondido até o fim do diálogo).
	var chest := VBoxContainer.new()
	chest.name = "Chest"
	chest.position = Vector2(160, 380)
	chest.size = Vector2(400, 520)
	chest.alignment = BoxContainer.ALIGNMENT_CENTER
	chest.visible = false
	var gift := TextureButton.new()
	gift.texture_normal = load(GIFT_ICON)
	gift.custom_minimum_size = Vector2(300, 300)
	gift.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	gift.pressed.connect(_on_chest_opened)
	chest.add_child(gift)
	var clab := Label.new()
	clab.name = "ChestLabel"
	clab.text = "Toque para abrir o baú!"
	clab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(clab, 34)
	chest.add_child(clab)
	_overlay.add_child(chest)
	# Toque para avançar o diálogo.
	var tap := Button.new()
	tap.set_anchors_preset(Control.PRESET_FULL_RECT)
	tap.flat = true
	tap.text = ""
	tap.pressed.connect(_on_overlay_tap)
	_overlay.add_child(tap)
	_overlay.move_child(tap, 1) # atrás do diálogo e do baú, na frente do dim


func _show_story() -> void:
	_dlg_index = 0
	_overlay.visible = true
	_overlay.get_node("Dialog").visible = true
	_overlay.get_node("Chest").visible = false
	_show_story_line()


func _show_story_line() -> void:
	var line: Array = _story[_dlg_index]
	_dlg_name.text = line[0]
	_dlg_text.text = line[1]
	_dlg_portrait.texture = load(PORTRAITS[line[0]])


func _on_overlay_tap() -> void:
	if _overlay.get_node("Dialog").visible:
		_dlg_index += 1
		if _dlg_index >= _story.size():
			_overlay.get_node("Dialog").visible = false
			_show_chest()
		else:
			_show_story_line()


func _show_chest() -> void:
	_chest_opened = false
	_overlay.visible = true
	_overlay.get_node("Dialog").visible = false
	(_overlay.get_node("Chest") as VBoxContainer).visible = true


func _on_chest_opened() -> void:
	if _chest_opened:
		return
	_chest_opened = true
	var chest: VBoxContainer = _overlay.get_node("Chest")
	var gift: TextureButton = chest.get_child(0)
	gift.disabled = true
	# Punch + sparkles.
	var tw := create_tween()
	tw.tween_property(gift, "scale", Vector2(1.25, 1.25), 0.18)
	tw.tween_property(gift, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	_sparkle(gift.get_global_rect().get_center())
	GameState.add_coins(100)
	GameState.claim_chest_area(_area)
	var clab: Label = _overlay.get_node("Chest/ChestLabel")
	clab.text = "+100 moedas!"
	await get_tree().create_timer(1.2).timeout
	if _area == 5:
		_show_finale()
		return
	# Botão voltar ao mapa.
	var back := Button.new()
	back.text = "Voltar ao mapa"
	back.add_theme_font_size_override("font_size", 34)
	back.add_theme_color_override("font_color", Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.55, 0.15)
	sb.set_corner_radius_all(24)
	sb.border_width_bottom = 6
	sb.border_color = Color(0.75, 0.38, 0.08)
	back.add_theme_stylebox_override("normal", sb)
	back.custom_minimum_size = Vector2(360, 84)
	chest.add_child(back)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/level_map.tscn"))


# ------------------------------------------------------------- tela final

func _build_finale() -> void:
	_finale = Control.new()
	_finale.set_anchors_preset(Control.PRESET_FULL_RECT)
	_finale.visible = false
	add_child(_finale)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.2, 0.32, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_finale.add_child(dim)
	var vb := VBoxContainer.new()
	vb.position = Vector2(60, 380)
	vb.size = Vector2(600, 560)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 28)
	_finale.add_child(vb)
	var title := Label.new()
	title.text = "A história da Marina continua..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(title, 56)
	vb.add_child(title)
	var sub := Label.new()
	sub.text = "Aguarde as próximas atualizações!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(sub, 36)
	vb.add_child(sub)
	var back := Button.new()
	back.text = "Voltar ao mapa"
	back.add_theme_font_size_override("font_size", 34)
	back.add_theme_color_override("font_color", Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.55, 0.15)
	sb.set_corner_radius_all(24)
	sb.border_width_bottom = 6
	sb.border_color = Color(0.75, 0.38, 0.08)
	back.add_theme_stylebox_override("normal", sb)
	back.custom_minimum_size = Vector2(360, 84)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/level_map.tscn"))
	vb.add_child(back)


func _show_finale() -> void:
	_overlay.visible = false
	_finale.visible = true
	_sparkle(Vector2(360, 640))
