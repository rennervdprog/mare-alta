extends SceneTree
## Gerador + calibragem das fases 11-300 do MARÉ ALTA.
##
## MODO CALIB (gera metas determinísticas + calibra movimentos com o bot):
##   godot --headless --path <proj> --script res://tests/gen_levels.gd -- calib [from=11] [to=300] [K=30]
## MODO SPOTCHECK (100 jogos com o limite final em cada 10a fase, lendo o GameState):
##   godot --headless --path <proj> --script res://tests/gen_levels.gd -- spotcheck
##
## Metas: gerador determinístico (seed 424242 + nível*131), 1-2 tipos de peça,
## variando os 5 tipos entre fases (sem repetir a assinatura da fase anterior).
## Calibragem: K jogos SEM limite de movimentos; movimentos =
## ceil(percentil(dist, alvo_wr)) + 1, mínimo 6.
## Bot: heurística gulosa de tests/bot_calib_level.gd (que por sua vez deriva de
## tests/bot_calib.gd, com o fix do snapshot no combo Sol+X). NÃO usa bot_sim.gd.
##
## Saídas do modo calib (uma por intervalo, p/ rodar faixas em paralelo):
##   /tmp/levels_snippet_<from>_<to>.txt  (linhas prontas p/ a const LEVELS)
##   /tmp/levels_gen_<from>_<to>.jsonl    (resumo por fase p/ o relatório)

const GEN_SEED := 424242
const K_DEFAULT := 30
const GUARD := 3000
const NO_LIMIT := 100000

const TYPE_NAMES := ["coco", "guarda_sol", "chinelo", "peixe", "concha"]
const TYPE_IDS := {"coco": 0, "guarda_sol": 1, "chinelo": 2, "peixe": 3, "concha": 4}

var tie_rng := RandomNumberGenerator.new()
var LogicScript = null
var K := K_DEFAULT


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("ERRO: uso -- calib [from] [to] [K] | spotcheck")
		quit(1)
		return
	LogicScript = load("res://scripts/board_logic.gd")
	if args[0] == "calib":
		var from := 11
		var to := 300
		if args.size() > 1:
			from = int(args[1])
		if args.size() > 2:
			to = int(args[2])
		if args.size() > 3:
			K = int(args[3])
		_run_calib(from, to)
	elif args[0] == "spotcheck":
		_run_spotcheck()
	else:
		print("ERRO: modo desconhecido: ", args[0])
		quit(1)
		return
	quit(0)


# ------------------------------------------------------------ faixas/alvos

func _band_of(level: int) -> String:
	if level <= 30:
		return "11-30"
	if level <= 60:
		return "31-60"
	if level <= 120:
		return "61-120"
	if level <= 200:
		return "121-200"
	return "201-300"


func _is_breather(level: int) -> bool:
	match _band_of(level):
		"61-120":
			return (level - 61) % 10 == 5
		"121-200":
			return (level - 121) % 8 == 4
		"201-300":
			# Nunca 3 fases <88% seguidas: respiro a cada 3.
			return (level - 201) % 3 == 2
	return false


func _target_of(level: int) -> int:
	var band := _band_of(level)
	if _is_breather(level):
		match band:
			"61-120":
				return 97
			"121-200":
				return 96
			_:
				return 95
	match band:
		"11-30":
			return 97
		"31-60":
			return 94
		"61-120":
			return 91
		"121-200":
			return 88
	return 86


# ------------------------------------------------------------ gerador de metas

func _pick_type(rng: RandomNumberGenerator, exclude: Array) -> String:
	var opts: Array = []
	for t in TYPE_NAMES:
		if not exclude.has(t):
			opts.append(t)
	return opts[rng.randi_range(0, opts.size() - 1)]


func _pick_two_types(rng: RandomNumberGenerator) -> Array:
	var a := _pick_type(rng, [])
	var b := _pick_type(rng, [a])
	return [a, b]


func _maybe_swap_pair(rng: RandomNumberGenerator, names: Array, amounts: Array) -> void:
	if rng.randi_range(0, 1) == 1:
		var tn = names[0]
		names[0] = names[1]
		names[1] = tn
		var ta = amounts[0]
		amounts[0] = amounts[1]
		amounts[1] = ta


func _goal_signature(names: Array, amounts: Array) -> String:
	var pairs: Array = []
	for i in names.size():
		pairs.append("%s:%d" % [names[i], int(amounts[i])])
	pairs.sort()
	return "|".join(pairs)


