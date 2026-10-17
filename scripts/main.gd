extends Node2D
## MARÉ ALTA — Fase 2: núcleo match-3 + 4 power-ups (Pipa, Gaivota, Trovão, Sol).
## Retrato 720x1280. Controles: toque na peça + toque na vizinha, ou arrastar.
## Power-up: toque nele para disparar, ou troque com peça/power-up vizinho.

const CELL := 76.0
const BOARD_PX := 608.0
const BOARD_X := 56.0
const BOARD_Y := 300.0
const PIECE_TARGET := 64.0

const T_COCO := 0
const T_GUARDA_SOL := 1
const T_CHINELO := 2
const T_PEIXE := 3
const T_CONCHA := 4

const TEX_PATHS: Array[String] = [
	"res://assets/pecas/media-generation-peca-coco-0-4c8ee45f-8fe4-4ba7-a157-87abc63074d9.webp",
	"res://assets/pecas/media-generation-peca-guarda-sol-0-cc42fc82-43d4-4a76-ad42-435b3b62f08b.webp",
	"res://assets/pecas/media-generation-peca-chinelo-0-3d35c8f8-fa6f-4094-9002-013d606c627a.webp",
	"res://assets/pecas/media-generation-peca-peixe-0-b89b476d-f69a-4497-8be5-b2fedd17eeb2.webp",
	"res://assets/pecas/media-generation-peca-concha-0-ff58d4b9-bb14-4907-946b-5e8ae9ff218d.webp",
	"res://assets/pecas/media-generation-peca-pipa-0-c5f7b3c9-2118-4ee1-8b12-6b585b0bd854.webp",
	"res://assets/pecas/media-generation-peca-gaivota-0-ef0974e1-77a1-409b-967b-26fb699f85a0.webp",
	"res://assets/pecas/media-generation-peca-trovao-0-34664f41-9fe7-4a07-b1d1-f6809681a228.webp",
	"res://assets/pecas/media-generation-peca-sol-powerup-0-024d75cd-b0ae-4a9c-ab3b-30666ea59f56.webp",
]

var logic: BoardLogic
var tex: Array = []
var board_node: Node2D
var pieces: Array = [] # pieces[linha][coluna] -> Sprite2D
var selected := Vector2i(-1, -1)
var press_cell := Vector2i(-1, -1)
var sol_armed := Vector2i(-1, -1)
var busy := false
var game_over := false
var level_cfg: Dictionary = {}
var goal_targets: Dictionary = {} # type_id -> alvo
var goal_counts: Dictionary = {}  # type_id -> coletados
var moves := 0
var _won_last := false

# Sistema de dica (idle hint): após HINT_DELAY sem input, sugere um movimento
# com pulso nas peças. Qualquer toque/arrastar cancela e reinicia o timer.
const HINT_DELAY := 4.0
var hint_idle := 0.0
var hint_cells: Array = []  # Vector2i das peças destacadas
var hint_scales: Array = [] # escalas-base para restaurar ao cancelar
var hint_tweens: Array = [] # tweens do pulso

var moves_label: Label
var goal_labels: Dictionary = {} # type_id -> Label
var toast_label: Label
var select_frame: Panel
var overlay: CanvasLayer
var overlay_title: Label
var overlay_sub: Label
var overlay_star_holder: Control
var overlay_button: Button


func _tex_index(ptype: int) -> int:
	match ptype:
		BoardLogic.P_PIPA:
			return 5
		BoardLogic.P_GAIVOTA:
			return 6
		BoardLogic.P_TROVAO:
			return 7
		BoardLogic.P_SOL:
			return 8
		_:
			return ptype


func _ready() -> void:
	# Config da fase vem do GameState (metas + movimentos calibrados via bot).
	level_cfg = GameState.get_level(GameState.current_level)
	goal_targets = level_cfg["goals"]
	for t in goal_targets.keys():
		goal_counts[t] = 0
	moves = int(level_cfg["moves"])
	for p in TEX_PATHS:
		tex.append(load(p))
	_build_background()
	_build_hud()
	_build_board()
	_build_overlay()
	logic = BoardLogic.new()
	logic.goal_types = goal_targets.keys()
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
	_make_label("MARÉ ALTA · Fase %d" % GameState.current_level, 54, Vector2(0, 24), Vector2(720, 84))
	_goals_box = HBoxContainer.new()
	_goals_box.position = Vector2(0, 118)
	_goals_box.size = Vector2(720, 64)
	_goals_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_goals_box.add_theme_constant_override("separation", 64)
	add_child(_goals_box)
	for t in goal_targets.keys():
		goal_labels[t] = _make_goal_row(int(t))
	moves_label = _make_label("Movimentos: %d" % moves, 40, Vector2(0, 196), Vector2(720, 56))
	_make_label("Combine 4+ para criar power-ups!", 24, Vector2(0, 1196), Vector2(720, 40))
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

