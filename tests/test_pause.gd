extends SceneTree
## Testes do menu de pausa + recorte das peças + toggles da config.
## Roda com: godot --headless --path <projeto> --script res://tests/test_pause.gd
## Usa user://test_pause_save.cfg para não tocar no save real.

var _fails := 0


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_fails += 1
		printerr("FAIL: ", name)


func _wait_scene(sname: String, max_frames: int = 90) -> Node:
	for i in max_frames:
		await process_frame
		if current_scene != null and current_scene.name == sname:
			return current_scene
	return null


func _find(n: Node, target: String) -> Node:
	if n.name == target:
		return n
	for ch in n.get_children():
		var f := _find(ch, target)
		if f != null:
			return f
	return null


func _run() -> void:
	var gs = root.get_node("GameState")
	gs.save_path = "user://test_pause_save.cfg"
	gs.reset_progress()
	gs.lives = 5

	# ---- fase: pausa existe e congela ----
	change_scene_to_file("res://main.tscn")
	var s: Node = await _wait_scene("Main")
	_check(s != null, "pausa: cena Main carrega")
	if s == null:
		_finish()
		return
	var pause_btn: Button = _find(s, "PauseBtn") as Button
	_check(pause_btn != null and pause_btn.visible, "pausa: botão PauseBtn visível no HUD")
	var pause_layer: CanvasLayer = _find(s, "PauseLayer") as CanvasLayer
	_check(pause_layer != null and not pause_layer.visible, "pausa: menu começa escondido")
	# peças sob o recorte, dentro da moldura
	var clip: Control = _find(s, "PiecesClip") as Control
	_check(clip != null and clip.clip_contents, "clip: PiecesClip existe com clip_contents")
	if clip != null:
		_check(clip.size == Vector2(672, 672), "clip: tamanho = área do tabuleiro")
		_check(clip.get_children().size() == 64, "clip: 64 peças filhas do recorte")
	# congela ao pausar (via sinal do botão, como o jogador faria)
	pause_btn.pressed.emit()
	await process_frame
	_check(paused, "pausa: árvore pausada (timers/animações congelam)")
	_check(pause_layer.visible, "pausa: menu aparece")
	# continuar
	(s as Node).call("_on_pause_resume")
	await process_frame
	_check(not paused, "pausa: continuar despausa")
	_check(not pause_layer.visible, "pausa: menu esconde ao continuar")
	# reiniciar não custa vida nem dá recompensa
	var lives_before: int = gs.lives
	var won_before: int = gs.levels_won.size()
	(s as Node).call("_on_pause_pressed")
	(s as Node).call("_on_pause_restart")
	await process_frame
	_check(not paused, "pausa: reiniciar despausa")
	_check(gs.lives == lives_before, "pausa: reiniciar não custa vida")
	_check(gs.levels_won.size() == won_before, "pausa: reiniciar não dá recompensa")
	# sair no meio da fase: sem custo de vida, sem recompensa
	lives_before = gs.lives
	won_before = gs.levels_won.size()
	(s as Node).call("_on_pause_pressed")
	(s as Node).call("_on_pause_exit")
	var lm: Node = await _wait_scene("LevelMap")
	_check(lm != null, "pausa: sair vai pro mapa")
	_check(not paused, "pausa: sair despausa antes de trocar de cena")
	_check(gs.lives == lives_before, "pausa: SAIR DA FASE NÃO CUSTA VIDA")
	_check(gs.levels_won.size() == won_before, "pausa: sair não dá recompensa")

	# ---- config: toggles visíveis e tocáveis ----
	change_scene_to_file("res://scenes/config_screen.tscn")
	var cfg: Node = await _wait_scene("ConfigScreen")
	_check(cfg != null, "config: cena carrega")
	if cfg != null:
		for tn in ["CheckSound", "CheckMusic", "CheckNotif"]:
			var t: Button = _find(cfg, tn) as Button
			_check(t != null, "config: toggle " + tn + " existe")
			if t != null:
				_check(t.custom_minimum_size.y >= 44.0, "config: toggle " + tn + " altura >= 44px")
				_check(t.toggle_mode, "config: toggle " + tn + " é toggle_mode")
		# alternar persiste (simula o sinal toggled como o jogador faria)
		var snd: Button = _find(cfg, "CheckSound") as Button
		var before: bool = gs.opt_sound
		snd.toggled.emit(not before)
		_check(gs.opt_sound == (not before), "config: toggle sons persiste no GameState")
		_check(snd.text == ("Ligado" if not before else "Desligado"), "config: toggle sons atualiza texto")
		snd.toggled.emit(before)

	_finish()


func _finish() -> void:
	paused = false
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("test_pause_save.cfg"):
		dir.remove("test_pause_save.cfg")
	if _fails == 0:
		print("ALL_PAUSE_TESTS_PASSED")
	else:
		printerr("PAUSE_TESTS_FAILED: ", _fails)
	quit(_fails)
