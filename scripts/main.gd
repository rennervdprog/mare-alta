extends Node2D
## MARÉ ALTA — Fase 1: núcleo match-3 jogável.
## Retrato 720x1280. Controles: toque na peça + toque na vizinha, ou arrastar.

const CELL := 76.0
const BOARD_PX := 608.0
const BOARD_X := 56.0
const BOARD_Y := 300.0
const PIECE_TARGET := 64.0

const T_COCO := 0
const T_CONCHA := 4

const GOAL_COCO := 20
const GOAL_CONCHA := 20
const START_MOVES := 20

const TEX_PATHS: Array[String] = [
	"res://assets/pecas/media-generation-peca-coco-0-4c8ee45f-8fe4-4ba7-a157-87abc63074d9.webp",
	"res://assets/pecas/media-generation-peca-guarda-sol-0-cc42fc82-43d4-4a76-ad42-435b3b62f08b.webp",
	"res://assets/pecas/media-generation-peca-chinelo-0-3d35c8f8-fa6f-4094-9002-013d606c627a.webp",
	"res://assets/pecas/media-generation-peca-peixe-0-b89b476d-f69a-4497-8be5-b2fedd17eeb2.webp",
	"res://assets/pecas/media-generation-peca-concha-0-ff58d4b9-bb14-4907-946b-5e8ae9ff218d.webp",
]

var logic: BoardLogic
var tex: Array = []
var board_node: Node2D
var pieces: Array = [] # pieces[linha][coluna] -> Sprite2D
var selected := Vector2i(-1, -1)
var press_cell := Vector2i(-1, -1)
var busy := false
var game_over := false
var moves := START_MOVES
var coco_count := 0
var concha_count := 0

var moves_label: Label
var coco_label: Label
var concha_label: Label
var toast_label: Label
var select_frame: Panel
var overlay: CanvasLayer
var overlay_title: Label
var overlay_sub: Label
var overlay_star_holder: Control
var overlay_button: Button


func _ready() -> void:
	for p in TEX_PATHS:
		tex.append(load(p))
	_build_background()
	_build_hud()
	_build_board()
	_build_overlay()
	logic = BoardLogic.new()
	_rebuild_pieces()
	_update_goal_labels()
	_update_moves_label()


# ---------------------------------------------------------------- construção

func _build_background() -> void:
	var grad := GradientTexture2D.new()
	grad.width = 720
	grad.height = 1280
	grad.fill_from = Vector2(0.5, 0.0)
	grad.fill_to = Vector2(0.5, 1.0)
	var g := Gradient.new()
	g.set_color(0, Color(0.15, 0.60, 0.76)) # mar
	g.set_color(1, Color(0.96, 0.87, 0.66)) # areia
	g.add_point(0.55, Color(0.55, 0.84, 0.87))
	grad.gradient = g
	var bg := Sprite2D.new()
	bg.texture = grad
	bg.position = Vector2(360, 640)
	add_child(bg)


func _make_label(text: String, font_size: int, pos: Vector2, size: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = pos
	l.size = size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.28, 0.42))
	l.add_theme_constant_override("outline_size", 8)
	add_child(l)
	return l


func _make_goal_row(tex_idx: int) -> Label:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	var icon := TextureRect.new()
	icon.texture = tex[tex_idx]
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(icon)
	var lab := Label.new()
	lab.text = "0/20"
	lab.add_theme_font_size_override("font_size", 40)
	lab.add_theme_color_override("font_color", Color.WHITE)
	lab.add_theme_color_override("font_outline_color", Color(0.06, 0.28, 0.42))
	lab.add_theme_constant_override("outline_size", 8)
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(lab)
	_goals_box.add_child(hb)
	return lab


var _goals_box: HBoxContainer


