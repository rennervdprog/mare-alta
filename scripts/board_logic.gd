class_name BoardLogic
extends RefCounted
## Modelo PURO do tabuleiro match-3 (sem nenhuma renderização).
## Permite testar toda a regra do jogo de forma headless.
##
## Convenções:
## - grid[linha][coluna] -> int
##   - 0..TYPES-1 : peça normal (cor)
##   - P_PIPA/P_GAIVOTA/P_TROVAO/P_SOL : power-up
##   - EMPTY (-1) : vazio
## - células como Vector2i(coluna, linha)

const ROWS: int = 8
const COLS: int = 8
const TYPES: int = 5
const EMPTY: int = -1

# Power-ups (valores altos para nunca colidir com índices de cor).
const P_PIPA: int = 10
const P_GAIVOTA: int = 11
const P_TROVAO: int = 12
const P_SOL: int = 13

var grid: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Tipos de peça que contam para a meta (usado pela Gaivota). Ex.: [0, 4].
var goal_types: Array = [0, 4]


func _init(seed_value: int = 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	new_board()


func is_powerup(t: int) -> bool:
	return t >= 10


func is_normal(t: int) -> bool:
	return t >= 0 and t < TYPES


func clone() -> BoardLogic:
	var b := BoardLogic.new(1)
	b.grid = grid.duplicate(true)
	b.goal_types = goal_types.duplicate()
	return b


func new_board() -> void:
	## Preenche o tabuleiro só com peças normais, sem combinações prontas
	## e com pelo menos 1 jogada.
	for _attempt in 200:
		_fill_no_matches()
		if has_possible_move():
			return


func _fill_no_matches() -> void:
	grid.clear()
	for r in ROWS:
		var row: Array = []
		row.resize(COLS)
		for c in COLS:
			row[c] = _pick_type_avoiding_match(r, c, row)
		grid.append(row)


func _pick_type_avoiding_match(r: int, c: int, current_row: Array) -> int:
	var forbidden := {}
	if c >= 2 and int(current_row[c - 1]) == int(current_row[c - 2]):
		forbidden[int(current_row[c - 1])] = true
	if r >= 2 and int(grid[r - 1][c]) == int(grid[r - 2][c]):
		forbidden[int(grid[r - 1][c])] = true
	for _i in 30:
		var t := rng.randi_range(0, TYPES - 1)
		if not forbidden.has(t):
			return t
	return rng.randi_range(0, TYPES - 1)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS


func get_type(cell: Vector2i) -> int:
	return int(grid[cell.y][cell.x])


func are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


func swap_cells(a: Vector2i, b: Vector2i) -> void:
	var tmp: int = grid[a.y][a.x]
	grid[a.y][a.x] = grid[b.y][b.x]
	grid[b.y][b.x] = tmp


func find_matches() -> Array:
	## Retorna Array de Vector2i(coluna, linha) com todas as células em
	## sequências de 3+ PEÇAS NORMAIS iguais (power-ups nunca combinam).
	var matched := {}
	# Horizontal (por linha).
	for r in ROWS:
		var c := 0
		while c < COLS:
			var t: int = grid[r][c]
			if t == EMPTY or is_powerup(t):
				c += 1
				continue
			var run := 1
			while c + run < COLS and int(grid[r][c + run]) == t:
				run += 1
			if run >= 3:
				for k in run:
					matched[Vector2i(c + k, r)] = true
			c += run
	# Vertical (por coluna).
	for c in COLS:
		var r := 0
		while r < ROWS:
			var t: int = grid[r][c]
			if t == EMPTY or is_powerup(t):
				r += 1
				continue
			var run := 1
			while r + run < ROWS and int(grid[r + run][c]) == t:
				run += 1
			if run >= 3:
				for k in run:
					matched[Vector2i(c, r + k)] = true
			r += run
	return matched.keys()


func swap_creates_match(a: Vector2i, b: Vector2i) -> bool:
	## Testa sem efeitos colaterais: troca, verifica, desfaz.
	## Trocas envolvendo power-up NÃO contam aqui (têm regra própria).
	if not (in_bounds(a) and in_bounds(b)):
		return false
	if is_powerup(int(grid[a.y][a.x])) or is_powerup(int(grid[b.y][b.x])):
		return false
	swap_cells(a, b)
	var ok := not find_matches().is_empty()
	swap_cells(a, b)
	return ok


func has_possible_move() -> bool:
	## Existe jogada se houver power-up no tabuleiro (toque = jogada)
	## Existe jogada se houver power-up no tabuleiro (toque = jogada),
	## alguma troca que forme combinação, ou troca que complete um 2x2.
	for r in ROWS:
		for c in COLS:
			if is_powerup(int(grid[r][c])):
				return true
	for r in ROWS:
		for c in COLS:
			var cell := Vector2i(c, r)
			var right := Vector2i(c + 1, r)
			var down := Vector2i(c, r + 1)
			if in_bounds(right) and _swap_valid_normal(cell, right):
				return true
			if in_bounds(down) and _swap_valid_normal(cell, down):
				return true
	return false


func _swap_valid_normal(a: Vector2i, b: Vector2i) -> bool:
	## Troca entre peças normais: vale se formar match OU completar 2x2.
	swap_cells(a, b)
	var ok := not find_matches().is_empty()
	if not ok:
		ok = detect_square_at(a) or detect_square_at(b)
	swap_cells(a, b)
	return ok


func find_hint() -> Dictionary:
	## Sugestão de movimento para o sistema de dica (idle hint).
	## Retorna {"a": Vector2i, "b": Vector2i} com uma troca legal,
	## PREFERINDO trocas cujo match/quadrado inclua peça da meta
	## (goal_types). Se não houver troca legal mas existir power-up no
	## tabuleiro, retorna {"a": c, "b": c} (a dica é tocar nele).
	## Retorna {} se não houver nenhum movimento (jogo embaralha).
	var best: Array = []
	var best_score := 0
	for r in ROWS:
		for c in COLS:
			var cell := Vector2i(c, r)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var nb: Vector2i = cell + d
				if not in_bounds(nb):
					continue
				if not _swap_valid_normal(cell, nb):
					continue
				var score := 1
				swap_cells(cell, nb)
				var goal_hit := false
				for v in find_matches():
					var mc: Vector2i = v
					if goal_types.has(int(grid[mc.y][mc.x])):
						goal_hit = true
						break
				if not goal_hit:
					# Quadrado 2x2 não gera match: checa o tipo do quadrado.
					var sq := Vector2i(-1, -1)
					if detect_square_at(cell):
						sq = cell
					elif detect_square_at(nb):
						sq = nb
					if sq.x >= 0 and goal_types.has(int(grid[sq.y][sq.x])):
						goal_hit = true
				swap_cells(cell, nb)
				if goal_hit:
					score = 2
				if score > best_score:
					best_score = score
					best = [{"a": cell, "b": nb}]
				elif score == best_score:
					best.append({"a": cell, "b": nb})
	if not best.is_empty():
		var pick: Dictionary = best[rng.randi_range(0, best.size() - 1)]
		return pick
	# Sem troca legal: sugere tocar num power-up, se houver.
	for r in ROWS:
		for c in COLS:
			if is_powerup(int(grid[r][c])):
				var pc := Vector2i(c, r)
				return {"a": pc, "b": pc}
	return {}


func swap_is_valid_move(a: Vector2i, b: Vector2i) -> bool:
	## Para o bot: vale para pares normais (match ou quadrado).
	## Pares com power-up têm fluxo próprio e retornam false aqui.
	if not (in_bounds(a) and in_bounds(b)):
		return false
	if is_powerup(int(grid[a.y][a.x])) or is_powerup(int(grid[b.y][b.x])):
		return false
	return _swap_valid_normal(a, b)


func detect_square_at(cell: Vector2i) -> bool:
	## True se `cell` faz parte de um quadrado 2x2 de peças normais iguais.
	var t := int(grid[cell.y][cell.x])
	if not is_normal(t):
		return false
	return _in_square(cell, t)


func remove_cells(cells: Array) -> Array:
	## Marca células como EMPTY. Retorna Array[int] indexado pelo tipo
	## (0..TYPES-1 normais; 10..13 power-ups) com a contagem removida.
	var counts: Array = []
	counts.resize(16)
	counts.fill(0)
	for v in cells:
		var cell: Vector2i = v
		var t: int = grid[cell.y][cell.x]
		if t != EMPTY:
			counts[t] = int(counts[t]) + 1
			grid[cell.y][cell.x] = EMPTY
	return counts


func apply_gravity() -> Array:
	## Compacta cada coluna para baixo e preenche o topo com peças NOVAS
	## (sempre normais). Power-ups caem como peças comuns.
	## Retorna Array de Dicionários para animação:
	## {col, from_row, to_row, ptype, is_new}
	## from_row < 0 indica peça nova (nasce acima do tabuleiro).
	var moves: Array = []
	for c in COLS:
		var existing: Array = [] # pares [tipo, linha_origem], de baixo p/ cima
		for r in range(ROWS - 1, -1, -1):
			var t: int = grid[r][c]
			if t != EMPTY:
				existing.append([t, r])
		var new_col: Array = []
		new_col.resize(ROWS)
		new_col.fill(EMPTY)
		var r := ROWS - 1
		for e in existing:
			var t: int = e[0]
			var from_r: int = e[1]
			new_col[r] = t
			if from_r != r:
				moves.append({"col": c, "from_row": from_r, "to_row": r, "ptype": t, "is_new": false})
			r -= 1
		var spawn_k := 0
		while r >= 0:
			var t := rng.randi_range(0, TYPES - 1)
			new_col[r] = t
			moves.append({"col": c, "from_row": -1 - spawn_k, "to_row": r, "ptype": t, "is_new": true})
			spawn_k += 1
			r -= 1
		for rr in ROWS:
			grid[rr][c] = new_col[rr]
	return moves


# ------------------------------------------------------------ criação

func _run_len(cell: Vector2i, dir: Vector2i, t: int) -> int:
	var n := 0
	var c := cell
	while in_bounds(c) and int(grid[c.y][c.x]) == t:
		n += 1
		c += dir
	return n


func _in_square(cell: Vector2i, t: int) -> bool:
	for oy in [0, -1]:
		for ox in [0, -1]:
			var ok := true
			for dy in 2:
				for dx in 2:
					var cc := Vector2i(cell.x + ox + dx, cell.y + oy + dy)
					if not in_bounds(cc) or int(grid[cc.y][cc.x]) != t:
						ok = false
						break
				if not ok:
					break
			if ok:
				return true
	return false


func detect_creation(matched: Array, preferred: Vector2i) -> Dictionary:
	## Dada a lista de células combinadas, decide se nasce um power-up.
	## Retorna {"ptype": P_*, "at": Vector2i} ou {} se não houver criação.
	## Regras: 5 em linha -> SOL; L/T (3+3) -> TROVÃO; 4 em linha -> PIPA;
	## quadrado 2x2 -> GAIVOTA. `preferred` = célula da troca (se válida).
	var mset := {}
	for v in matched:
		mset[v] = true
	var candidates: Array = []
	if preferred.x >= 0 and mset.has(preferred):
		candidates = [preferred]
	else:
		candidates = matched
	var best := {}
	var best_prio := 0
	for v in candidates:
		var cell: Vector2i = v
		var t := int(grid[cell.y][cell.x])
		if not is_normal(t):
			continue
		var h := _run_len(cell, Vector2i(1, 0), t) + _run_len(cell, Vector2i(-1, 0), t) - 1
		var vv := _run_len(cell, Vector2i(0, 1), t) + _run_len(cell, Vector2i(0, -1), t) - 1
		var ptype := -1
		var prio := 0
		if h >= 5 or vv >= 5:
			ptype = P_SOL
			prio = 4
		elif h >= 3 and vv >= 3:
			ptype = P_TROVAO
			prio = 3
		elif h == 4 or vv == 4:
			ptype = P_PIPA
			prio = 2
		elif _in_square(cell, t):
			ptype = P_GAIVOTA
			prio = 1
		if prio > best_prio:
			best_prio = prio
			best = {"ptype": ptype, "at": cell}
	return best


func resolve_matches(preferred: Vector2i) -> Dictionary:
	## UMA passada de resolução: encontra matches, detecta criação de
	## power-up, remove as demais células e planta o power-up no tabuleiro.
	## Retorna {"counts": Array, "removed": Array, "created_ptype": int,
	##          "created_at": Vector2i}.
	var counts: Array = []
	counts.resize(16)
	counts.fill(0)
	var matched: Array = find_matches()
	if matched.is_empty():
		return {"counts": counts, "removed": [], "created_ptype": -1,
			"created_at": Vector2i(-1, -1)}
	var creation := detect_creation(matched, preferred)
	var keep := Vector2i(-1, -1)
	var ctype := -1
	if not creation.is_empty():
		keep = creation["at"]
		ctype = int(creation["ptype"])
	var to_remove: Array = []
	for v in matched:
		if v != keep:
			to_remove.append(v)
	counts = remove_cells(to_remove)
	if ctype != -1:
		grid[keep.y][keep.x] = ctype
	return {"counts": counts, "removed": to_remove, "created_ptype": ctype,
		"created_at": keep}


func resolve_square(cell: Vector2i) -> Dictionary:
	## Resolve a criação de GAIVOTA a partir de um quadrado 2x2 contendo
	## `cell` (o 2x2 não gera match de 3, então tem fluxo próprio).
	## Remove as outras 3 células e planta a GAIVOTA em `cell`.
	var counts: Array = []
	counts.resize(16)
	counts.fill(0)
	var empty := {"counts": counts, "removed": [], "created_ptype": -1,
		"created_at": Vector2i(-1, -1)}
	var t := int(grid[cell.y][cell.x])
	if not is_normal(t):
		return empty
	for oy in [0, -1]:
		for ox in [0, -1]:
			var cells: Array = []
			var ok := true
			for dy in 2:
				for dx in 2:
					var cc := Vector2i(cell.x + ox + dx, cell.y + oy + dy)
					if not in_bounds(cc) or int(grid[cc.y][cc.x]) != t:
						ok = false
						break
					cells.append(cc)
				if not ok:
					break
			if ok:
				var to_remove: Array = []
				for cc2 in cells:
					if cc2 != cell:
						to_remove.append(cc2)
				counts = remove_cells(to_remove)
				grid[cell.y][cell.x] = P_GAIVOTA
				return {"counts": counts, "removed": to_remove,
					"created_ptype": P_GAIVOTA, "created_at": cell}
	return empty


# ------------------------------------------------------------ efeitos

func _most_common_color() -> int:
	var cnt := [0, 0, 0, 0, 0]
	for r in ROWS:
		for c in COLS:
			var t := int(grid[r][c])
			if is_normal(t):
				cnt[t] += 1
	var best := 0
	for i in TYPES:
		if int(cnt[i]) > int(cnt[best]):
			best = i
	return best


func _random_target() -> Vector2i:
	## Alvo da Gaivota: peça da meta primeiro, senão qualquer peça normal.
	var goals: Array = []
	var others: Array = []
	for r in ROWS:
		for c in COLS:
			var t := int(grid[r][c])
			if is_normal(t):
				if goal_types.has(t):
					goals.append(Vector2i(c, r))
				else:
					others.append(Vector2i(c, r))
	if not goals.is_empty():
		return goals[rng.randi_range(0, goals.size() - 1)]
	if not others.is_empty():
		return others[rng.randi_range(0, others.size() - 1)]
	return Vector2i(-1, -1)


func _hit(cell: Vector2i, cleared: Dictionary, queue: Array) -> void:
	if not in_bounds(cell):
		return
	cleared[cell] = true
	var t := int(grid[cell.y][cell.x])
	if is_powerup(t):
		queue.append(cell)


func _effect_cells(c: Vector2i, t: int, cleared: Dictionary, queue: Array, fx: Array) -> void:
	cleared[c] = true
	match t:
		P_PIPA:
			for cc in COLS:
				_hit(Vector2i(cc, c.y), cleared, queue)
			for rr in ROWS:
				_hit(Vector2i(c.x, rr), cleared, queue)
			fx.append({"kind": "blast", "shape": "cross", "center": c})
		P_TROVAO:
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					_hit(Vector2i(c.x + dx, c.y + dy), cleared, queue)
			fx.append({"kind": "blast", "shape": "square", "center": c, "radius": 2})
		P_GAIVOTA:
			var tgt := _random_target()
			if in_bounds(tgt):
				fx.append({"kind": "gaivota_flight", "from": c, "to": tgt})
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						_hit(Vector2i(tgt.x + dx, tgt.y + dy), cleared, queue)
		P_SOL:
			var col := _most_common_color()
			fx.append({"kind": "sol_fire", "color": col})
			for r in ROWS:
				for cc in COLS:
					if int(grid[r][cc]) == col:
						_hit(Vector2i(cc, r), cleared, queue)


func _drain(queue: Array, cleared: Dictionary, processed: Dictionary, fx: Array) -> void:
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		if processed.has(c) or not in_bounds(c):
			continue
		var t := int(grid[c.y][c.x])
		if not is_powerup(t):
			continue
		processed[c] = true
		_effect_cells(c, t, cleared, queue, fx)


func trigger_at(cell: Vector2i) -> Dictionary:
	## Dispara UM power-up (toque ou troca com peça normal) + reações em cadeia.
	## Retorna {"cells": Array[Vector2i], "fx": Array} para animação.
	var cleared := {}
	var processed := {}
	var queue: Array = [cell]
	var fx: Array = []
	_drain(queue, cleared, processed, fx)
	return {"cells": cleared.keys(), "fx": fx}


func trigger_sol_at(sol_cell: Vector2i, color: int) -> Dictionary:
	## Sol armado + toque numa peça de `color`: limpa TODAS dessa cor.
	var cleared := {}
	if in_bounds(sol_cell):
		cleared[sol_cell] = true
	for r in ROWS:
		for c in COLS:
			if int(grid[r][c]) == color:
				cleared[Vector2i(c, r)] = true
	var fx: Array = [{"kind": "sol_fire", "color": color}]
	return {"cells": cleared.keys(), "fx": fx}


func combo_cells(a: Vector2i, b: Vector2i) -> Dictionary:
	## Dois power-ups adjacentes trocados entre si. Retorna {"cells", "fx"}.
	var ta := int(grid[a.y][a.x])
	var tb := int(grid[b.y][b.x])
	var cleared := {}
	var processed := {}
	var queue: Array = []
	var fx: Array = []
	# Ambos são consumidos.
	processed[a] = true
	processed[b] = true
	cleared[a] = true
	cleared[b] = true
	if ta == P_SOL or tb == P_SOL:
		if ta == P_SOL and tb == P_SOL:
			fx.append({"kind": "combo", "name": "sol_sol"})
			for r in ROWS:
				for c in COLS:
					cleared[Vector2i(c, r)] = true
		else:
			var x: int = tb if ta == P_SOL else ta
			fx.append({"kind": "combo", "name": "sol_x"})
			var col := _most_common_color()
			var targets: Array = []
			for r in ROWS:
				for c in COLS:
					if int(grid[r][c]) == col:
						var cc := Vector2i(c, r)
						grid[r][c] = x
						targets.append(cc)
			for tcell in targets:
				queue.append(tcell)
			_drain(queue, cleared, processed, fx)
	elif ta == P_PIPA and tb == P_PIPA:
		fx.append({"kind": "combo", "name": "pipa_pipa"})
		for dy in range(-1, 2):
			var rr := b.y + dy
			if rr >= 0 and rr < ROWS:
				for c in COLS:
					_hit(Vector2i(c, rr), cleared, queue)
		for dx in range(-1, 2):
			var cc := b.x + dx
			if cc >= 0 and cc < COLS:
				for r in ROWS:
					_hit(Vector2i(cc, r), cleared, queue)
		_drain(queue, cleared, processed, fx)
	elif ta == P_TROVAO and tb == P_TROVAO \
			or (ta == P_PIPA and tb == P_TROVAO) \
			or (ta == P_TROVAO and tb == P_PIPA):
		fx.append({"kind": "combo", "name": "board_clear"})
		for r in ROWS:
			for c in COLS:
				_hit(Vector2i(c, r), cleared, queue)
		_drain(queue, cleared, processed, fx)
	elif ta == P_GAIVOTA or tb == P_GAIVOTA:
		var other: int = tb if ta == P_GAIVOTA else ta
		if other == P_GAIVOTA:
			fx.append({"kind": "combo", "name": "gaivota_x3"})
			for i in 3:
				var tgt := _random_target()
				if in_bounds(tgt):
					fx.append({"kind": "gaivota_flight", "from": a, "to": tgt})
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							_hit(Vector2i(tgt.x + dx, tgt.y + dy), cleared, queue)
		else:
			fx.append({"kind": "combo", "name": "gaivota_carry"})
			var tgt := _random_target()
			if in_bounds(tgt):
				fx.append({"kind": "gaivota_flight", "from": a, "to": tgt})
				if other == P_PIPA:
					for c in COLS:
						_hit(Vector2i(c, tgt.y), cleared, queue)
					for r in ROWS:
						_hit(Vector2i(tgt.x, r), cleared, queue)
				else: # P_TROVAO
					for dy in range(-2, 3):
						for dx in range(-2, 3):
							_hit(Vector2i(tgt.x + dx, tgt.y + dy), cleared, queue)
		_drain(queue, cleared, processed, fx)
	return {"cells": cleared.keys(), "fx": fx}