func _gen_goals_raw(level: int, prev_sig: String, prev_names: Array) -> Dictionary:
	## Função pura do nível (RNG próprio): mesmo resultado independente de
	## fatiamento. `prev_sig`/`prev_names` evitam repetir a fase anterior.
	var rng := RandomNumberGenerator.new()
	rng.seed = GEN_SEED + level * 131
	var band := _band_of(level)
	var breather := _is_breather(level)
	var names: Array = []
	var amounts: Array = []
	for _attempt in 12:
		names = []
		amounts = []
		if breather:
			var lo := 15
			var hi := 20
			match band:
				"121-200":
					lo = 20
					hi = 25
				"201-300":
					lo = 25
					hi = 30
			names = [_pick_type(rng, [])]
			amounts = [rng.randi_range(lo, hi)]
		else:
			match band:
				"11-30":
					if rng.randi_range(0, 1) == 0:
						names = [_pick_type(rng, [])]
						amounts = [rng.randi_range(10, 18)]
					else:
						names = _pick_two_types(rng)
						amounts = [8, 8]
						_maybe_swap_pair(rng, names, amounts)
				"31-60":
					if rng.randi_range(0, 1) == 0:
						names = [_pick_type(rng, [])]
						amounts = [rng.randi_range(15, 25)]
					else:
						names = _pick_two_types(rng)
						amounts = [rng.randi_range(10, 15), rng.randi_range(10, 12)]
						_maybe_swap_pair(rng, names, amounts)
				"61-120":
					if rng.randi_range(0, 99) < 60:
						names = _pick_two_types(rng)
						amounts = [rng.randi_range(12, 20), rng.randi_range(12, 15)]
						_maybe_swap_pair(rng, names, amounts)
					else:
						names = [_pick_type(rng, [])]
						amounts = [rng.randi_range(20, 30)]
				"121-200":
					if rng.randi_range(0, 99) < 60:
						names = _pick_two_types(rng)
						amounts = [rng.randi_range(15, 25), rng.randi_range(15, 20)]
						_maybe_swap_pair(rng, names, amounts)
					else:
						names = [_pick_type(rng, [])]
						amounts = [rng.randi_range(25, 35)]
				_: # "201-300"
					if rng.randi_range(0, 99) < 60:
						names = _pick_two_types(rng)
						amounts = [rng.randi_range(20, 30), rng.randi_range(20, 25)]
						_maybe_swap_pair(rng, names, amounts)
					else:
						names = [_pick_type(rng, [])]
						amounts = [rng.randi_range(30, 40)]
		# Variação: não repete a assinatura da fase anterior; meta única não
		# repete o tipo da meta única anterior.
		if _goal_signature(names, amounts) == prev_sig:
			continue
		if names.size() == 1 and prev_names.size() == 1 and names[0] == prev_names[0]:
			continue
		break
	return {"names": names, "amounts": amounts}


func _gen_goals(level: int) -> Dictionary:
	var prev_names: Array = []
	var prev_sig := ""
	if level == 11:
		# Fase 10 real (mantida intacta): 20 cocos + 20 conchas.
		prev_names = ["coco", "concha"]
		prev_sig = "coco:20|concha:20"
	elif level > 11:
		var prev := _gen_goals_raw(level - 1, "", [])
		prev_names = prev["names"]
		prev_sig = _goal_signature(prev["names"], prev["amounts"])
	return _gen_goals_raw(level, prev_sig, prev_names)


func _snippet_line(level: int, names: Array, amounts: Array, moves: int, target: int) -> String:
	var order: Array = names.duplicate()
	order.sort_custom(func(a, b): return int(TYPE_IDS[a]) < int(TYPE_IDS[b]))
	var parts: Array = []
	for n in order:
		parts.append('"%s": %d' % [n, int(amounts[names.find(n)])])
	var tag := "alvo bot %d%%" % target
	if _is_breather(level):
		tag += " respiro"
	return '\t{"goals": {%s}, "moves": %d},  # %d - %s' % [", ".join(parts), moves, level, tag]


# ------------------------------------------------------------ modo calib