func _build_hud() -> void:
	_make_label("MARÉ ALTA", 60, Vector2(0, 24), Vector2(720, 84))
	_goals_box = HBoxContainer.new()
	_goals_box.position = Vector2(0, 118)
	_goals_box.size = Vector2(720, 64)
	_goals_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_goals_box.add_theme_constant_override("separation", 64)
	add_child(_goals_box)
	coco_label = _make_goal_row(T_COCO)
	concha_label = _make_goal_row(T_CONCHA)
	moves_label = _make_label("Movimentos: 20", 40, Vector2(0, 196), Vector2(720, 56))
	_make_label("Toque em 2 peças vizinhas ou arraste para trocar", 24, Vector2(0, 1196), Vector2(720, 40))
	toast_label = _make_label("", 34, Vector2(0, 936), Vector2(720, 60))
	toast_label.modulate.a = 0.0


func _build_board() -> void:
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.22)
	sb.set_corner_radius_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(BOARD_X - 12, BOARD_Y - 12)
	panel.size = Vector2(BOARD_PX + 24, BOARD_PX + 24)
	add_child(panel)
	board_node = Node2D.new()
	board_node.position = Vector2(BOARD_X, BOARD_Y)
	add_child(board_node)
	select_frame = Panel.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(1, 1, 1, 0.0)
	fsb.set_corner_radius_all(16)
	fsb.set_border_width_all(5)
	fsb.border_color = Color.WHITE
	select_frame.add_theme_stylebox_override("panel", fsb)
	select_frame.size = Vector2(CELL, CELL)
	select_frame.visible = false
	board_node.add_child(select_frame)


func _build_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 20
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.97)
	sb.set_corner_radius_all(24)
	sb.content_margin_left = 48
	sb.content_margin_right = 48
	sb.content_margin_top = 40
	sb.content_margin_bottom = 40
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	panel.add_child(vbox)
	overlay_title = Label.new()
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_size_override("font_size", 46)
	overlay_title.add_theme_color_override("font_color", Color(0.06, 0.28, 0.42))
	vbox.add_child(overlay_title)
	overlay_star_holder = Control.new()
	overlay_star_holder.custom_minimum_size = Vector2(140, 140)
	overlay_star_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var star := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI * 0.5 + float(i) * PI / 5.0
		var rad := 62.0 if i % 2 == 0 else 26.0
		pts.append(Vector2(cos(ang), sin(ang)) * rad)
	star.polygon = pts
	star.color = Color(1.0, 0.78, 0.15)
	star.position = Vector2(70, 70)
	overlay_star_holder.add_child(star)
	vbox.add_child(overlay_star_holder)
	overlay_sub = Label.new()
	overlay_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_sub.add_theme_font_size_override("font_size", 28)
	overlay_sub.add_theme_color_override("font_color", Color(0.25, 0.25, 0.30))
	vbox.add_child(overlay_sub)
	overlay_button = Button.new()
	overlay_button.custom_minimum_size = Vector2(300, 76)
	overlay_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	overlay_button.add_theme_font_size_override("font_size", 30)
	overlay_button.pressed.connect(_on_overlay_button)
	vbox.add_child(overlay_button)
	overlay.hide()


# ---------------------------------------------------------------- entrada

