extends SceneTree
## Calibragem de dificuldade (Fase 2): robô guloso joga N partidas headless.
## Heurística: avalia todas as ações possíveis e executa a de maior valor
## IMEDIATO (desempate aleatório), conta 1 movimento:
##  - trocas normais: nº de peças do match (+4 se completa 2x2, +3 se cria power-up)
##  - power-up individual: nº de células que o disparo limpa (com reações em cadeia)
##  - Sol: melhor cor (1 + nº de peças da cor)
##  - combos: nº de células do combo
## Resolve cascatas com criação de power-ups, igual ao jogo real.
## Espelha o jogo real: reshuffle (new_board) sem custo quando sem jogadas.
## Roda com: godot --headless --path <projeto> --script res://tests/bot_sim.gd

const GOAL_COCO := 20
const GOAL_CONCHA := 20
const GAMES := 200
const GUARD := 800

var tie_rng := RandomNumberGenerator.new()


func _init() -> void:
	var LogicScript := load("res://scripts/board_logic.gd")
	var results: Array = []
	var incomplete := 0
	for g in GAMES:
		tie_rng.seed = 9000 + g
		var moves_needed := _play_game(LogicScript, 1000 + g)
		if moves_needed < 0:
			incomplete += 1
		else:
			results.append(moves_needed)
	results.sort()
	var n := results.size()
	var total := 0
	for v in results:
		total += int(v)
	var mean := float(total) / float(maxi(n, 1))
	var median := 0.0
	if n > 0:
		if n % 2 == 1:
			median = float(results[n / 2])
		else:
			median = (float(results[n / 2 - 1]) + float(results[n / 2])) / 2.0
	var p90 := 0
	if n > 0:
		p90 = int(results[mini(int(n * 0.9), n - 1)])
	print("BOT_STATS games=%d completed=%d incomplete=%d mean=%.2f median=%.2f min=%d max=%d p90=%d" % [
		GAMES, n, incomplete, mean, median,
		int(results[0]) if n > 0 else -1,
		int(results[n - 1]) if n > 0 else -1, p90])
	if n > 0:
		var dec := PackedStringArray()
		for k in range(1, 10):
			dec.append(str(int(results[mini(int(n * k / 10), n - 1)])))
		print("BOT_DECILES d10..d90: ", ",".join(dec))
	quit(0)


func _play_game(LogicScript, seed_value: int) -> int:
	var logic = LogicScript.new(seed_value)
	var goals := [0, 0] # [cocos, conchas]
	var moves := 0
	var guard := 0
	while goals[0] < GOAL_COCO or goals[1] < GOAL_CONCHA:
		guard += 1
		if guard > GUARD:
			return -1
		if not logic.has_possible_move():
			logic.new_board() # igual ao jogo: reshuffle sem custar movimento
			continue
		var action: Dictionary = _best_action(LogicScript, logic)
		if action.is_empty():
			return -1
		_exec_action(logic, action, goals)
		moves += 1
	return moves


