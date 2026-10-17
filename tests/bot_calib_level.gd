extends SceneTree
## Calibragem por fase: mede win-rate do bot para (fase, limite de movimentos).
## Uso: godot --headless --path <projeto> --script res://tests/bot_calib_level.gd -- <fase 1-10> <limite> [jogos=100]
## Bot guloso igual a tests/bot_calib.gd (com o fix do snapshot no Sol+X),
## mas com metas genéricas {type_id: alvo} vindas do GameState.

var tie_rng := RandomNumberGenerator.new()
var MOVE_LIMIT := -1
var LEVEL_IDX := 1
var GAMES := 100
var GOALS := {} # type_id -> alvo


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("ERRO: uso -- <fase 1-10> <limite> [jogos]")
		quit(1)
		return
	LEVEL_IDX = int(args[0])
	MOVE_LIMIT = int(args[1])
	if args.size() > 2:
		GAMES = int(args[2])
	var GS := load("res://scripts/game_state.gd")
	var cfg: Dictionary = GS.new().get_level(LEVEL_IDX)
	GOALS = cfg["goals"]
	var LogicScript := load("res://scripts/board_logic.gd")
	var wins := 0
	for g in GAMES:
		tie_rng.seed = 5000 + g * 7919
		var r: Dictionary = _play_game(LogicScript, 3000 + g)
		if bool(r["won"]):
			wins += 1
	print("CALIB level=%d limit=%d games=%d wins=%d winrate=%.1f%%" % [
		LEVEL_IDX, MOVE_LIMIT, GAMES, wins, 100.0 * float(wins) / float(GAMES)])
	quit(0)


func _play_game(LogicScript, seed_value: int) -> Dictionary:
	var logic = LogicScript.new(seed_value)
	logic.goal_types = GOALS.keys()
	var counts := {}
	for t in GOALS.keys():
		counts[t] = 0
	var moves := 0
	var guard := 0
	while not _goals_met(counts) and moves < MOVE_LIMIT:
		guard += 1
		if guard > 800:
			break
		if not logic.has_possible_move():
			logic.new_board()
			continue
		var action: Dictionary = _best_action(LogicScript, logic)
		if action.is_empty():
			break
		_exec_action(logic, action, counts)
		moves += 1
	return {"won": _goals_met(counts), "moves": moves}


func _goals_met(counts: Dictionary) -> bool:
	for t in GOALS.keys():
		if int(counts[t]) < int(GOALS[t]):
			return false
	return true


func _best_action(S, logic) -> Dictionary:
	var best: Array = []
	var best_n := -1
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
						est += 3
				logic.swap_cells(cell, nb)
				if est > best_n:
					best_n = est
					best = [{"kind": "swap", "a": cell, "b": nb}]
				elif est == best_n:
					best.append({"kind": "swap", "a": cell, "b": nb})
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
				var snap: Array = logic.grid.duplicate(true)
				var res: Dictionary = logic.trigger_at(cell)
				var est2 := (res["cells"] as Array).size()
				logic.grid = snap
				if est2 > best_n:
					best_n = est2
					best = [{"kind": "trigger", "cell": cell}]
				elif est2 == best_n:
					best.append({"kind": "trigger", "cell": cell})
	for cell in power_cells:
		var pc: Vector2i = cell
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var nb: Vector2i = pc + d
			if not logic.in_bounds(nb):
				continue
			if int(logic.grid[nb.y][nb.x]) < S.P_PIPA:
				continue
			var snap: Array = logic.grid.duplicate(true)
			var res2: Dictionary = logic.combo_cells(pc, nb)
			var est3 := (res2["cells"] as Array).size()
			logic.grid = snap
			if est3 > best_n:
				best_n = est3
				best = [{"kind": "combo", "a": pc, "b": nb}]
			elif est3 == best_n:
				best.append({"kind": "combo", "a": pc, "b": nb})
	if best.is_empty():
		return {}
	return best[tie_rng.randi_range(0, best.size() - 1)]


func _exec_action(logic, action: Dictionary, counts: Dictionary) -> void:
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
		_resolve(logic, a, sq, counts)
	elif kind == "trigger":
		var res: Dictionary = logic.trigger_at(action["cell"])
		_apply_cleared(logic, res["cells"], counts)
		_resolve(logic, Vector2i(-1, -1), Vector2i(-1, -1), counts)
	elif kind == "sol":
		var res2: Dictionary = logic.trigger_sol_at(action["cell"], int(action["color"]))
		_apply_cleared(logic, res2["cells"], counts)
		_resolve(logic, Vector2i(-1, -1), Vector2i(-1, -1), counts)
	elif kind == "combo":
		var res3: Dictionary = logic.combo_cells(action["a"], action["b"])
		_apply_cleared(logic, res3["cells"], counts)
		_resolve(logic, Vector2i(-1, -1), Vector2i(-1, -1), counts)


func _apply_cleared(logic, cells: Array, counts: Dictionary) -> void:
	var cc: Array = logic.remove_cells(cells)
	for t in counts.keys():
		counts[t] = int(counts[t]) + int(cc[int(t)])
	logic.apply_gravity()


func _resolve(logic, preferred: Vector2i, sq_cell: Vector2i, counts: Dictionary) -> void:
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
		var cc: Array = res["counts"]
		for t in counts.keys():
			counts[t] = int(counts[t]) + int(cc[int(t)])
		logic.apply_gravity()
