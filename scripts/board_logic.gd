class_name BoardLogic
extends RefCounted
## Modelo PURO do tabuleiro match-3 (sem nenhuma renderização).
## Permite testar toda a regra do jogo de forma headless.
##
## Convenções:
## - grid[linha][coluna] -> int (0..TYPES-1) ou EMPTY (-1)
## - células como Vector2i(coluna, linha)

const ROWS: int = 8
const COLS: int = 8
const TYPES: int = 5
const EMPTY: int = -1

var grid: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	new_board()


func new_board() -> void:
	## Preenche o tabuleiro sem combinações prontas e com pelo menos 1 jogada.
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
	## sequências de 3+ peças iguais (horizontal e/ou vertical).
	var matched := {}
	# Horizontal (por linha).
	for r in ROWS:
		var c := 0
		while c < COLS:
			var t: int = grid[r][c]
			if t == EMPTY:
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
			if t == EMPTY:
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
	if not (in_bounds(a) and in_bounds(b)):
		return false
	swap_cells(a, b)
	var ok := not find_matches().is_empty()
	swap_cells(a, b)
	return ok


func has_possible_move() -> bool:
	for r in ROWS:
		for c in COLS:
			var cell := Vector2i(c, r)
			var right := Vector2i(c + 1, r)
			var down := Vector2i(c, r + 1)
			if in_bounds(right) and swap_creates_match(cell, right):
				return true
			if in_bounds(down) and swap_creates_match(cell, down):
				return true
	return false


func remove_cells(cells: Array) -> Array:
	## Marca células como EMPTY. Retorna Array[int] de tamanho TYPES
	## com a contagem de peças removidas por tipo.
	var counts: Array = []
	counts.resize(TYPES)
	counts.fill(0)
	for v in cells:
		var cell: Vector2i = v
		var t: int = grid[cell.y][cell.x]
		if t != EMPTY:
			counts[t] = int(counts[t]) + 1
			grid[cell.y][cell.x] = EMPTY
	return counts


func apply_gravity() -> Array:
	## Compacta cada coluna para baixo e preenche o topo com peças novas.
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
