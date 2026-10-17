extends SceneTree
## Testes headless dos power-ups (criação, detecção, efeitos, combos).
## Roda com: godot --headless --path <projeto> --script res://tests/test_powerups.gd
## Saída: linhas PASS/FAIL + ALL_POWERUP_TESTS_PASSED; exit code = nº de falhas.
##
## Preenchimento seguro: (linha + 2*coluna) % 5 nunca forma 3 em sequência
## (horizontal: passos de +2 mod 5 são todos distintos; vertical: +1).

const ROWS := 8
const COLS := 8

var _failures := 0


func _init() -> void:
	var LogicScript := load("res://scripts/board_logic.gd")
	_t_creation_pipa(LogicScript)
	_t_creation_trovao(LogicScript)
	_t_creation_sol(LogicScript)
	_t_creation_gaivota(LogicScript)
	_t_no_creation_for_3(LogicScript)
	_t_powerups_dont_match(LogicScript)
	_t_powerup_on_board_is_a_move(LogicScript)
	_t_swap_square_valid(LogicScript)
	_t_trigger_pipa(LogicScript)
	_t_trigger_trovao(LogicScript)
	_t_trigger_chain(LogicScript)
	_t_trigger_sol(LogicScript)
	_t_combo_pipa_pipa(LogicScript)
	_t_combo_sol_sol(LogicScript)
	_t_remove_cells_counts_powerups(LogicScript)
	_t_trigger_produces_fx(LogicScript)
	_t_no_holes_after_powerups(LogicScript)
	if _failures == 0:
		print("ALL_POWERUP_TESTS_PASSED")
	else:
		printerr("POWERUP_TESTS_FAILED: ", _failures)
	quit(_failures)


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)


func _safe_fill(b) -> void:
	var g: Array = []
	for r in ROWS:
		var row: Array = []
		for c in COLS:
			row.append((r + 2 * c) % 5)
		g.append(row)
	b.grid = g


func _set_cells(b, cells: Array, t: int) -> void:
	for v in cells:
		var cell: Vector2i = v
		b.grid[cell.y][cell.x] = t


func _as_set(arr: Array) -> Dictionary:
	var d := {}
	for v in arr:
		d[v] = true
	return d


func _t_creation_pipa(LogicScript) -> void:
	var b = LogicScript.new(1)
	_safe_fill(b)
	_set_cells(b, [Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)], 1)
	b.grid[2][5] = 3 # quebra extensão (era 1)
	var expected := _as_set([Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)])
	_check(_as_set(b.find_matches()) == expected, "setup pipa: só o 4 em linha combina")
	var res: Dictionary = b.resolve_matches(Vector2i(2, 2))
	_check(int(res["created_ptype"]) == 10, "4 em linha cria PIPA")
	_check(int((res["removed"] as Array).size()) == 3, "criação remove as outras 3 peças")
	_check(b.get_type(res["created_at"]) == 10, "PIPA plantada no tabuleiro")


func _t_creation_trovao(LogicScript) -> void:
	var b = LogicScript.new(1)
	_safe_fill(b)
	_set_cells(b, [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
		Vector2i(2, 3), Vector2i(2, 4)], 2)
	b.grid[2][5] = 0 # quebra extensão horizontal (era 2)
	var expected := _as_set([Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
		Vector2i(2, 3), Vector2i(2, 4)])
	_check(_as_set(b.find_matches()) == expected, "setup trovão: só o L combina")
	var res: Dictionary = b.resolve_matches(Vector2i(2, 2))
	_check(int(res["created_ptype"]) == 12, "L de 5 cria TROVÃO")


func _t_creation_sol(LogicScript) -> void:
	var b = LogicScript.new(1)
	_safe_fill(b)
	_set_cells(b, [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4),
		Vector2i(4, 4), Vector2i(5, 4)], 3)
	b.grid[2][3] = 0 # quebra extensão vertical (era 3)
	b.grid[5][4] = 1 # quebra extensão vertical (era 3)
	var expected := _as_set([Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4),
		Vector2i(4, 4), Vector2i(5, 4)])
	_check(_as_set(b.find_matches()) == expected, "setup sol: só o 5 em linha combina")
	var res: Dictionary = b.resolve_matches(Vector2i(3, 4))
	_check(int(res["created_ptype"]) == 13, "5 em linha cria SOL")