func _best_action(S, logic) -> Dictionary:
	var best: Array = []
	var best_n := -1
	# 1. Trocas entre peças normais.
	for r in 8:
		for c in 8:
			var cell := Vector2i(c, r)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var nb: Vector2i = cell + d
				if not logic.in_bounds(nb):
					continue
				if not logic.swap_is_valid_move(cell, nb):
					continue
				logic.swap_cells(cell, nb)
				var dm: Array = logic.find_matches()
				var sq: bool = logic.detect_square_at(cell) or logic.detect_square_at(nb)
				var est := dm.size()
				if sq:
					est += 4
				if not dm.is_empty():
					var dc: Dictionary = logic.detect_creation(dm, cell)
					if not dc.is_empty():
						est += 3 # bônus: power-up criado vale jogadas futuras
				logic.swap_cells(cell, nb)
				if est > best_n:
					best_n = est
					best = [{"kind": "swap", "a": cell, "b": nb}]
				elif est == best_n:
					best.append({"kind": "swap", "a": cell, "b": nb})
	# 2. Power-ups individuais (+ Sol avaliado pela melhor cor).
	var power_cells: Array = []
	for r in 8:
		for c in 8:
			var cell := Vector2i(c, r)
			var t := int(logic.grid[r][c])
			if t < S.P_PIPA or t > S.P_SOL:
				continue
			power_cells.append(cell)
			if t == S.P_SOL:
				var color_counts := [0, 0, 0, 0, 0]
				for rr in 8:
					for cc in 8:
						var u := int(logic.grid[rr][cc])
						if u >= 0 and u <= 4:
							color_counts[u] += 1
				var best_c := 0
				for color in 5:
					if int(color_counts[color]) > int(color_counts[best_c]):
						best_c = color
				var est := 1 + int(color_counts[best_c])
				if est > best_n:
					best_n = est
					best = [{"kind": "sol", "cell": cell, "color": best_c}]
				elif est == best_n:
					best.append({"kind": "sol", "cell": cell, "color": best_c})
			else:
				var res: Dictionary = logic.trigger_at(cell)
				var est2 := (res["cells"] as Array).size()
				if est2 > best_n:
					best_n = est2
					best = [{"kind": "trigger", "cell": cell}]
				elif est2 == best_n:
					best.append({"kind": "trigger", "cell": cell})
	# 3. Combos: pares adjacentes de power-ups.
	for cell in power_cells:
		var pc: Vector2i = cell
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var nb: Vector2i = pc + d
			if not logic.in_bounds(nb):
				continue
			if int(logic.grid[nb.y][nb.x]) < S.P_PIPA:
				continue
			var res2: Dictionary = logic.combo_cells(pc, nb)
			var est3 := (res2["cells"] as Array).size()
			if est3 > best_n:
				best_n = est3
				best = [{"kind": "combo", "a": pc, "b": nb}]
			elif est3 == best_n:
				best.append({"kind": "combo", "a": pc, "b": nb})
	if best.is_empty():
		return {}
	var pick: Dictionary = best[tie_rng.randi_range(0, best.size() - 1)]
	return pick


func _exec_action(logic, action: Dictionary, goals: Array) -> void:
	var kind: String = action["kind"]
	if kind == "swap":
		var a: Vector2i = action["a"]
		var b: Vector2i = action["b"]
		logic.swap_cells(a, b)
		var sq := Vector2i(-1, -1)
		if logic.detect_square_at(a):
			sq = a
		elif logic.detect_square_at(b):
			sq = b
		_resolve(logic, a, sq, goals)
	elif kind == "trigger":
		var res: Dictionary = logic.trigger_at(action["cell"])
		_apply_cleared(logic, res["cells"], goals)
		_resolve(logic, Vector2i(-1, -1), Vector2i(-1, -1), goals)
	elif kind == "sol":
		var res2: Dictionary = logic.trigger_sol_at(action["cell"], int(action["color"]))
		_apply_cleared(logic, res2["cells"], goals)
		_resolve(logic, Vector2i(-1, -1), Vector2i(-1, -1), goals)
	elif kind == "combo":
		var res3: Dictionary = logic.combo_cells(action["a"], action["b"])
		_apply_cleared(logic, res3["cells"], goals)
		_resolve(logic, Vector2i(-1, -1), Vector2i(-1, -1), goals)


func _apply_cleared(logic, cells: Array, goals: Array) -> void:
	var counts: Array = logic.remove_cells(cells)
	goals[0] += int(counts[0]) # coco
	goals[1] += int(counts[4]) # concha
	logic.apply_gravity()


func _resolve(logic, preferred: Vector2i, sq_cell: Vector2i, goals: Array) -> void:
	## Cascatas com criação de power-ups (espelha _resolve_cascades do jogo).
	var first := true
	var sq := sq_cell
	while true:
		var res: Dictionary
		if first and sq.x >= 0:
			res = logic.resolve_square(sq)
			sq = Vector2i(-1, -1)
		else:
			res = logic.resolve_matches(preferred if first else Vector2i(-1, -1))
		first = false
		var removed: Array = res["removed"]
		if removed.is_empty():
			break
		var counts: Array = res["counts"]
		goals[0] += int(counts[0])
		goals[1] += int(counts[4])
		logic.apply_gravity()