func _process(delta: float) -> void:
	## Timer do idle hint: 4s sem input e sem animação -> sugere um movimento.
	if game_over or busy or overlay.visible or _valid_cell(sol_armed):
		if not hint_cells.is_empty():
			_cancel_hint()
		hint_idle = 0.0
		return
	hint_idle += delta
	if hint_idle >= HINT_DELAY and hint_cells.is_empty():
		_show_hint()


func _show_hint() -> void:
	if logic == null:
		return
	var h: Dictionary = logic.find_hint()
	if h.is_empty():
		hint_idle = 0.0 # sem dica agora; tenta de novo em 4s
		return
	var cells: Array = [h["a"]]
	if h["b"] != h["a"]:
		cells.append(h["b"])
	for v in cells:
		var cell: Vector2i = v
		if not _valid_cell(cell):
			continue
		var node: Sprite2D = pieces[cell.y][cell.x]
		if node == null:
			continue
		hint_cells.append(cell)
		hint_scales.append(node.scale)
		var tw := create_tween().set_loops()
		tw.tween_property(node, "scale", node.scale * 1.22, 0.45)\
			.set_trans(Tween.TRANS_SINE)
		tw.tween_property(node, "scale", node.scale, 0.45)\
			.set_trans(Tween.TRANS_SINE)
		hint_tweens.append(tw)


func _cancel_hint() -> void:
	## Qualquer toque/arrastar chama isto: mata o pulso, restaura escalas,
	## reinicia o timer.
	for tw in hint_tweens:
		if is_instance_valid(tw):
			(tw as Tween).kill()
	hint_tweens.clear()
	for i in hint_cells.size():
		var cell: Vector2i = hint_cells[i]
		if _valid_cell(cell) and i < hint_scales.size():
			var node: Sprite2D = pieces[cell.y][cell.x]
			if is_instance_valid(node):
				node.scale = hint_scales[i]
	hint_cells.clear()
	hint_scales.clear()
	hint_idle = 0.0


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
	_cancel_hint()
	if not _valid_cell(press_cell):
		return
	var cell := _screen_to_cell(screen_pos)
	if not (_valid_cell(cell) and cell != press_cell and logic.are_adjacent(press_cell, cell)):
		return
	var a := press_cell
	press_cell = Vector2i(-1, -1)
	selected = Vector2i(-1, -1)
	_update_select_frame()
	var ta: int = logic.get_type(a)
	var tb: int = logic.get_type(cell)
	if logic.is_powerup(ta) or logic.is_powerup(tb):
		_activate_pair(a, cell)
	else:
		attempt_swap(a, cell)


func _on_press(screen_pos: Vector2) -> void:
	_cancel_hint()
	var cell := _screen_to_cell(screen_pos)
	if not _valid_cell(cell):
		return
	# Sol armado: segundo toque escolhe a cor (ou combo / desarma).
	if _valid_cell(sol_armed):
		if cell == sol_armed:
			_disarm_sol()
			return
		var t: int = logic.get_type(cell)
		if logic.is_powerup(t):
			var s := sol_armed
			_disarm_sol()
			_do_combo(s, cell)
		elif logic.is_normal(t):
			_do_sol_fire(sol_armed, t)
		return
	var t: int = logic.get_type(cell)
	# Toque direto num power-up: dispara (Sol arma para escolher cor).
	if logic.is_powerup(t):
		if t == BoardLogic.P_SOL:
			_arm_sol(cell)
		else:
			_do_single_powerup(cell)
		return
	press_cell = cell
	if _valid_cell(selected) and cell != selected and logic.are_adjacent(selected, cell):
		var a := selected
		selected = Vector2i(-1, -1)
		press_cell = Vector2i(-1, -1)
		_update_select_frame()
		var tb: int = logic.get_type(cell)
		if logic.is_powerup(tb):
			_activate_pair(a, cell)
		else:
			attempt_swap(a, cell)
	elif cell == selected:
		selected = Vector2i(-1, -1)
		_update_select_frame()
	else:
		selected = cell
		_update_select_frame()


