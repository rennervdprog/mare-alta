extends Node
## Check de cenas rodando no main loop NORMAL (com autoloads).
## Roda com: godot --headless --path <projeto> res://tests/scene_check.tscn
## Não commitar como cena do jogo: arquivo de verificação temporário.

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_autoload()
	await _check_scene("res://scenes/level_map.tscn", 12, "mapa")
	await _check_scene("res://scenes/renovation.tscn", 8, "renovacao")
	await _check_scene("res://main.tscn", 5, "fase")
	await _check_scene("res://scenes/start_screen.tscn", 5, "inicio")
	await _check_main_config()
	if _fails == 0:
		print("ALL_SCENE_CHECKS_PASSED")
	else:
		printerr("SCENE_CHECKS_FAILED: ", _fails)
	get_tree().quit(_fails)


func _check_autoload() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		printerr("FAIL: autoload GameState ausente no main loop")
		_fails += 1
	else:
		print("PASS: autoload GameState OK, fases=", gs.LEVELS.size())


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


func _count_all(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count_all(ch)
	return c


func _check_main_config() -> void:
	var gs = get_node("/root/GameState")
	gs.current_level = 5
	var ps: PackedScene = load("res://main.tscn")
	var inst = ps.instantiate()
	get_tree().root.add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	var gt: Dictionary = inst.goal_targets
	if int(gt.get(0, -1)) == 12 and int(gt.get(2, -1)) == 12 and gt.size() == 2 and inst.moves == 10:
		print("PASS: fase 5 carrega config (12 cocos + 12 chinelos, 10 mov)")
	else:
		printerr("FAIL: config da fase 5 errada: ", gt, " moves=", inst.moves)
		_fails += 1
	gs.current_level = 1
	inst.queue_free()
