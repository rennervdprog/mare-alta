extends SceneTree
## Smoke de calibragem: garante que as fases 1-5 continuam vencíveis pelo bot
## nos alvos de onboarding (1-3: 98-100%, 4-5: 93-96%).
## Usa as MESMAS seeds de tests/bot_calib_level.gd e lê os movimentos da config
## real (GameState.LEVELS): se alguém apertar os movimentos, este teste quebra.
## 15 jogos/fase, determinístico, rápido.
## Roda com: godot --headless --path <projeto> --script res://tests/test_calib_smoke.gd

const GAMES := 15
# Vitórias mínimas esperadas (medidas em 2026-10-17; determinístico).
const MIN_WINS := {1: 15, 2: 15, 3: 15, 4: 14, 5: 15}

var tie_rng := RandomNumberGenerator.new()
var _failures := 0
var _LogicScript = null
var _GOALS := {}


func _init() -> void:
	_LogicScript = load("res://scripts/board_logic.gd")
	var GS := load("res://scripts/game_state.gd")
	var gs = GS.new()
	for level in [1, 2, 3, 4, 5]:
		var cfg: Dictionary = gs.get_level(level)
		_GOALS = cfg["goals"]
		var wins := 0
		for g in GAMES:
			tie_rng.seed = 5000 + g * 7919
			if bool(_play_game(3000 + g, int(cfg["moves"]))["won"]):
				wins += 1
		var need: int = MIN_WINS[level]
		if wins >= need:
			print("PASS: fase %d: bot %d/%d (alvo >= %d)" % [level, wins, GAMES, need])
		else:
			_failures += 1
			printerr("FAIL: fase %d: bot %d/%d (alvo >= %d)" % [level, wins, GAMES, need])
	if _failures == 0:
		print("ALL_CALIB_SMOKE_PASSED")
	else:
		printerr("CALIB_SMOKE_FAILED: ", _failures)
	quit(_failures)


func _play_game(seed_value: int, move_limit: int) -> Dictionary:
	var logic = _LogicScript.new(seed_value)
	logic.goal_types = _GOALS.keys()
	var counts := {}
	for t in _GOALS.keys():
		counts[t] = 0
	var moves := 0
	var guard := 0
	while not _goals_met(counts) and moves < move_limit:
		guard += 1
		if guard > 800:
			break
		if not logic.has_possible_move():
			logic.new_board()
			continue
		var action: Dictionary = _best_action(logic)
		if action.is_empty():
			break
		_exec_action(logic, action, counts)
		moves += 1
	return {"won": _goals_met(counts)}


func _goals_met(counts: Dictionary) -> bool:
	for t in _GOALS.keys():
		if int(counts[t]) < int(_GOALS[t]):
			return false
	return true


func _best_action(logic) -> Dictionary:
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
			if t < 10 or t > 13:
				continue
			power_cells.append(cell)
			if t == 13: # P_SOL
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
			if int(logic.grid[nb.y][nb.x]) < 10:
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
		_apply_cleared(logic, (logic.trigger_at(action["cell"])["cells"]) as Array, counts)
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