func _on_release(screen_pos: Vector2) -> void:
	_cancel_hint()
	var cell := _screen_to_cell(screen_pos)
	if _valid_cell(press_cell) and _valid_cell(cell) and cell != press_cell \
			and logic.are_adjacent(press_cell, cell):
		var a := press_cell
		press_cell = Vector2i(-1, -1)
		selected = Vector2i(-1, -1)
		_update_select_frame()
		var ta: int = logic.get_type(a)
		var tb: int = logic.get_type(cell)
		if logic.is_powerup(ta) or logic.is_powerup(tb):
			_activate_pair(a, cell)
		else:
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
	if _valid_cell(selected) or _valid_cell(sol_armed):
		var c := selected if _valid_cell(selected) else sol_armed
		select_frame.position = Vector2(float(c.x) * CELL, float(c.y) * CELL)
		select_frame.visible = true
	else:
		select_frame.visible = false


func _arm_sol(cell: Vector2i) -> void:
	sol_armed = cell
	_update_select_frame()
	_toast("Sol armado! Toque numa peça para escolher a cor.")


func _disarm_sol() -> void:
	sol_armed = Vector2i(-1, -1)
	_update_select_frame()
	_hide_toast()


# ---------------------------------------------------------------- peças

func _create_piece(ptype: int, cell: Vector2i) -> Sprite2D:
	var s := Sprite2D.new()
	var t: Texture2D = tex[_tex_index(ptype)]
	s.texture = t
	var sc: float = PIECE_TARGET / maxf(float(t.get_width()), float(t.get_height()))
	s.scale = Vector2(sc, sc)
	s.position = _cell_pos(cell)
	board_node.add_child(s)
	return s


func _rebuild_pieces() -> void:
	_cancel_hint() # peças serão recriadas; o pulso não pode apontar p/ nós mortos
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
	sol_armed = Vector2i(-1, -1)
	_update_select_frame()


# ---------------------------------------------------------------- jogadas

func attempt_swap(a: Vector2i, b: Vector2i) -> void:
	## Troca entre duas peças NORMAIS (power-ups têm fluxo próprio).
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
	var sq_cell := Vector2i(-1, -1)
	if logic.detect_square_at(a):
		sq_cell = a
	elif logic.detect_square_at(b):
		sq_cell = b
	if logic.find_matches().is_empty() and not _valid_cell(sq_cell):
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
	await _resolve_cascades(a, sq_cell)
	busy = false
	_after_turn()


func _activate_pair(a: Vector2i, b: Vector2i) -> void:
	## Troca envolvendo power-up: dispara sem precisar de combinação.
	if busy or game_over:
		return
	var ta: int = logic.get_type(a)
	var tb: int = logic.get_type(b)
	# Dois power-ups: combo direto, sem troca visual.
	if logic.is_powerup(ta) and logic.is_powerup(tb):
		_do_combo(a, b)
		return
	busy = true
	selected = Vector2i(-1, -1)
	_update_select_frame()
	var na: Sprite2D = pieces[a.y][a.x]
	var nb: Sprite2D = pieces[b.y][b.x]
	logic.swap_cells(a, b)
	pieces[a.y][a.x] = nb
	pieces[b.y][b.x] = na
	var tw := create_tween().set_parallel(true)
	tw.tween_property(na, "position", _cell_pos(b), 0.16).set_trans(Tween.TRANS_SINE)
	tw.tween_property(nb, "position", _cell_pos(a), 0.16).set_trans(Tween.TRANS_SINE)
	await tw.finished
	# Power-up está agora na outra célula.
	var pcell: Vector2i = b if logic.is_powerup(logic.get_type(b)) else a
	var ptype: int = logic.get_type(pcell)
	var other: Vector2i = a if pcell == b else b
	moves -= 1
	_update_moves_label()
	if ptype == BoardLogic.P_SOL:
		await _execute_trigger(logic.trigger_sol_at(pcell, logic.get_type(other)))
	else:
		await _execute_trigger(logic.trigger_at(pcell))
	busy = false
	_after_turn()


func _do_single_powerup(cell: Vector2i) -> void:
	## Toque direto num power-up (exceto Sol).
	if busy or game_over:
		return
	busy = true
	selected = Vector2i(-1, -1)
	_update_select_frame()
	moves -= 1
	_update_moves_label()
	await _execute_trigger(logic.trigger_at(cell))
	busy = false
	_after_turn()


func _do_combo(a: Vector2i, b: Vector2i) -> void:
	if busy or game_over:
		return
	busy = true
	selected = Vector2i(-1, -1)
	_update_select_frame()
	moves -= 1
	_update_moves_label()
	await _execute_trigger(logic.combo_cells(a, b))
	busy = false
	_after_turn()