func _t_creation_gaivota(LogicScript) -> void:
	var b = LogicScript.new(1)
	_safe_fill(b)
	_set_cells(b, [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4)], 1)
	b.grid[5][3] = 0 # quebra extensão vertical (era 1)
	_check(b.find_matches().is_empty(), "quadrado 2x2 não gera match (setup limpo)")
	_check(b.detect_square_at(Vector2i(3, 3)), "detecta quadrado 2x2 na célula")
	_check(not b.detect_square_at(Vector2i(0, 0)), "sem quadrado longe dali")
	var res: Dictionary = b.resolve_square(Vector2i(3, 3))
	_check(int(res["created_ptype"]) == 11, "quadrado cria GAIVOTA")
	_check(int((res["removed"] as Array).size()) == 3, "quadrado remove as outras 3 peças")
	_check(b.get_type(Vector2i(3, 3)) == 11, "GAIVOTA plantada na célula da troca")


func _t_no_creation_for_3(LogicScript) -> void:
	var b = LogicScript.new(1)
	_safe_fill(b)
	_set_cells(b, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], 4)
	var res: Dictionary = b.resolve_matches(Vector2i(1, 0))
	_check(int(res["created_ptype"]) == -1, "3 em linha não cria power-up")
	_check(int((res["removed"] as Array).size()) == 3, "3 em linha limpa as 3 peças")


func _t_powerups_dont_match(LogicScript) -> void:
	var b = LogicScript.new(1)
	_safe_fill(b)
	_set_cells(b, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], 10)
	_check(b.find_matches().is_empty(), "3 PIPAs em linha não combinam")
	_check(b.has_possible_move(), "has_possible_move continua ok")


func _t_powerup_on_board_is_a_move(LogicScript) -> void:
	var b = LogicScript.new(1)
	for r in ROWS:
		for c in COLS:
			b.grid[r][c] = 10
	_check(b.find_matches().is_empty(), "tabuleiro só de PIPAs: sem matches")
	_check(b.has_possible_move(), "power-up no tabuleiro conta como jogada")
	_check(not b.swap_creates_match(Vector2i(0, 0), Vector2i(1, 0)),
		"swap com power-up não conta como match")


func _t_swap_square_valid(LogicScript) -> void:
	var b = LogicScript.new(1)
	_safe_fill(b)
	# 2x2 quase completo em (0,0),(1,0),(0,1); (1,1)=3 e (2,1)=2.
	_set_cells(b, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)], 2)
	b.grid[1][1] = 3
	b.grid[1][2] = 2
	b.grid[2][0] = 0 # quebra 3 vertical acidental na coluna 0
	_check(not b.swap_creates_match(Vector2i(1, 1), Vector2i(2, 1)),
		"troca que completa quadrado não é match comum")
	_check(b.swap_is_valid_move(Vector2i(1, 1), Vector2i(2, 1)),
		"troca que completa quadrado é jogada válida")


func _t_trigger_pipa(LogicScript) -> void:
	var b = LogicScript.new(1)
	_safe_fill(b)
	b.grid[3][3] = 10
	var res: Dictionary = b.trigger_at(Vector2i(3, 3))
	_check(int((res["cells"] as Array).size()) == 15, "PIPA limpa linha+coluna (15 células)")


func _t_trigger_trovao(LogicScript) -> void:
	var b = LogicScript.new(1)
	_safe_fill(b)
	b.grid[3][3] = 12
	var res: Dictionary = b.trigger_at(Vector2i(3, 3))
	_check(int((res["cells"] as Array).size()) == 25, "TROVÃO limpa 5x5 (25 células)")


func _t_trigger_chain(LogicScript) -> void:
	var b = LogicScript.new(1)
	_safe_fill(b)
	b.grid[3][3] = 10 # PIPA em (3,3)
	b.grid[3][5] = 12 # TROVÃO em (5,3), na mesma linha
	var res: Dictionary = b.trigger_at(Vector2i(3, 3))
	# PIPA: linha 3 (8) + coluna 3 (8) - (3,3) = 15
	# TROVÃO em cadeia: 5x5 em (5,3) = 25; interseção com a PIPA = 9
	# total = 15 + 25 - 9 = 31
	_check(int((res["cells"] as Array).size()) == 31,
		"explosão atinge outro power-up e dispara em cadeia (31 células)")


func _t_trigger_sol(LogicScript) -> void:
	var b = LogicScript.new(1)
	for r in ROWS:
		for c in COLS:
			b.grid[r][c] = 1
	b.grid[0][0] = 13
	_set_cells(b, [Vector2i(7, 7), Vector2i(6, 6), Vector2i(5, 5),
		Vector2i(4, 4), Vector2i(3, 3)], 2)
	var res: Dictionary = b.trigger_sol_at(Vector2i(0, 0), 2)
	_check(int((res["cells"] as Array).size()) == 6,
		"SOL limpa as 5 peças da cor + a si mesmo")


