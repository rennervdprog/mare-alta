extends SceneTree
## Teste de layout multi-resolução (responsividade 100%).
## Para cada tamanho de tela x cada cena com UI nova, verifica:
## (a) topbar/tabbar/botões principais 100% dentro do rect visível,
## (b) sem sobreposição entre controles interativos (botões),
## (c) fundos cobrindo o rect visível inteiro.
## Roda com: godot --headless --path <projeto> --script res://tests/test_layout.gd
## Saída: linhas PASS/FAIL + ALL_LAYOUT_TESTS_PASSED; exit code = nº de falhas.

const SIZES := [Vector2(720, 1280), Vector2(720, 1600), Vector2(1080, 1920), Vector2(750, 1334)]
const SCENES := {
	"start": "res://scenes/start_screen.tscn",
	"home": "res://scenes/home_screen.tscn",
	"teaser": "res://scenes/teaser.tscn",
	"config": "res://scenes/config_screen.tscn",
	"main": "res://main.tscn",
}

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_fails += 1
		printerr("FAIL: ", name)


## Rect visível em coordenadas de canvas com aspect="expand":
## escala = min(w/720, h/1280); visível = janela / escala.
func _visible_rect() -> Rect2:
	var win: Vector2 = root.size
	var s := minf(win.x / 720.0, win.y / 1280.0)
	return Rect2(Vector2.ZERO, win / s)


func _run() -> void:
	var gs = root.get_node("GameState")
	gs.save_path = "user://test_layout_save.cfg"
	gs.reset_progress()
	for sz in SIZES:
		root.size = sz
		await process_frame
		await process_frame
		_check(Vector2(root.size) == sz, "root.size aplicado %s (real: %s)" % [sz, root.size])
		var vr := _visible_rect()
		print("  [layout] tela %s -> visível %s" % [sz, vr.size])
		for key in SCENES:
			await _check_scene(key, SCENES[key], vr)
	gs.reset_progress()
	if _fails == 0:
		print("ALL_LAYOUT_TESTS_PASSED")
	else:
		printerr("LAYOUT_TESTS_FAILED: ", _fails)
	quit(_fails)


func _check_scene(key: String, path: String, vr: Rect2) -> void:
	change_scene_to_file(path)
	for i in 8:
		await process_frame
		if current_scene != null:
			break
	var s := current_scene
	_check(s != null, "[%s] cena carregou" % key)
	if s == null:
		return
	# (a) botões visíveis 100% dentro do rect visível
	# (botões dentro de ScrollContainer são roláveis por design).
	var btns := _visible_buttons(s)
	for b in btns:
		var r := (b as Control).get_global_rect()
		if _in_scroll(b):
			_check(true, "[%s] botão '%s' rolável (ScrollContainer)" % [key, _btn_name(b)])
		else:
			_check(vr.grow(1.0).encloses(r), "[%s] botão '%s' dentro da tela (rect %s)" % [key, _btn_name(b), r])
	# (b) sem sobreposição entre botões interativos.
	for i in btns.size():
		for j in range(i + 1, btns.size()):
			var ri := (btns[i] as Control).get_global_rect()
			var rj := (btns[j] as Control).get_global_rect()
			_check(not ri.grow(-2.0).intersects(rj.grow(-2.0)),
				"[%s] sem sobreposição: '%s' x '%s'" % [key, _btn_name(btns[i]), _btn_name(btns[j])])
	# (c) fundos full-rect cobrem o rect visível.
	_check(_bg_covers(s, vr), "[%s] fundo cobre a tela" % key)
	_extra_checks(key, s, vr)


func _visible_buttons(n: Node) -> Array:
	var out: Array = []
	_collect_buttons(n, out)
	return out


func _collect_buttons(n: Node, out: Array) -> void:
	if n is Button and (n as CanvasItem).is_visible_in_tree():
		out.append(n)
	for ch in n.get_children():
		_collect_buttons(ch, out)


func _btn_name(b: Node) -> String:
	var t := (b as Button).text
	if t != "":
		return t
	return b.name