func _run_calib(from: int, to: int) -> void:
	var snip_path := "/tmp/levels_snippet_%d_%d.txt" % [from, to]
	var json_path := "/tmp/levels_gen_%d_%d.jsonl" % [from, to]
	var f_snip := FileAccess.open(snip_path, FileAccess.WRITE)
	var f_json := FileAccess.open(json_path, FileAccess.WRITE)
	if f_snip == null or f_json == null:
		print("ERRO: nao abri arquivos de saida em /tmp")
		quit(1)
		return
	print("GEN_INICIO faixas %d-%d K=%d" % [from, to, K])
	for level in range(from, to + 1):
		var g := _gen_goals(level)
		var names: Array = g["names"]
		var amounts: Array = g["amounts"]
		var target := _target_of(level)
		var goals := {}
		for i in names.size():
			goals[int(TYPE_IDS[names[i]])] = int(amounts[i])
		var cal := _calibrate(goals, target, level)
		var moves: int = cal["moves"]
		var line := _snippet_line(level, names, amounts, moves, target)
		f_snip.store_line(line)
		f_json.store_line(JSON.stringify({
			"level": level, "band": _band_of(level), "breather": _is_breather(level),
			"names": names, "amounts": amounts, "moves": moves, "target": target,
			"degraded": bool(cal["degraded"]), "snippet": line,
		}))
		f_snip.flush()
		f_json.flush()
		print("GEN faixa=%s fase=%d metas=%s mov=%d alvo=%d%% respiro=%s%s" % [
			_band_of(level), level, _goal_signature(names, amounts), moves, target,
			str(_is_breather(level)), " DEGRADED" if bool(cal["degraded"]) else ""])
	f_snip.close()
	f_json.close()
	print("GEN_FIM faixas %d-%d -> %s" % [from, to, snip_path])


func _calibrate(goals: Dictionary, target: int, level: int) -> Dictionary:
	var needs: Array = []
	var degraded := false
	for gi in K:
		tie_rng.seed = 5000 + gi * 7919
		var r := _play_game(3000 + gi, goals, NO_LIMIT)
		var mv := int(r["moves"])
		if mv < 0:
			# Guard estourou (não deveria acontecer): tenta outra seed.
			tie_rng.seed = 5000 + (gi + 100003) * 7919
			r = _play_game(3000 + gi + 100003, goals, NO_LIMIT)
			mv = int(r["moves"])
			degraded = true
			print("GEN_GUARD fase=%d jogo=%d (retry)" % [level, gi])
		if mv < 0:
			mv = 200
			degraded = true
			print("GEN_GUARD_DUPLo fase=%d jogo=%d (usando 200)" % [level, gi])
		needs.append(mv)
	needs.sort()
	var idx := clampi(int(ceil(target / 100.0 * float(K))) - 1, 0, K - 1)
	var moves := maxi(6, int(needs[idx]) + 1)
	return {"moves": moves, "degraded": degraded}


# ------------------------------------------------------------ modo spotcheck

func _run_spotcheck() -> void:
	var GS := load("res://scripts/game_state.gd")
	var gs = GS.new()
	var band_n := {}
	var band_sum := {}
	var fails := 0
	var level := 20
	print("SPOT_INICIO (100 jogos/fase, limite final do GameState)")
	while level <= 300:
		var cfg: Dictionary = gs.get_level(level)
		var goals: Dictionary = cfg["goals"]
		var limit := int(cfg["moves"])
		var target := _target_of(level)
		var wins := 0
		for gi in 100:
			tie_rng.seed = 5000 + gi * 7919
			if bool(_play_game(3000 + gi, goals, limit)["won"]):
				wins += 1
		var wr := float(wins)
		var ok := wr >= float(target) - 7.0
		if not ok:
			fails += 1
		var band := _band_of(level)
		band_n[band] = int(band_n.get(band, 0)) + 1
		band_sum[band] = float(band_sum.get(band, 0.0)) + wr
		print("SPOT fase=%d mov=%d alvo=%d wr=%.0f%% %s" % [level, limit, target, wr, "OK" if ok else "WARN"])
		level += 10
	for band in ["11-30", "31-60", "61-120", "121-200", "201-300"]:
		if band_n.has(band):
			print("SPOT_BAND %s n=%d wr_media=%.1f%%" % [band, int(band_n[band]), float(band_sum[band]) / float(band_n[band])])
	if fails == 0:
		print("SPOTCHECK_PASSED")
	else:
		print("SPOTCHECK_WARN: %d fases fora da faixa" % fails)


# ------------------------------------------------------------ bot (cópia de bot_calib_level.gd)

func _play_game(seed_value: int, goals: Dictionary, move_limit: int) -> Dictionary:
	var logic = LogicScript.new(seed_value)
	logic.goal_types = goals.keys()
	var counts := {}
	for t in goals.keys():
		counts[t] = 0
	var moves := 0
	var guard := 0
	while not _goals_met(goals, counts) and moves < move_limit:
		guard += 1
		if guard > GUARD:
			return {"won": false, "moves": -1}
		if not logic.has_possible_move():
			logic.new_board()
			continue
		var action: Dictionary = _best_action(LogicScript, logic)
		if action.is_empty():
			break
		_exec_action(logic, action, counts)
		moves += 1
	return {"won": _goals_met(goals, counts), "moves": moves}


func _goals_met(goals: Dictionary, counts: Dictionary) -> bool:
	for t in goals.keys():
		if int(counts[t]) < int(goals[t]):
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
