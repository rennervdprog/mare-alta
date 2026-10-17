extends SceneTree
## Testes headless do find_hint (board_logic.gd) — sistema de dica.
## Roda com: godot --headless --path <projeto> --script res://tests/test_hint.gd
## Saída: linhas PASS/FAIL + ALL_HINT_TESTS_PASSED; exit code = nº de falhas.

const ROWS := 8
const COLS := 8

var _failures := 0


func _init() -> void:
	var LogicScript := load("res://scripts/board_logic.gd")
	_t_hint_legal(LogicScript)
	_t_hint_prefers_goal(LogicScript)
	_t_hint_powerup_tap(LogicScript)
	_t_hint_never_empty(LogicScript)
	if _failures == 0:
		print("ALL_HINT_TESTS_PASSED")
	else:
		printerr("HINT_TESTS_FAILED: ", _failures)
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


func _hint_is_legal(b, h: Dictionary) -> bool:
	if h.is_empty():
		return false
	var a: Vector2i = h["a"]
	var bb: Vector2i = h["b"]
	if a == bb:
		return b.is_powerup(int(b.grid[a.y][a.x]))
	return b.swap_is_valid_move(a, bb)


func _t_hint_legal(LogicScript) -> void:
	# Em tabuleiros frescos, a dica sempre sugere um movimento legal.
	for seed_value in [1, 2, 3, 42, 777]:
		var b = LogicScript.new(seed_value)
		b.goal_types = [0, 4]
		var h: Dictionary = b.find_hint()
		_check(_hint_is_legal(b, h), "dica é movimento legal (seed %d)" % seed_value)


func _t_hint_prefers_goal(LogicScript) -> void:
	# Tabuleiro com 2 jogadas: uma forma match de cocos (meta), outra de
	# peixes (fora da meta). A dica deve preferir a da meta.
	var b = LogicScript.new(1)
	_clean_grid(b)
	b.goal_types = [0] # só coco conta
	# Jogada da meta: linha 0 = [0,0,1,0,...] -> trocar (2,0)<->(3,0) = 3 cocos.
	b.grid[0][0] = 0
	b.grid[0][1] = 0
	b.grid[0][2] = 1
	b.grid[0][3] = 0
	# Jogada fora da meta: linha 5 = [3,3,1,3,...] -> trocar (2,5)<->(3,5).
	b.grid[5][0] = 3
	b.grid[5][1] = 3
	b.grid[5][2] = 1
	b.grid[5][3] = 3
	_check(b.find_matches().is_empty(), "tabuleiro de teste sem matches iniciais")
	var h: Dictionary = b.find_hint()
	_check(not h.is_empty() and h["a"] != h["b"], "dica sugere uma troca")
	if h.is_empty() or h["a"] == h["b"]:
		return
	# Simula a troca sugerida e verifica se o match inclui peça da meta.
	var sim = b.clone()
	sim.swap_cells(h["a"], h["b"])
	var goal_hit := false
	for v in sim.find_matches():
		var mc: Vector2i = v
		if int(sim.grid[mc.y][mc.x]) == 0:
			goal_hit = true
			break
	if not goal_hit:
		# Pode ser quadrado 2x2: checa o tipo do quadrado.
		var sq := Vector2i(-1, -1)
		if sim.detect_square_at(h["a"]):
			sq = h["a"]
		elif sim.detect_square_at(h["b"]):
			sq = h["b"]
		if sq.x >= 0 and int(sim.grid[sq.y][sq.x]) == 0:
			goal_hit = true
	_check(goal_hit, "dica prefere movimento que inclui peça da meta")


func _t_hint_powerup_tap(LogicScript) -> void:
	# Sem troca legal mas com power-up: a dica é tocar nele (a == b).
	var b = LogicScript.new(1)
	var g: Array = []
	for r in ROWS:
		var row: Array = []
		for c in COLS:
			row.append(-1) # EMPTY em tudo
		g.append(row)
	b.grid = g
	b.grid[3][3] = 10 # P_PIPA
	var h: Dictionary = b.find_hint()
	_check(h.get("a") == Vector2i(3, 3) and h.get("b") == Vector2i(3, 3),
		"dica sugere toque no power-up quando não há troca")


func _t_hint_never_empty(LogicScript) -> void:
	# new_board garante >= 1 jogada: a dica nunca vem vazia nesses casos.
	for seed_value in range(1, 11):
		var b = LogicScript.new(seed_value)
		_check(not (b.find_hint() as Dictionary).is_empty(),
			"dica nunca vazia em tabuleiro fresco (seed %d)" % seed_value)