## true se o controle está dentro de um ScrollContainer (conteúdo rolável).
func _in_scroll(n: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


func _bg_covers(s: Node, vr: Rect2) -> bool:
	var bgs: Array = []
	_collect_bg(s, bgs)
	if bgs.is_empty():
		return true # sem fundo próprio (ex.: config usa fundo da janela)
	for b in bgs:
		var r := (b as Control).get_global_rect()
		if not r.grow(2.0).encloses(vr):
			printerr("  fundo não cobre: ", (b as Node).name, " rect=", r, " visível=", vr)
			return false
	return true


func _collect_bg(n: Node, out: Array) -> void:
	if (n is TextureRect or n is ColorRect) and (n as CanvasItem).visible:
		var c := n as Control
		if c.anchor_left == 0.0 and c.anchor_top == 0.0 and c.anchor_right == 1.0 and c.anchor_bottom == 1.0:
			out.append(n)
	for ch in n.get_children():
		_collect_bg(ch, out)


func _extra_checks(key: String, s: Node, vr: Rect2) -> void:
	var tab := s.find_child("Tabbar", true, false)
	if tab != null:
		var r := (tab as Control).get_global_rect()
		_check(absf(r.end.y - vr.end.y) < 2.0, "[%s] Tabbar colada embaixo" % key)
		_check(absf(r.size.x - vr.size.x) < 2.0, "[%s] Tabbar full-width" % key)
		_check(vr.grow(1.0).encloses(r), "[%s] Tabbar dentro da tela" % key)
	if key == "start" or key == "home":
		var tb := s.find_child("Topbar", true, false)
		_check(tb != null, "[%s] Topbar existe" % key)
		if tb != null:
			var r2 := (tb as Control).get_global_rect()
			_check(r2.position.y >= -1.0, "[%s] Topbar no topo" % key)
			_check(absf(r2.size.x - vr.size.x) < 2.0, "[%s] Topbar full-width" % key)
			_check(vr.grow(1.0).encloses(r2), "[%s] Topbar dentro da tela" % key)
	if key == "home":
		var fb := _find_button_text(s, "Fase")
		_check(fb != null, "[home] botão Fase existe")
		if fb != null:
			_check(vr.grow(1.0).encloses((fb as Control).get_global_rect()), "[home] botão Fase dentro da tela")
	if key == "start":
		var jb := _find_button_text(s, "JOGAR")
		_check(jb != null, "[start] botão JOGAR existe")
		if jb != null:
			_check(vr.grow(1.0).encloses((jb as Control).get_global_rect()), "[start] JOGAR dentro da tela")
	if key == "teaser":
		for ch in s.get_children():
			if ch is Panel and (ch as Control).size.x == 640.0:
				var r3 := (ch as Control).get_global_rect()
				_check(absf(r3.get_center().x - vr.get_center().x) < 2.0, "[teaser] sheet centralizada x")
				_check(vr.grow(1.0).encloses(r3), "[teaser] sheet dentro da tela")
	if key == "main":
		var panel := s.find_child("BoardPanel", true, false)
		_check(panel != null, "[main] BoardPanel existe")
		if panel != null:
			var r4 := (panel as Control).get_global_rect()
			_check(vr.grow(1.0).encloses(r4), "[main] tabuleiro dentro da tela")
			_check(absf(r4.get_center().x - vr.get_center().x) < 2.0, "[main] tabuleiro centralizado x")
			if vr.size.y > 1400.0:
				_check(r4.position.y > 300.0, "[main] tabuleiro desceu em tela alta (y=%.0f)" % r4.position.y)
		var hud := s.find_child("HUD", true, false)
		_check(hud != null, "[main] HUD existe")
		if hud != null:
			_check(vr.grow(1.0).encloses((hud as Control).get_global_rect()), "[main] HUD dentro da tela")


func _find_button_text(n: Node, prefix: String) -> Node:
	if n is Button and (n as Button).text.begins_with(prefix):
		return n
	for ch in n.get_children():
		var f := _find_button_text(ch, prefix)
		if f != null:
			return f
	return null
