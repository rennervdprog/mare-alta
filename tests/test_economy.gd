extends SceneTree
## Testes da economia: vidas (regen offline-first), moedas, continuar, configs.
## Roda com: godot --headless --path <projeto> --script res://tests/test_economy.gd
## Usa user://test_economy.cfg para não tocar no save real.

const BASE := 1700000000 # unix time fixo p/ simular o relógio

var _failures := 0
var GS := load("res://scripts/game_state.gd")


func _init() -> void:
	_t_lives_regen_full()
	_t_lives_regen_partial()
	_t_lives_legacy_no_credit()
	_t_lose_life_from_full()
	_t_lose_life_empty()
	_t_time_to_next_and_display()
	_t_can_play()
	_t_spend_coins()
	_t_spend_insufficient()
	_t_add_coins_persist()
	_t_win_reward()
	_t_settings_persist()
	_t_reset()
	_t_cloud_roundtrip()
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("test_economy.cfg"):
		dir.remove("test_economy.cfg")
	if _failures == 0:
		print("ALL_ECONOMY_TESTS_PASSED")
	else:
		printerr("ECONOMY_TESTS_FAILED: ", _failures)
	quit(_failures)


func _new_gs():
	var gs = GS.new()
	gs.save_path = "user://test_economy.cfg"
	return gs


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)


func _t_lives_regen_full() -> void:
	var gs = _new_gs()
	gs.lives = 3
	gs.lives_ts = BASE - 2 * 20 * 60 - 30 # 2 intervalos cheios + 30s
	_check(gs.refresh_lives(BASE) == 5, "vidas: regen credita e capa no máximo")
	_check(gs.lives_ts == 0, "vidas: ts zera quando chega ao máximo")


func _t_lives_regen_partial() -> void:
	var gs = _new_gs()
	gs.lives = 3
	gs.lives_ts = BASE - 20 * 60 - 30 # 1 intervalo + 30s de resto
	_check(gs.refresh_lives(BASE) == 4, "vidas: regen parcial +1")
	_check(gs.lives_ts == BASE - 30, "vidas: resto de 30s preservado no ts")


func _t_lives_legacy_no_credit() -> void:
	var gs = _new_gs()
	gs.lives = 3
	gs.lives_ts = 0 # save antigo sem timestamp
	_check(gs.refresh_lives(BASE) == 3, "vidas: save antigo não ganha crédito grátis")
	_check(gs.lives_ts == BASE, "vidas: save antigo começa a contar agora")


func _t_lose_life_from_full() -> void:
	var gs = _new_gs()
	gs.lives = 5
	gs.lives_ts = 0
	_check(gs.lose_life(BASE) == true, "vidas: perde 1 quando cheio")
	_check(gs.lives == 4, "vidas: 5 -> 4")
	_check(gs.lives_ts == BASE, "vidas: timer começa na derrota")


func _t_lose_life_empty() -> void:
	var gs = _new_gs()
	gs.lives = 0
	gs.lives_ts = BASE
	_check(gs.lose_life(BASE) == false, "vidas: sem vidas não perde")
	_check(gs.lives == 0, "vidas: continua 0")


func _t_time_to_next_and_display() -> void:
	var gs = _new_gs()
	gs.lives = 5
	gs.lives_ts = 0
	_check(gs.time_to_next_life(BASE) == 0, "vidas: cheio -> 0s")
	_check(gs.lives_display(BASE) == "Cheio", "vidas: display 'Cheio'")
	gs.lives = 4
	gs.lives_ts = BASE - 90
	_check(gs.time_to_next_life(BASE) == 20 * 60 - 90, "vidas: 1110s p/ próxima")
	_check(gs.lives_display(BASE) == "18:30", "vidas: display mm:ss")


func _t_can_play() -> void:
	var gs = _new_gs()
	gs.lives = 0
	gs.lives_ts = BASE
	_check(gs.can_play(BASE) == false, "vidas: 0 vidas não pode jogar")
	gs.lives_ts = BASE - 25 * 60 # passou 1 intervalo
	_check(gs.can_play(BASE) == true, "vidas: regen libera o jogo")
	_check(gs.lives == 1, "vidas: 1 vida creditada")


func _t_spend_coins() -> void:
	var gs = _new_gs()
	gs.coins = 50
	_check(gs.spend_coins(40) == true, "moedas: gasta 40 de 50")
	_check(gs.coins == 10, "moedas: saldo 10")


func _t_spend_insufficient() -> void:
	var gs = _new_gs()
	gs.coins = 10
	_check(gs.spend_coins(40) == false, "moedas: sem saldo não gasta")
	_check(gs.coins == 10, "moedas: saldo intacto")


func _t_add_coins_persist() -> void:
	var a = _new_gs()
	a.coins = 120
	a.add_coins(20, "win")
	var b = _new_gs()
	b.load_game()
	_check(b.coins == 140, "moedas: add persiste no save")


func _t_win_reward() -> void:
	var gs = _new_gs()
	gs.coins = 120
	gs.on_level_won(1)
	_check(gs.coins == 120 + gs.COIN_WIN_REWARD, "moedas: vitória paga COIN_WIN_REWARD")
	_check(gs.COIN_WIN_REWARD == 20 and gs.CONTINUE_COST == 40 and gs.CONTINUE_MOVES == 5,
		"economia: constantes (20/40/5)")


func _t_settings_persist() -> void:
	var a = _new_gs()
	a.set_opt("sound", false)
	a.set_opt("music", false)
	_check(a.opt_sound == false and a.opt_music == false, "configs: toggles mudam")
	var b = _new_gs()
	b.load_game()
	_check(b.opt_sound == false and b.opt_music == false and b.opt_notifications == true,
		"configs: persistem no save")


func _t_reset() -> void:
	var gs = _new_gs()
	gs.lives = 2
	gs.lives_ts = BASE
	gs.coins = 999
	gs.set_opt("sound", false)
	gs.reset_progress()
	_check(gs.lives == 5 and gs.lives_ts == 0, "reset: vidas voltam ao máximo")
	_check(gs.coins == 120, "reset: moedas voltam a 120")
	_check(gs.opt_sound == true, "reset: configs voltam ao padrão")


func _t_cloud_roundtrip() -> void:
	var a = _new_gs()
	a.lives = 3
	a.lives_ts = BASE - 100
	a.set_opt("music", false)
	var data: Dictionary = a.get_cloud_data()
	var b = _new_gs()
	b.apply_cloud_data(data)
	_check(b.lives == 3 and b.lives_ts == BASE - 100, "nuvem: vidas viajam")
	_check(b.opt_music == false, "nuvem: configs viajam")
