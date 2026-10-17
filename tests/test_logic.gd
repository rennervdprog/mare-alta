extends SceneTree
## Testes headless da BoardLogic (lógica pura do match-3).
## Roda com: godot --headless --path <projeto> --script res://tests/test_logic.gd
## Saída: linhas PASS/FAIL + ALL_LOGIC_TESTS_PASSED; exit code = nº de falhas.

const ROWS := 8
const COLS := 8

var _failures := 0


func _init() -> void:
	var LogicScript := load("res://scripts/board_logic.gd")
	_t_no_initial_matches(LogicScript)
	_t_find_matches(LogicScript)
	_t_swap_creates_match(LogicScript)
	_t_gravity(LogicScript)
	_t_full_resolve(LogicScript)
	_t_possible_move(LogicScript)
	if _failures == 0:
		print("ALL_LOGIC_TESTS_PASSED")
	else:
		printerr("LOGIC_TESTS_FAILED: ", _failures)
	quit(_failures)


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)


func _clean_grid(b) -> void:
	# Padrão (r+c)%5: garantido sem matches horizontais/verticais.
	var g: Array = []
	for r in ROWS:
		var row: Array = []
		for c in COLS:
			row.append((r + c) % 5)
		g.append(row)
	b.grid = g


func _t_no_initial_matches(LogicScript) -> void:
	for seed_value in [1, 2, 3, 42, 777]:
		var b = LogicScript.new(seed_value)
		_check(b.find_matches().is_empty(), "sem matches iniciais (seed %d)" % seed_value)
		_check(b.has_possible_move(), "jogada possível no tabuleiro inicial (seed %d)" % seed_value)


func _t_find_matches(LogicScript) -> void:
	var b = LogicScript.new(1)
	_clean_grid(b)
	b.grid[0][0] = 2
	b.grid[0][1] = 2
	b.grid[0][2] = 2
	var m: Array = b.find_matches()
	_check(m.has(Vector2i(0, 0)) and m.has(Vector2i(1, 0)) and m.has(Vector2i(2, 0)),
		"match horizontal de 3 detectado")
	b.grid[3][5] = 4
	b.grid[4][5] = 4
	b.grid[5][5] = 4
	m = b.find_matches()
	_check(m.has(Vector2i(5, 3)) and m.has(Vector2i(5, 4)) and m.has(Vector2i(5, 5)),
		"match vertical de 3 detectado")


func _t_swap_creates_match(LogicScript) -> void:
	var b = LogicScript.new(1)
	_clean_grid(b)
	# Linha 0: [1, 0, 1, 1, ...] -> trocar (0,0)<->(1,0) forma 1,1,1 nas cols 1-3.
	b.grid[0][0] = 1
	b.grid[0][1] = 0
	b.grid[0][2] = 1
	b.grid[0][3] = 1
	_check(b.swap_creates_match(Vector2i(0, 0), Vector2i(1, 0)), "swap válido detectado")
	_check(int(b.grid[0][0]) == 1 and int(b.grid[0][1]) == 0,
		"swap_creates_match não altera o tabuleiro")
	# (6,0)=1,(7,0)=2 no padrão limpo: trocar não forma nada.
	_check(not b.swap_creates_match(Vector2i(6, 0), Vector2i(7, 0)), "swap inválido rejeitado")


func _t_gravity(LogicScript) -> void:
	var b = LogicScript.new(1)
	_clean_grid(b)
	var before: Array = []
	for r in 5:
		before.append(int(b.grid[r][0]))
	for r in [5, 6, 7]:
		b.grid[r][0] = -1
	var falls: Array = b.apply_gravity()
	var ok := true
	for i in 5:
		if int(b.grid[3 + i][0]) != int(before[i]):
			ok = false
	_check(ok, "gravidade compacta a coluna preservando a ordem")
	var any_empty := false
	for r in ROWS:
		for c in COLS:
			if int(b.grid[r][c]) == -1:
				any_empty = true
	_check(not any_empty, "sem buracos após a gravidade")
	var new_count := 0
	var moved_count := 0
	for f in falls:
		if int(f["col"]) == 0:
			if bool(f["is_new"]):
				new_count += 1
			else:
				moved_count += 1
	_check(new_count == 3 and moved_count == 5, "gravidade: 5 caíram + 3 novas na coluna 0")


func _t_full_resolve(LogicScript) -> void:
	var b = LogicScript.new(1)
	_clean_grid(b)
	b.grid[0][0] = 3
	b.grid[0][1] = 3
	b.grid[0][2] = 3
	b.grid[4][4] = 0
	b.grid[5][4] = 0
	b.grid[6][4] = 0
	var total := 0
	var guard := 0
	while guard < 50:
		guard += 1
		var m: Array = b.find_matches()
		if m.is_empty():
			break
		total += m.size()
		b.remove_cells(m)
		b.apply_gravity()
	_check(b.find_matches().is_empty(), "cascatas resolvem até não restar match")
	_check(total >= 6, "todas as peças dos matches foram removidas")
	var any_empty := false
	for r in ROWS:
		for c in COLS:
			if int(b.grid[r][c]) == -1:
				any_empty = true
	_check(not any_empty, "tabuleiro íntegro após cascatas")


func _t_possible_move(LogicScript) -> void:
	var b = LogicScript.new(99)
	_check(b.has_possible_move(), "tabuleiro aleatório tem jogada possível")
	var dead = null
	for s in 500:
		var t = LogicScript.new(1000 + s)
		if not t.has_possible_move():
			dead = t
			break
	if dead == null:
		print("SKIP: nenhum tabuleiro sem jogadas em 500 tentativas")
		return
	_check(not dead.has_possible_move(), "detecta tabuleiro sem jogadas possíveis")
	dead.new_board()
	_check(dead.has_possible_move() and dead.find_matches().is_empty(),
		"reshuffle gera tabuleiro válido e jogável")
