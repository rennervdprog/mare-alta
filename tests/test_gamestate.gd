extends SceneTree
## Testes headless do GameState (save/load, estrelas, desbloqueio, tarefas, baú).
## Roda com: godot --headless --path <projeto> --script res://tests/test_gamestate.gd
## Usa user://test_save.cfg para não tocar no save real.

var _failures := 0
var GS := load("res://scripts/game_state.gd")


func _init() -> void:
	_t_save_load_roundtrip()
	_t_star_only_first_win()
	_t_unlock_progression()
	_t_spend_star()
	_t_tasks()
	_t_chest()
	_t_level_configs()
	# Limpa o save de teste.
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("test_save.cfg"):
		dir.remove("test_save.cfg")
	if _failures == 0:
		print("ALL_GAMESTATE_TESTS_PASSED")
	else:
		printerr("GAMESTATE_TESTS_FAILED: ", _failures)
	quit(_failures)


func _new_gs():
	var gs = GS.new()
	gs.save_path = "user://test_save.cfg"
	return gs


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)


func _t_save_load_roundtrip() -> void:
	var a = _new_gs()
	a.stars = 7
	a.coins = 350
	a.unlocked_level = 4
	a.levels_won = {1: true, 2: true}
	a.tasks_done = ["task_rubble"]
	a.chest_claimed = true
	a.save_game()
	var b = _new_gs()
	b.load_game()
	_check(b.stars == 7, "save/load: stars")
	_check(b.coins == 350, "save/load: coins")
	_check(b.unlocked_level == 4, "save/load: unlocked_level")
	_check(b.level_won_before(1) and b.level_won_before(2) and not b.level_won_before(3), "save/load: levels_won")
	_check(b.task_done("task_rubble") and not b.task_done("task_deck"), "save/load: tasks_done")
	_check(b.chest_claimed, "save/load: chest_claimed")


func _t_star_only_first_win() -> void:
	var gs = _new_gs()
	gs.reset_progress()
	_check(gs.on_level_won(1) == true, "primeira vitoria da estrela")
	_check(gs.stars == 1, "estrela somada na 1a vitoria")
	_check(gs.on_level_won(1) == false, "segunda vitoria nao da estrela")
	_check(gs.stars == 1, "estrela nao duplica")
	_check(gs.on_level_won(2) == true, "vitoria em outra fase da estrela")
	_check(gs.stars == 2, "duas estrelas de duas fases")


func _t_unlock_progression() -> void:
	var gs = _new_gs()
	gs.reset_progress()
	_check(gs.unlocked_level == 1, "comeca na fase 1")
	gs.on_level_won(1)
	_check(gs.unlocked_level == 2, "vencer fase 1 desbloqueia fase 2")
	gs.on_level_won(2)
	_check(gs.unlocked_level == 3, "vencer fase 2 desbloqueia fase 3")
	gs.on_level_won(10)
	_check(gs.unlocked_level == 11, "vencer fase 10 desbloqueia fase 11 (teto agora é 300)")
	gs.on_level_won(300)
	_check(gs.unlocked_level == 300, "nao passa da fase 300")


func _t_spend_star() -> void:
	var gs = _new_gs()
	gs.reset_progress()
	gs.stars = 2
	_check(gs.spend_star() == true, "gastar estrela com saldo")
	_check(gs.stars == 1, "estrela consumida")
	gs.stars = 0
	_check(gs.spend_star() == false, "gastar estrela sem saldo falha")
	_check(gs.stars == 0, "saldo nao fica negativo")


func _t_tasks() -> void:
	var gs = _new_gs()
	gs.reset_progress()
	gs.complete_task("task_deck")
	_check(gs.task_done("task_deck"), "tarefa marcada")
	gs.complete_task("task_deck")
	_check(gs.tasks_done.size() == 1, "tarefa nao duplica")


func _t_chest() -> void:
	var gs = _new_gs()
	gs.reset_progress()
	_check(not gs.chest_claimed, "bau comeca fechado")
	gs.add_coins(100)
	gs.claim_chest()
	_check(gs.coins == 220, "moedas do bau somadas")
	_check(gs.chest_claimed, "bau marcado como resgatado")


func _t_level_configs() -> void:
	var gs = _new_gs()
	var l1: Dictionary = gs.get_level(1)
	_check(int((l1["goals"] as Dictionary)[0]) == 10 and (l1["goals"] as Dictionary).size() == 1, "fase 1: 10 cocos")
	_check(int(l1["moves"]) == 9, "fase 1: 9 movimentos (recalibrada: bot 99%)")
	var l10: Dictionary = gs.get_level(10)
	_check(int((l10["goals"] as Dictionary)[0]) == 20 and int((l10["goals"] as Dictionary)[4]) == 20, "fase 10: 20 cocos + 20 conchas")
	_check(int(l10["moves"]) == 11, "fase 10: 11 movimentos")
	var l5: Dictionary = gs.get_level(5)
	_check((l5["goals"] as Dictionary).has(2), "fase 5 inclui chinelo (tipo 2)")
	_check(int(GS.TYPE_IDS["guarda_sol"]) == 1, "TYPE_IDS: guarda_sol = 1")
