extends SceneTree
## Temp: smoke test da navegação do redesign (start -> home -> fase, teasers).
## Opera sempre sobre current_scene (nada de add_child manual).

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_fails += 1
		printerr("FAIL: ", name)


func _find_btn(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text == text:
		return n as Button
	for ch in n.get_children():
		var f := _find_btn(ch, text)
		if f != null:
			return f
	return null


func _find_label_text(n: Node, text: String) -> Label:
	if n is Label and (n as Label).text == text:
		return n as Label
	for ch in n.get_children():
		var f := _find_label_text(ch, text)
		if f != null:
			return f
	return null


func _parent_button(n: Node) -> Button:
	var p := n.get_parent()
	while p != null:
		if p is Button:
			return p as Button
		p = p.get_parent()
	return null


func _has_text(n: Node, text: String) -> bool:
	if n is Label and text in (n as Label).text:
		return true
	if n is RichTextLabel and text in (n as RichTextLabel).get_parsed_text():
		return true
	if n is Button and text in (n as Button).text:
		return true
	for ch in n.get_children():
		if _has_text(ch, text):
			return true
	return false


func _wait_scene(name: String, max_frames: int = 40) -> Node:
	for i in max_frames:
		await process_frame
		if current_scene != null and current_scene.name == name:
			return current_scene
	return null


func _go(scene_path: String, expect: String) -> Node:
	change_scene_to_file(scene_path)
	var s := await _wait_scene(expect)
	_check(s != null, "navega para " + expect)
	return s


func _run() -> void:
	var gs = root.get_node("GameState")
	gs.save_path = "user://test_nav_save.cfg"
	gs.reset_progress()

	# 1. start -> JOGAR -> home
	var start = await _go("res://scenes/start_screen.tscn", "StartScreen")
	var jogar := _find_btn(start, "JOGAR")
	_check(jogar != null, "start: botao JOGAR existe")
	jogar.pressed.emit()
	var home = await _wait_scene("HomeScreen")
	_check(home != null, "JOGAR -> HomeScreen")

	# 2. home: faixa, pedestais, Fase 1 -> Main
	_check(_has_text(home, "Praia · 1 de 60"), "home: faixa 'Praia · 1 de 60'")
	var mundo_btn := _parent_button(_find_label_text(home, "Mundo"))
	_check(mundo_btn != null, "home: pedestal Mundo existe e clica")
	var reforma_btn := _parent_button(_find_label_text(home, "Reforma"))
	_check(reforma_btn != null, "home: pedestal Reforma existe e clica")
	var fase_btn := _find_btn(home, "Fase 1")
	_check(fase_btn != null, "home: botao Fase 1 existe")
	fase_btn.pressed.emit()
	_check(int(gs.current_level) == 1, "Fase 1 -> current_level=1")
	var main = await _wait_scene("Main")
	_check(main != null, "Fase 1 -> cena Main")
	_check(_has_text(main, "Metas"), "HUD: etiqueta Metas")
	_check(_has_text(main, "Jogadas"), "HUD: etiqueta Jogadas")
	_check(_has_text(main, str(gs.get_level(1)["moves"])), "HUD: numero de jogadas visivel")

	# 3. pedestal Mundo -> mapa de nós
	home = await _go("res://scenes/home_screen.tscn", "HomeScreen")
	mundo_btn = _parent_button(_find_label_text(home, "Mundo"))
	mundo_btn.pressed.emit()
	var lmap = await _wait_scene("LevelMap")
	_check(lmap != null, "pedestal Mundo -> mapa de nos")

	# 4. pedestal Reforma -> reforma (current_area setado)
	home = await _go("res://scenes/home_screen.tscn", "HomeScreen")
	reforma_btn = _parent_button(_find_label_text(home, "Reforma"))
	reforma_btn.pressed.emit()
	var ren = await _wait_scene("Renovation")
	_check(ren != null, "pedestal Reforma -> reforma")
	_check(int(gs.current_area) == 1, "Reforma: current_area=1")

	# 5. teaser ranking
	TeaserScreen.feature = "ranking"
	TeaserScreen.return_scene = "res://scenes/start_screen.tscn"
	var t = await _go("res://scenes/teaser.tscn", "TeaserScreen")
	_check(_has_text(t, "Fase 21"), "teaser ranking: 'Alcance a Fase 21'")
	_check(_has_text(t, "GRÁTIS"), "teaser: beneficios GRATIS")
	var back := _find_btn(t, "Entendi")
	_check(back != null, "teaser: botao Entendi existe")
	back.pressed.emit()
	var back_home = await _wait_scene("StartScreen")
	_check(back_home != null, "teaser Entendi -> volta")

	# 6. teaser loja
	TeaserScreen.feature = "loja"
	TeaserScreen.return_scene = "res://scenes/home_screen.tscn"
	var t2 = await _go("res://scenes/teaser.tscn", "TeaserScreen")
	_check(_has_text(t2, "Fase 10"), "teaser loja: 'Alcance a Fase 10'")
	_check(_has_text(t2, "Loja"), "teaser loja: titulo Loja")

	# 7. teaser premio
	TeaserScreen.feature = "premio"
	var t3 = await _go("res://scenes/teaser.tscn", "TeaserScreen")
	_check(_has_text(t3, "Fase 5"), "teaser premio: 'Alcance a Fase 5'")

	gs.reset_progress()
	if _fails == 0:
		print("ALL_NAV_CHECKS_PASSED")
	else:
		printerr("NAV_CHECKS_FAILED: ", _fails)
	quit(_fails)