func _input(event: InputEvent) -> void:
	if game_over or busy or overlay.visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_press(mb.position)
			else:
				_on_release(mb.position)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_on_press(st.position)
		else:
			_on_release(st.position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_drag_to(mm.position)
	elif event is InputEventScreenDrag:
		_drag_to((event as InputEventScreenDrag).position)


func _drag_to(screen_pos: Vector2) -> void:
	if not _valid_cell(press_cell):
		return
	var cell := _screen_to_cell(screen_pos)
	if _valid_cell(cell) and cell != press_cell and logic.are_adjacent(press_cell, cell):
		var a := press_cell
		press_cell = Vector2i(-1, -1)
		selected = Vector2i(-1, -1)
		_update_select_frame()
		attempt_swap(a, cell)


func _on_press(screen_pos: Vector2) -> void:
	var cell := _screen_to_cell(screen_pos)
	if not _valid_cell(cell):
		return
	press_cell = cell
	if _valid_cell(selected) and cell != selected and logic.are_adjacent(selected, cell):
		var a := selected
		selected = Vector2i(-1, -1)
		press_cell = Vector2i(-1, -1)
		_update_select_frame()
		attempt_swap(a, cell)
	elif cell == selected:
		selected = Vector2i(-1, -1)
		_update_select_frame()
	else:
		selected = cell
		_update_select_frame()


func _on_release(screen_pos: Vector2) -> void:
	var cell := _screen_to_cell(screen_pos)
	if _valid_cell(press_cell) and _valid_cell(cell) and cell != press_cell \
			and logic.are_adjacent(press_cell, cell):
		var a := press_cell
		press_cell = Vector2i(-1, -1)
		selected = Vector2i(-1, -1)
		_update_select_frame()
		attempt_swap(a, cell)
	else:
		press_cell = Vector2i(-1, -1)


func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	var local: Vector2 = world - board_node.position
	return Vector2i(int(floor(local.x / CELL)), int(floor(local.y / CELL)))


func _valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < BoardLogic.COLS and cell.y >= 0 and cell.y < BoardLogic.ROWS


func _cell_pos(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) * CELL + CELL * 0.5, float(cell.y) * CELL + CELL * 0.5)


func _update_select_frame() -> void:
	if _valid_cell(selected):
		select_frame.position = Vector2(float(selected.x) * CELL, float(selected.y) * CELL)
		select_frame.visible = true
	else:
		select_frame.visible = false


# ---------------------------------------------------------------- peças

func _create_piece(ptype: int, cell: Vector2i) -> Sprite2D:
	var s := Sprite2D.new()
	var t: Texture2D = tex[ptype]
	s.texture = t
	var sc: float = PIECE_TARGET / maxf(float(t.get_width()), float(t.get_height()))
	s.scale = Vector2(sc, sc)
	s.position = _cell_pos(cell)
	board_node.add_child(s)
	return s


func _rebuild_pieces() -> void:
	for child in board_node.get_children():
		if child != select_frame:
			child.queue_free()
	pieces.clear()
	for r in BoardLogic.ROWS:
		var row: Array = []
		for c in BoardLogic.COLS:
			row.append(_create_piece(logic.get_type(Vector2i(c, r)), Vector2i(c, r)))
		pieces.append(row)
	selected = Vector2i(-1, -1)
	_update_select_frame()


# ---------------------------------------------------------------- jogadas

func attempt_swap(a: Vector2i, b: Vector2i) -> void:
	if busy or game_over:
		return
	busy = true
	var na: Sprite2D = pieces[a.y][a.x]
	var nb: Sprite2D = pieces[b.y][b.x]
	logic.swap_cells(a, b)
	pieces[a.y][a.x] = nb
	pieces[b.y][b.x] = na
	var tw := create_tween().set_parallel(true)
	tw.tween_property(na, "position", _cell_pos(b), 0.16).set_trans(Tween.TRANS_SINE)
	tw.tween_property(nb, "position", _cell_pos(a), 0.16).set_trans(Tween.TRANS_SINE)
	await tw.finished
	if logic.find_matches().is_empty():
		# Troca inválida: desfaz com animação.
		logic.swap_cells(a, b)
		pieces[a.y][a.x] = na
		pieces[b.y][b.x] = nb
		var tw2 := create_tween().set_parallel(true)
		tw2.tween_property(na, "position", _cell_pos(a), 0.16).set_trans(Tween.TRANS_SINE)
		tw2.tween_property(nb, "position", _cell_pos(b), 0.16).set_trans(Tween.TRANS_SINE)
		await tw2.finished
		busy = false
		return
	moves -= 1
	_update_moves_label()
	await _resolve_board()
	busy = false
	_after_turn()


