extends SceneTree
## Calibragem de dificuldade com LIMITE de movimentos: mede win-rate do bot
## para um limite fixo (argumento de linha de comando após `--`).
## Uso: godot --headless --path <projeto> --script res://tests/bot_calib.gd -- 12
## Heurística gulosa igual a tests/bot_sim.gd, + contagem de power-ups criados.
## FIX vs bot_sim.gd: combo_cells (Sol+X) MUTA o grid; aqui o grid é
## restaurado após cada avaliação para não corromper o tabuleiro.

const GOAL_COCO := 20
const GOAL_CONCHA := 20
const GAMES := 200
const GUARD := 800

var tie_rng := RandomNumberGenerator.new()
var MOVE_LIMIT := -1
var powerups_created := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		MOVE_LIMIT = int(args[0])
	if MOVE_LIMIT < 1:
		print("ERRO: informe o limite de movimentos apos -- (ex.: -- 12)")
		quit(1)
		return
	var LogicScript := load("res://scripts/board_logic.gd")
	var wins := 0
	var total_spare := 0
	var max_spare := 0
	var total_coco_short := 0
	var total_concha_short := 0
	var max_coco_short := 0
	var max_concha_short := 0
	var total_powerups := 0
	for g in GAMES:
		tie_rng.seed = 9000 + g
		powerups_created = 0
		var r: Dictionary = _play_game(LogicScript, 1000 + g)
		total_powerups += powerups_created
		if bool(r["won"]):
			wins += 1
			var spare := MOVE_LIMIT - int(r["moves"])
			total_spare += spare
			max_spare = maxi(max_spare, spare)
		else:
			var cs := maxi(0, GOAL_COCO - int(r["coco"]))
			var hs := maxi(0, GOAL_CONCHA - int(r["concha"]))
			total_coco_short += cs
			total_concha_short += hs
			max_coco_short = maxi(max_coco_short, cs)
			max_concha_short = maxi(max_concha_short, hs)
	var losses := GAMES - wins
	print("CALIB_STATS limit=%d games=%d wins=%d winrate=%.1f%% avg_spare=%.2f max_spare=%d avg_coco_short=%.2f max_coco_short=%d avg_concha_short=%.2f max_concha_short=%d avg_powerups=%.2f" % [
		MOVE_LIMIT, GAMES, wins, 100.0 * float(wins) / float(GAMES),
		float(total_spare) / float(maxi(wins, 1)), max_spare,
		float(total_coco_short) / float(maxi(losses, 1)), max_coco_short,
		float(total_concha_short) / float(maxi(losses, 1)), max_concha_short,
		float(total_powerups) / float(GAMES)])
	quit(0)


func _play_game(LogicScript, seed_value: int) -> Dictionary:
	var logic = LogicScript.new(seed_value)
	var goals := [0, 0] # [cocos, conchas]
	var moves := 0
	var guard := 0
	while (goals[0] < GOAL_COCO or goals[1] < GOAL_CONCHA) and moves < MOVE_LIMIT:
		guard += 1
		if guard > GUARD:
			break
		if not logic.has_possible_move():
			logic.new_board() # igual ao jogo: reshuffle sem custar movimento
			continue
		var action: Dictionary = _best_action(LogicScript, logic)
		if action.is_empty():
			break
		_exec_action(logic, action, goals)
		moves += 1
	var won: bool = goals[0] >= GOAL_COCO and goals[1] >= GOAL_CONCHA
	return {"won": won, "moves": moves, "coco": goals[0], "concha": goals[1]}


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
	# 3. Combos: pares adjacentes de power-ups. (combo_cells MUTA o grid no
	# caso Sol+X -> restaura snapshot após cada avaliação.)
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
		if int(res["created_ptype"]) != -1:
			powerups_created += 1
		var removed: Array = res["removed"]
		if removed.is_empty():
			break
		var counts: Array = res["counts"]
		goals[0] += int(counts[0])
		goals[1] += int(counts[4])
		logic.apply_gravity()