func _t_combo_pipa_pipa(LogicScript) -> void:
	var b = LogicScript.new(1)
	_safe_fill(b)
	b.grid[3][3] = 10
	b.grid[4][3] = 10
	var res: Dictionary = b.combo_cells(Vector2i(3, 3), Vector2i(3, 4))
	# 3 linhas (24) + 3 colunas (24) - sobreposição 3x3 (9) = 39
	_check(int((res["cells"] as Array).size()) == 39,
		"Pipa+Pipa limpa 3 linhas + 3 colunas (39 células)")


func _t_combo_sol_sol(LogicScript) -> void:
	var b = LogicScript.new(1)
	_safe_fill(b)
	b.grid[0][0] = 13
	b.grid[1][0] = 13 # Vector2i(0,1): grid[linha][coluna]
	var res: Dictionary = b.combo_cells(Vector2i(0, 0), Vector2i(0, 1))
	_check(int((res["cells"] as Array).size()) == 64,
		"Sol+Sol limpa o tabuleiro inteiro")


func _t_remove_cells_counts_powerups(LogicScript) -> void:
	var b = LogicScript.new(1)
	_safe_fill(b)
	b.grid[0][0] = 10
	b.grid[1][0] = 12 # Vector2i(0,1): grid[linha][coluna]
	var counts: Array = b.remove_cells([Vector2i(0, 0), Vector2i(0, 1)])
	_check(int(counts[10]) == 1 and int(counts[12]) == 1,
		"remove_cells conta power-ups sem quebrar")
	_check(int(b.grid[0][0]) == -1, "célula esvaziada")


func _t_trigger_produces_fx(LogicScript) -> void:
	# Bug 2026-10-17: "não fez animação alguma". Garante que toda
	# ativação produz eventos de efeito para main.gd animar.
	for ptype in [10, 11, 12]:
		var b = LogicScript.new(7)
		_safe_fill(b)
		b.grid[3][3] = ptype
		var res: Dictionary = b.trigger_at(Vector2i(3, 3))
		_check(not (res["fx"] as Array).is_empty(),
			"trigger_at(%d) produz fx para animação" % ptype)
	var b2 = LogicScript.new(7)
	_safe_fill(b2)
	b2.grid[0][0] = 13
	var rs: Dictionary = b2.trigger_sol_at(Vector2i(0, 0), 1)
	_check(not (rs["fx"] as Array).is_empty(), "trigger_sol_at produz fx")
	var b3 = LogicScript.new(7)
	_safe_fill(b3)
	b3.grid[0][0] = 10
	b3.grid[1][0] = 10
	var rc: Dictionary = b3.combo_cells(Vector2i(0, 0), Vector2i(0, 1))
	_check(not (rc["fx"] as Array).is_empty(), "combo_cells produz fx")


func _count_empty(b) -> int:
	var n := 0
	for r in ROWS:
		for c in COLS:
			if int(b.grid[r][c]) == -1:
				n += 1
	return n


func _execute_trigger_flow(b, result: Dictionary) -> void:
	## Replica EXATAMENTE o pipeline de _execute_trigger em main.gd
	## (após o fix): remove -> gravidade SEMPRE -> cascatas.
	## Se main.gd mudar esse fluxo, este teste precisa acompanhar.
	b.remove_cells(result["cells"])
	b.apply_gravity()
	var guard := 0
	while guard < 20:
		guard += 1
		var r2: Dictionary = b.resolve_matches(Vector2i(-1, -1))
		if (r2["removed"] as Array).is_empty():
			break
		b.apply_gravity()


func _t_no_holes_after_powerups(LogicScript) -> void:
	# Bug 2026-10-17: explosão deixava buracos vazios no tabuleiro
	# porque a gravidade só rodava se houvesse match novo.
	for ptype in [10, 11, 12]:
		var b = LogicScript.new(99)
		_safe_fill(b)
		b.grid[3][3] = ptype
		_execute_trigger_flow(b, b.trigger_at(Vector2i(3, 3)))
		_check(_count_empty(b) == 0,
			"zero buracos após ativar power-up %d" % ptype)
	# Sol (via trigger_sol_at).
	var bs = LogicScript.new(99)
	_safe_fill(bs)
	bs.grid[0][0] = 13
	_execute_trigger_flow(bs, bs.trigger_sol_at(Vector2i(0, 0), 1))
	_check(_count_empty(bs) == 0, "zero buracos após ativar SOL")
	# Combos: Pipa+Pipa e Sol+Sol.
	for pair in [[10, 10], [13, 13], [10, 12], [11, 11]]:
		var bc = LogicScript.new(99)
		_safe_fill(bc)
		bc.grid[0][0] = pair[0]
		bc.grid[1][0] = pair[1]
		_execute_trigger_flow(bc, bc.combo_cells(Vector2i(0, 0), Vector2i(0, 1)))
		_check(_count_empty(bc) == 0,
			"zero buracos após combo %d+%d" % [pair[0], pair[1]])