func _do_sol_fire(sol_cell: Vector2i, color: int) -> void:
	if busy or game_over:
		return
	busy = true
	_disarm_sol()
	moves -= 1
	_update_moves_label()
	await _execute_trigger(logic.trigger_sol_at(sol_cell, color))
	busy = false
	_after_turn()


## Soma peças coletadas às metas da fase (genérico: qualquer combinação de metas).
func _add_counts(counts: Array) -> void:
	for t in goal_targets.keys():
		goal_counts[t] = int(goal_counts[t]) + int(counts[int(t)])


func _goals_met() -> bool:
	for t in goal_targets.keys():
		if int(goal_counts[t]) < int(goal_targets[t]):
			return false
	return true


func _execute_trigger(result: Dictionary) -> void:
	await _play_fx(result["fx"])
	var cells: Array = result["cells"]
	var counts: Array = logic.remove_cells(cells)
	_add_counts(counts)
	await _blast_punch(cells)
	await _pop_sprites(cells)
	# FIX (bug 2026-10-17): a gravidade precisa rodar SEMPRE após a
	# explosão. Antes ela só rodava dentro de _resolve_cascades quando
	# uma combinação era removida — se a explosão não gerasse match
	# novo, o loop quebrava na 1ª iteração e as células ficavam vazias.
	var falls: Array = logic.apply_gravity()
	await _animate_falls(falls)
	await _resolve_cascades(Vector2i(-1, -1), Vector2i(-1, -1))
	_update_goal_labels()


func _resolve_cascades(preferred: Vector2i, square_cell: Vector2i) -> void:
	var pref := preferred
	var sq := square_cell
	var first := true
	while true:
		var res: Dictionary
		if first and _valid_cell(sq):
			res = logic.resolve_square(sq)
			sq = Vector2i(-1, -1)
		else:
			res = logic.resolve_matches(pref if first else Vector2i(-1, -1))
		first = false
		var removed: Array = res["removed"]
		if removed.is_empty():
			break
		var counts: Array = res["counts"]
		_add_counts(counts)
		await _pop_sprites(removed)
		var ctype: int = int(res["created_ptype"])
		if ctype != -1:
			await _spawn_powerup_sprite(ctype, res["created_at"])
		var falls: Array = logic.apply_gravity()
		await _animate_falls(falls)
		_update_goal_labels()


func _blast_punch(cells: Array) -> void:
	## A explosão "incha" as peças atingidas antes de sumirem — o flash
	## sozinho era sutil demais e o Renner não viu animação nenhuma.
	var nodes: Array = []
	for v in cells:
		var cell: Vector2i = v
		if _valid_cell(cell):
			var node: Sprite2D = pieces[cell.y][cell.x]
			if node != null:
				nodes.append(node)
	if nodes.is_empty():
		return
	var tw := create_tween().set_parallel(true)
	for n in nodes:
		var s: Sprite2D = n
		tw.tween_property(s, "scale", s.scale * 1.35, 0.10)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished


func _pop_sprites(cells: Array) -> void:
	var nodes: Array = []
	for v in cells:
		var cell: Vector2i = v
		var node: Sprite2D = pieces[cell.y][cell.x]
		if node != null:
			nodes.append(node)
			pieces[cell.y][cell.x] = null
	if nodes.is_empty():
		return
	var tw := create_tween().set_parallel(true)
	for n in nodes:
		tw.tween_property(n, "scale", Vector2.ZERO, 0.16)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished
	for n in nodes:
		n.queue_free()


func _spawn_powerup_sprite(ptype: int, cell: Vector2i) -> void:
	var old: Sprite2D = pieces[cell.y][cell.x]
	if old != null:
		old.queue_free()
	var ps := _create_piece(ptype, cell)
	pieces[cell.y][cell.x] = ps
	var target: Vector2 = ps.scale
	ps.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(ps, "scale", target, 0.28)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished


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


func _play_fx(fx: Array) -> void:
	for e in fx:
		var kind: String = String(e["kind"])
		if kind == "gaivota_flight":
			await _fx_gaivota_flight(e["from"], e["to"])
		elif kind == "blast":
			_fx_flash(_blast_rect(e))
			if String(e.get("shape", "")) == "square":
				_shake(8.0) # Trovão: área grande merece impacto
		elif kind == "sol_fire":
			_fx_flash(Rect2(BOARD_X, BOARD_Y, BOARD_PX, BOARD_PX), 0.6)
		elif kind == "combo":
			_fx_flash(Rect2(BOARD_X, BOARD_Y, BOARD_PX, BOARD_PX), 0.8)
			_shake(12.0)


