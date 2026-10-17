extends Node
## Teste funcional dos fluxos da Fase 4 (300 fases / 5 áreas):
## - reforma da área 1: 8 tarefas -> crossfade -> capítulo -> baú (+100 moedas)
## - reentrada: sem repetir história; baú já resgatado some
## - área 5: após o baú, tela final ("A história da Marina continua...")
## - mapa: aba bloqueada não troca; intro da área 2 aparece 1x; nó -> fase
## Roda no main loop normal (precisa do autoload).
## Uso: godot --headless --path <projeto> res://tests/flow_check.tscn

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var gs = get_node("/root/GameState")
	var tree := get_tree() # capturada antes de qualquer troca de cena
	# Save isolado: não toca no save real nem interfere com outros agentes.
	gs.save_path = "user://test_ui_save.cfg"
	gs.reset_progress()
	await _t_renovation_area1(gs)
	await _t_finale_area5(gs)
	await _t_map_intro_once(gs)
	# Resumo ANTES do teste destrutivo (abaixo): ele troca a cena de verdade.
	gs.reset_progress()
	var fails := _fails
	if fails == 0:
		print("ALL_FLOW_CHECKS_PASSED")
	else:
		printerr("FLOW_CHECKS_FAILED: ", fails)
	await _t_node_to_level(gs)
	tree.quit(fails)


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_fails += 1
		printerr("FAIL: ", name)


func _new_renovation():
	var ps: PackedScene = load("res://scenes/renovation.tscn")
	var ren = ps.instantiate()
	get_tree().root.add_child(ren)
	await get_tree().process_frame
	await get_tree().process_frame
	return ren


func _t_renovation_area1(gs) -> void:
	gs.reset_progress()
	gs.current_area = 1
	gs.stars = 8
	var ren = await _new_renovation()
	_check(ren._tasks.size() == 8, "reforma: 8 tarefas da area 1")
	# Completa as 8 tarefas chamando o handler (equivale ao toque).
	for t in gs.area_tasks(1):
		var row: Dictionary = ren._task_rows[t[0]]
		ren._on_task_pressed(t[0], row["button"])
		await get_tree().process_frame
	_check(gs.stars == 0, "8 tarefas consumiram 8 estrelas")
	_check(ren._all_done(), "todas as tarefas marcadas")
	_check(gs.area_renovation_done(1), "area_renovation_done(1) apos 8 tarefas")
	_check(gs.area_unlocked(2), "area 2 desbloqueia apos reforma da area 1")
	# Aguarda crossfade (0.8 + 1.4 + 0.4s).
	await get_tree().create_timer(3.2).timeout
	_check(ren._overlay.visible, "overlay da historia visivel apos crossfade")
	_check(ren._dlg_index == 0, "dialogo comeca na linha 0")
	# Avança todas as falas do capítulo.
	var lines: int = (gs.area_story(1) as Array).size()
	for i in lines:
		ren._on_overlay_tap()
		await get_tree().process_frame
	_check((ren._overlay.get_node("Chest") as Control).visible, "bau aparece apos o dialogo")
	_check(not (ren._overlay.get_node("Dialog") as Control).visible, "dialogo some apos o fim")
	var coins_before: int = gs.coins
	ren._on_chest_opened()
	await get_tree().process_frame
	_check(gs.coins == coins_before + 100, "bau deu +100 moedas")
	_check(bool(gs.chests_claimed.get(1, false)), "bau da area 1 marcado como resgatado")
	ren.queue_free()
	await get_tree().process_frame
	# Reentrar: sem história de novo, baú já resgatado some, sem tela final.
	gs.current_area = 1
	var ren2 = await _new_renovation()
	_check(not ren2._overlay.visible, "reentrada: overlay escondido (historia nao repete)")
	_check(not ren2._finale.visible, "reentrada area 1: sem tela final")
	ren2.queue_free()
	await get_tree().process_frame