func _resolve_board() -> void:
	while true:
		var matches: Array = logic.find_matches()
		if matches.is_empty():
			break
		await _pop_cells(matches)
		var falls: Array = logic.apply_gravity()
		await _animate_falls(falls)
		_update_goal_labels()


func _pop_cells(cells: Array) -> void:
	var counts: Array = logic.remove_cells(cells)
	coco_count += int(counts[T_COCO])
	concha_count += int(counts[T_CONCHA])
	var nodes: Array = []
	for v in cells:
		var cell: Vector2i = v
		var node: Sprite2D = pieces[cell.y][cell.x]
		if node != null:
			nodes.append(node)
			pieces[cell.y][cell.x] = null
	var tw := create_tween().set_parallel(true)
	for n in nodes:
		tw.tween_property(n, "scale", Vector2.ZERO, 0.16)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished
	for n in nodes:
		n.queue_free()


func _animate_falls(falls: Array) -> void:
	if falls.is_empty():
		return
	var tw := create_tween().set_parallel(true)
	for f in falls:
		var col: int = int(f["col"])
		var to_row: int = int(f["to_row"])
		var from_row: int = int(f["from_row"])
		var ptype: int = int(f["ptype"])
		var is_new: bool = bool(f["is_new"])
		var node: Sprite2D
		if is_new:
			node = _create_piece(ptype, Vector2i(col, to_row))
			node.position = Vector2(
				float(col) * CELL + CELL * 0.5,
				float(from_row + 1) * CELL - CELL * 0.5)
		else:
			node = pieces[from_row][col]
			pieces[from_row][col] = null
		pieces[to_row][col] = node
		tw.tween_property(node, "position", _cell_pos(Vector2i(col, to_row)), 0.24)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished


func _after_turn() -> void:
	_update_goal_labels()
	if coco_count >= GOAL_COCO and concha_count >= GOAL_CONCHA:
		_show_win()
	elif moves <= 0:
		_show_lose()
	elif not logic.has_possible_move():
		busy = true
		_toast("Sem jogadas possíveis! Embaralhando...")
		await get_tree().create_timer(1.4).timeout
		logic.new_board()
		_rebuild_pieces()
		_hide_toast()
		busy = false


# ---------------------------------------------------------------- UI / fim

func _update_goal_labels() -> void:
	coco_label.text = "%d/%d" % [mini(coco_count, GOAL_COCO), GOAL_COCO]
	concha_label.text = "%d/%d" % [mini(concha_count, GOAL_CONCHA), GOAL_CONCHA]


func _update_moves_label() -> void:
	moves_label.text = "Movimentos: %d" % moves


func _toast(msg: String) -> void:
	toast_label.text = msg
	var tw := create_tween()
	tw.tween_property(toast_label, "modulate:a", 1.0, 0.2)


func _hide_toast() -> void:
	var tw := create_tween()
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.3)


func _show_win() -> void:
	game_over = true
	_update_select_frame()
	overlay_title.text = "Você venceu!"
	overlay_sub.text = "Meta cumprida!"
	overlay_star_holder.visible = true
	overlay_button.text = "Jogar de novo"
	overlay.show()


func _show_lose() -> void:
	game_over = true
	_update_select_frame()
	overlay_title.text = "Não foi dessa vez..."
	overlay_sub.text = "Faltaram %d cocos e %d conchas." % [
		maxi(GOAL_COCO - coco_count, 0), maxi(GOAL_CONCHA - concha_count, 0)]
	overlay_star_holder.visible = false
	overlay_button.text = "Tentar de novo"
	overlay.show()


func _on_overlay_button() -> void:
	overlay.hide()
	_restart()


func _restart() -> void:
	moves = START_MOVES
	coco_count = 0
	concha_count = 0
	game_over = false
	busy = false
	selected = Vector2i(-1, -1)
	press_cell = Vector2i(-1, -1)
	toast_label.modulate.a = 0.0
	logic.new_board()
	_rebuild_pieces()
	_update_goal_labels()
	_update_moves_label()