func _blast_rect(e: Dictionary) -> Rect2:
	var shape: String = String(e.get("shape", "square"))
	var center: Vector2i = e["center"]
	if shape == "cross":
		# Retornado como dois flashes: desenha o retângulo envolvente da cruz
		# (linha + coluna inteiras) via dois rects; aqui um só: usa dois flashes.
		_fx_flash(Rect2(BOARD_X, BOARD_Y + center.y * CELL, BOARD_PX, CELL), 0.4)
		return Rect2(BOARD_X + center.x * CELL, BOARD_Y, CELL, BOARD_PX)
	var radius: int = int(e.get("radius", 2))
	var x0: float = BOARD_X + maxf(0.0, float(center.x - radius)) * CELL
	var y0: float = BOARD_Y + maxf(0.0, float(center.y - radius)) * CELL
	var x1: float = BOARD_X + minf(7.0, float(center.x + radius)) * CELL + CELL
	var y1: float = BOARD_Y + minf(7.0, float(center.y + radius)) * CELL + CELL
	return Rect2(x0, y0, x1 - x0, y1 - y0)


func _fx_flash(rect: Rect2, alpha: float = 0.75) -> void:
	## Flash branco em pulso duplo — o flash único de 0.28s era sutil
	## demais e passava despercebido.
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, alpha)
	r.position = rect.position
	r.size = rect.size
	add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "modulate:a", 0.15, 0.12)
	tw.tween_property(r, "modulate:a", alpha, 0.10)
	tw.tween_property(r, "modulate:a", 0.0, 0.30)
	tw.tween_callback(r.queue_free)


func _shake(magnitude: float = 10.0) -> void:
	## Tremidinha rápida no tabuleiro para explosões grandes.
	## (input fica bloqueado por busy=true durante a ativação)
	var orig: Vector2 = board_node.position
	var tw := create_tween()
	tw.tween_property(board_node, "position", orig + Vector2(magnitude, 0), 0.05)
	tw.tween_property(board_node, "position", orig + Vector2(-magnitude, 0), 0.05)
	tw.tween_property(board_node, "position", orig + Vector2(magnitude * 0.5, 0), 0.05)
	tw.tween_property(board_node, "position", orig, 0.05)


func _fx_gaivota_flight(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var s := Sprite2D.new()
	var t: Texture2D = tex[_tex_index(BoardLogic.P_GAIVOTA)]
	s.texture = t
	var sc: float = PIECE_TARGET / maxf(float(t.get_width()), float(t.get_height()))
	s.scale = Vector2(sc, sc)
	s.position = board_node.position + _cell_pos(from_cell)
	add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "position", board_node.position + _cell_pos(to_cell), 0.38)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	s.queue_free()


func _after_turn() -> void:
	_update_goal_labels()
	if _goals_met():
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
	for t in goal_targets.keys():
		var lab: Label = goal_labels[t]
		lab.text = "%d/%d" % [mini(int(goal_counts[t]), int(goal_targets[t])), int(goal_targets[t])]


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
	_won_last = true
	_update_select_frame()
	var first: bool = GameState.on_level_won(GameState.current_level)
	overlay_title.text = "Você venceu!"
	overlay_sub.text = "Você ganhou 1 estrela!" if first else "Fase concluída!"
	overlay_star_holder.visible = true
	overlay_button.text = "Continuar"
	overlay.show()


func _show_lose() -> void:
	game_over = true
	_won_last = false
	_update_select_frame()
	overlay_title.text = "Não foi dessa vez..."
	var parts := PackedStringArray()
	for t in goal_targets.keys():
		var missing := maxi(int(goal_targets[t]) - int(goal_counts[t]), 0)
		if missing > 0:
			parts.append("%d %s" % [missing, GameState.TYPE_NAMES[int(t)]])
	overlay_sub.text = "Faltaram " + " e ".join(parts) + "."
	overlay_star_holder.visible = false
	overlay_button.text = "Voltar ao mapa"
	overlay.show()


func _on_overlay_button() -> void:
	overlay.hide()
	get_tree().change_scene_to_file("res://scenes/level_map.tscn")


func _restart() -> void:
	moves = int(level_cfg["moves"])
	for t in goal_targets.keys():
		goal_counts[t] = 0
	game_over = false
	busy = false
	selected = Vector2i(-1, -1)
	press_cell = Vector2i(-1, -1)
	sol_armed = Vector2i(-1, -1)
	toast_label.modulate.a = 0.0
	logic.new_board()
	_rebuild_pieces()
	_update_goal_labels()
	_update_moves_label()