func _t_finale_area5(gs) -> void:
	gs.reset_progress()
	# Completa as reformas das áreas 1-4 para desbloquear a 5.
	for a in [1, 2, 3, 4]:
		for t in gs.area_tasks(a):
			gs.complete_task(t[0])
	_check(gs.area_unlocked(5), "area 5 desbloqueada apos reformas 1-4")
	gs.current_area = 5
	gs.stars = 8
	var ren = await _new_renovation()
	_check(str(ren._cfg["name"]) == "O palco", "reforma parametrizada: titulo da area 5")
	for t in gs.area_tasks(5):
		var row: Dictionary = ren._task_rows[t[0]]
		ren._on_task_pressed(t[0], row["button"])
		await get_tree().process_frame
	_check(ren._all_done(), "area 5: 8 tarefas concluidas")
	await get_tree().create_timer(3.2).timeout
	var lines: int = (gs.area_story(5) as Array).size()
	_check(lines >= 6 and lines <= 7, "capitulo da area 5 tem 6-7 falas")
	for i in lines:
		ren._on_overlay_tap()
		await get_tree().process_frame
	_check((ren._overlay.get_node("Chest") as Control).visible, "area 5: bau aparece apos o dialogo")
	ren._on_chest_opened()
	await get_tree().create_timer(1.8).timeout
	_check(bool(gs.chests_claimed.get(5, false)), "bau da area 5 resgatado")
	_check(ren._finale.visible, "tela final visivel apos o bau da area 5")
	_check(not ren._overlay.visible, "overlay do bau some na tela final")
	ren.queue_free()
	await get_tree().process_frame
	# Reentrada na área 5 completa: mostra a tela final de novo.
	gs.current_area = 5
	var ren2 = await _new_renovation()
	_check(ren2._finale.visible, "reentrada area 5: tela final exibida")
	ren2.queue_free()
	await get_tree().process_frame


func _t_map_intro_once(gs) -> void:
	gs.reset_progress()
	# Desbloqueia a área 2 completando a reforma da área 1.
	for t in gs.area_tasks(1):
		gs.complete_task(t[0])
	var ps: PackedScene = load("res://scenes/level_map.tscn")
	var map = ps.instantiate()
	get_tree().root.add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(map._tab == 1, "mapa abre na aba da area 1")
	_check(not map._intro.visible, "sem intro na area 1")
	# Primeira abertura da aba 2: intro aparece.
	map._select_tab(2)
	await get_tree().process_frame
	_check(map._tab == 2, "aba 2 selecionada")
	_check(map._intro.visible, "intro da area 2 aparece na 1a abertura")
	_check(map._nodes.size() == 60, "aba 2 tem 60 nos")
	var lines: int = (gs.area_intro(2) as Array).size()
	_check(lines == 3, "intro da area 2 tem 3 falas")
	for i in lines:
		map._on_intro_tap()
		await get_tree().process_frame
	_check(not map._intro.visible, "intro some apos as 3 falas")
	_check(gs.intro_seen(2), "intro_seen(2) marcado")
	# Segunda abertura: intro NÃO aparece.
	map._select_tab(1)
	await get_tree().process_frame
	map._select_tab(2)
	await get_tree().process_frame
	_check(not map._intro.visible, "intro da area 2 nao repete")
	# Aba 3 ainda bloqueada: não troca.
	map._select_tab(3)
	await get_tree().process_frame
	_check(map._tab == 2, "aba 3 bloqueada: selecao mantida na aba 2")
	map.queue_free()
	await get_tree().process_frame


func _t_node_to_level(gs) -> void:
	gs.reset_progress()
	var ps: PackedScene = load("res://scenes/level_map.tscn")
	var map = ps.instantiate()
	get_tree().root.add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	# Nó 1 desbloqueado: define current_level (a troca de cena é deferred;
	# por isso este é o último passo: sem awaits após a chamada).
	map._on_level_pressed(1)
	_check(gs.current_level == 1, "toque no no 1 define current_level=1")
