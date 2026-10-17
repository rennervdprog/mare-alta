extends Node
## Check de cenas rodando no main loop NORMAL (com autoloads).
## Roda com: godot --headless --path <projeto> res://tests/scene_check.tscn
## Não commitar como cena do jogo: arquivo de verificação temporário.
## Realidade 300 fases / 5 áreas: valida MAX_LEVEL, AREAS, 5 abas e 60 nós.

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var gs = get_node("/root/GameState")
	var tree := get_tree() # capturada antes de qualquer troca de cena
	# Save isolado: não toca no save real nem interfere com outros agentes.
	gs.save_path = "user://test_ui_save.cfg"
	gs.reset_progress()
	_check_autoload()
	_check_areas()
	await _check_scene("res://scenes/level_map.tscn", 80, "mapa")
	await _check_map_structure()
	await _check_scene("res://scenes/renovation.tscn", 60, "renovacao")
	await _check_scene("res://main.tscn", 5, "fase")
	await _check_scene("res://scenes/start_screen.tscn", 5, "inicio")
	await _check_main_config()
	gs.reset_progress()
	if _fails == 0:
		print("ALL_SCENE_CHECKS_PASSED")
	else:
		printerr("SCENE_CHECKS_FAILED: ", _fails)
	tree.quit(_fails)


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_fails += 1
		printerr("FAIL: ", name)


func _check_autoload() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		printerr("FAIL: autoload GameState ausente no main loop")
		_fails += 1
		return
	_check(int(gs.MAX_LEVEL) == 300, "GameState.MAX_LEVEL == 300")
	_check((gs.AREAS as Array).size() == 5, "GameState.AREAS tem 5 areas")


func _check_areas() -> void:
	var gs = get_node("/root/GameState")
	var areas: Array = gs.AREAS
	var expect_from := 1
	for a in 5:
		var area: Dictionary = areas[a]
		_check(int(area["id"]) == a + 1, "area %d: id correto" % (a + 1))
		_check(int(area["from"]) == expect_from, "area %d: from=%d contiguo" % [a + 1, expect_from])
		var count: int = int(area["to"]) - int(area["from"]) + 1
		_check(count == 60, "area %d: 60 fases (%d-%d)" % [a + 1, int(area["from"]), int(area["to"])])
		expect_from = int(area["to"]) + 1
		_check((area["tasks"] as Array).size() == 8, "area %d: 8 tarefas" % (a + 1))
		var story_n: int = (area["story"] as Array).size()
		_check(story_n >= 6 and story_n <= 7, "area %d: story com %d falas (6-7)" % [a + 1, story_n])
		var intro_n: int = (area["intro"] as Array).size()
		if a == 0:
			_check(intro_n == 0, "area 1: intro vazio")
		else:
			_check(intro_n == 3, "area %d: intro com 3 falas" % (a + 1))
	_check(expect_from - 1 == 300, "areas cobrem as fases 1-300")
	_check(gs.area_of_level(1) == 1 and gs.area_of_level(60) == 1, "area_of_level: 1 e 60 -> area 1")
	_check(gs.area_of_level(61) == 2 and gs.area_of_level(300) == 5, "area_of_level: 61 -> 2, 300 -> 5")
	_check(gs.area_unlocked(1) and not gs.area_unlocked(2), "area 1 aberta, area 2 bloqueada no inicio")
	# get_level funciona em 1..300.
	for n in [1, 61, 150, 241, 300]:
		var cfg: Dictionary = gs.get_level(n)
		_check((cfg["goals"] as Dictionary).size() >= 1 and int(cfg["moves"]) > 0,
			"get_level(%d) valido" % n)


func _check_scene(path: String, min_nodes: int, name: String) -> void:
	var ps: PackedScene = load(path)
	var inst: Node = ps.instantiate()
	get_tree().root.add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	var total := _count_all(inst)
	if total < min_nodes:
		printerr("FAIL: cena ", name, " com poucos nos: ", total)
		_fails += 1
	else:
		print("PASS: cena ", name, " OK (", total, " nos)")
	inst.queue_free()


func _check_map_structure() -> void:
	var gs = get_node("/root/GameState")
	gs.current_area = 1
	var ps: PackedScene = load("res://scenes/level_map.tscn")
	var map = ps.instantiate()
	get_tree().root.add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(map._tab_buttons.size() == 5, "mapa: 5 abas")
	_check(map._nodes.size() == 60, "mapa: 60 nos na aba da area 1")
	_check(map._tab == 1, "mapa: aba inicial = area 1")
	# Troca para a aba 2 ainda bloqueada: nao troca, mostra toast.
	map._select_tab(2)
	await get_tree().process_frame
	_check(map._tab == 1, "mapa: aba bloqueada nao troca")
	_check(map._nodes.size() == 60, "mapa: nos mantidos apos toque em aba bloqueada")
	map.queue_free()


func _count_all(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count_all(ch)
	return c


func _check_main_config() -> void:
	var gs = get_node("/root/GameState")
	gs.current_level = 150
	var ps: PackedScene = load("res://main.tscn")
	var inst = ps.instantiate()
	get_tree().root.add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	var cfg: Dictionary = gs.get_level(150)
	var gt: Dictionary = inst.goal_targets
	var ok: bool = gt.size() == (cfg["goals"] as Dictionary).size()
	ok = ok and int(inst.moves) == int(cfg["moves"])
	for k in (cfg["goals"] as Dictionary).keys():
		ok = ok and int(gt.get(k, -1)) == int((cfg["goals"] as Dictionary)[k])
	_check(ok, "fase 150 carrega config do GameState.get_level(150)")
	gs.current_level = 1
	inst.queue_free()
