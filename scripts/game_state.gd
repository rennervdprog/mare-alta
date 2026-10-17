extends Node
## GameState — autoload com o progresso do jogador (save/load em user://save.cfg).
## Guarda: estrelas, moedas, fase desbloqueada, fases vencidas, tarefas da
## reforma, baú, e a config das 10 fases (metas + movimentos calibrados via bot).

const TYPE_IDS := {"coco": 0, "guarda_sol": 1, "chinelo": 2, "peixe": 3, "concha": 4}
const TYPE_NAMES := {0: "cocos", 1: "guarda-sóis", 2: "chinelos", 3: "peixes", 4: "conchas"}

## Movimentos calibrados com o bot (100 jogos/fase; alvo: bot vencendo ~90%
## nas fases 1-9 e ~85% na 10 -> humano típico na zona near-miss).
## Win-rates medidos: 90/96/91/90/95/96/95/92/94/84.
const LEVELS: Array = [
	{"goals": {"coco": 10}, "moves": 6},                          # 1 - bot 90%
	{"goals": {"concha": 12}, "moves": 8},                        # 2 - bot 96%
	{"goals": {"coco": 10, "concha": 10}, "moves": 8},            # 3 - bot 91%
	{"goals": {"peixe": 15}, "moves": 8},                         # 4 - bot 90%
	{"goals": {"coco": 12, "chinelo": 12}, "moves": 9},           # 5 - bot 95%
	{"goals": {"concha": 15, "guarda_sol": 10}, "moves": 10},     # 6 - bot 96%
	{"goals": {"coco": 20}, "moves": 11},                         # 7 - bot 95%
	{"goals": {"peixe": 15, "chinelo": 15}, "moves": 10},          # 8 - bot 92%
	{"goals": {"concha": 20, "coco": 10}, "moves": 12},            # 9 - bot 94%
	{"goals": {"coco": 20, "concha": 20}, "moves": 11},            # 10 - bot 84%
]

const SAVE_PATH := "user://save.cfg"
const MAX_LEVEL := 10

## Caminho do save (sobrescrito nos testes para não tocar no save real).
var save_path: String = SAVE_PATH

var stars: int = 0
var coins: int = 120
var unlocked_level: int = 1
var current_level: int = 1
var levels_won: Dictionary = {} # n (int) -> true
var tasks_done: Array = []      # ids de tarefa (String)
var chest_claimed: bool = false


func _ready() -> void:
	load_game()


## Devolve {"goals": {type_id: alvo}, "moves": n} da fase (1-based).
func get_level(n: int) -> Dictionary:
	var cfg: Dictionary = LEVELS[clampi(n, 1, MAX_LEVEL) - 1]
	var typed := {}
	for name in (cfg["goals"] as Dictionary).keys():
		typed[int(TYPE_IDS[name])] = int((cfg["goals"] as Dictionary)[name])
	return {"goals": typed, "moves": int(cfg["moves"])}


func level_won_before(n: int) -> bool:
	return bool(levels_won.get(n, false))


## Registra vitória. Retorna true se foi a PRIMEIRA vitória (vale +1 estrela).
func on_level_won(n: int) -> bool:
	var first := not level_won_before(n)
	levels_won[n] = true
	if first:
		stars += 1
	unlocked_level = maxi(unlocked_level, mini(n + 1, MAX_LEVEL))
	save_game()
	return first


func spend_star() -> bool:
	if stars <= 0:
		return false
	stars -= 1
	save_game()
	return true


func complete_task(task_id: String) -> void:
	if not tasks_done.has(task_id):
		tasks_done.append(task_id)
		save_game()


func task_done(task_id: String) -> bool:
	return tasks_done.has(task_id)


func add_coins(n: int) -> void:
	coins += n
	save_game()


func claim_chest() -> void:
	chest_claimed = true
	save_game()


func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "stars", stars)
	cfg.set_value("progress", "coins", coins)
	cfg.set_value("progress", "unlocked_level", unlocked_level)
	cfg.set_value("progress", "levels_won", levels_won.keys())
	cfg.set_value("progress", "tasks_done", tasks_done)
	cfg.set_value("progress", "chest_claimed", chest_claimed)
	cfg.save(save_path)


func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	stars = int(cfg.get_value("progress", "stars", 0))
	coins = int(cfg.get_value("progress", "coins", 120))
	unlocked_level = clampi(int(cfg.get_value("progress", "unlocked_level", 1)), 1, MAX_LEVEL)
	levels_won = {}
	for n in cfg.get_value("progress", "levels_won", []):
		levels_won[int(n)] = true
	tasks_done = Array(cfg.get_value("progress", "tasks_done", []))
	chest_claimed = bool(cfg.get_value("progress", "chest_claimed", false))


func reset_progress() -> void:
	stars = 0
	coins = 120
	unlocked_level = 1
	current_level = 1
	levels_won = {}
	tasks_done = []
	chest_claimed = false
	save_game()
