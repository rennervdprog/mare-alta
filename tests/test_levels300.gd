extends SceneTree
## Testes das 300 fases + áreas do MARÉ ALTA (Fase 4).
## Roda com: godot --headless --path <projeto> --script res://tests/test_levels300.gd
## Usa user://test_save300.cfg para não tocar no save real.

var _failures := 0
var GS := load("res://scripts/game_state.gd")

const EXPECTED_FIRST10 := [
	{"goals": {"coco": 10}, "moves": 9},
	{"goals": {"concha": 12}, "moves": 10},
	{"goals": {"coco": 10, "concha": 10}, "moves": 10},
	{"goals": {"peixe": 15}, "moves": 9},
	{"goals": {"coco": 12, "chinelo": 12}, "moves": 10},
	{"goals": {"concha": 15, "guarda_sol": 10}, "moves": 10},
	{"goals": {"coco": 20}, "moves": 11},
	{"goals": {"peixe": 15, "chinelo": 15}, "moves": 10},
	{"goals": {"concha": 20, "coco": 10}, "moves": 12},
	{"goals": {"coco": 20, "concha": 20}, "moves": 11},
]


func _init() -> void:
	_t_levels_valid()
	_t_first10_identical()
	_t_areas_integrity()
	_t_helpers()
	_t_save_load_new_fields()
	_t_old_save_migration()
	# Limpa o save de teste.
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("test_save300.cfg"):
		dir.remove("test_save300.cfg")
	if _failures == 0:
		print("ALL_LEVELS300_TESTS_PASSED")
	else:
		printerr("LEVELS300_TESTS_FAILED: ", _failures)
	quit(_failures)


func _new_gs():
	var gs = GS.new()
	gs.save_path = "user://test_save300.cfg"
	return gs


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)


func _t_levels_valid() -> void:
	_check(GS.MAX_LEVEL == 300, "MAX_LEVEL == 300")
	_check(GS.LEVELS.size() == 300, "LEVELS tem 300 entradas")
	var valid_names := ["coco", "guarda_sol", "chinelo", "peixe", "concha"]
	var bad := 0
	for i in 300:
		var e: Dictionary = GS.LEVELS[i]
		var goals: Dictionary = e["goals"]
		var moves := int(e["moves"])
		if goals.size() < 1 or goals.size() > 2:
			bad += 1
			continue
		for name in goals.keys():
			if not valid_names.has(name) or int(goals[name]) <= 0:
				bad += 1
				break
		if moves < 6 or moves > 60:
			bad += 1
	_check(bad == 0, "300 configs válidas (1-2 tipos, nomes válidos, alvo>0, mov 6-60)")
	# get_level converte p/ type ids e respeita os limites.
	var gs = _new_gs()
	var l300: Dictionary = gs.get_level(300)
	_check((l300["goals"] as Dictionary).size() >= 1, "get_level(300) ok")
	var l0: Dictionary = gs.get_level(0)
	_check(int((l0["goals"] as Dictionary).size()) >= 1, "get_level(0) faz clamp p/ fase 1")
	var l999: Dictionary = gs.get_level(999)
	_check(int(l999["moves"]) == int((gs.get_level(300) as Dictionary)["moves"]), "get_level(999) faz clamp p/ fase 300")


func _t_first10_identical() -> void:
	var ok := true
	for i in 10:
		var e: Dictionary = GS.LEVELS[i]
		var exp: Dictionary = EXPECTED_FIRST10[i]
		if (e["goals"] as Dictionary) != (exp["goals"] as Dictionary):
			ok = false
			printerr("  fase %d goals divergente: %s vs %s" % [i + 1, str(e["goals"]), str(exp["goals"])])
		if int(e["moves"]) != int(exp["moves"]):
			ok = false
			printerr("  fase %d moves divergente: %d vs %d" % [i + 1, int(e["moves"]), int(exp["moves"])])
	_check(ok, "fases 1-10 idênticas às originais (dicts exatos)")


func _t_areas_integrity() -> void:
	_check(GS.AREAS.size() == 5, "5 áreas")
	var ok := true
	var expect := [
		[1, "A ressaca", 1, 60], [2, "O bar", 61, 120], [3, "A cozinha", 121, 180],
		[4, "O deck", 181, 240], [5, "O palco", 241, 300],
	]
	for i in 5:
		var a: Dictionary = GS.AREAS[i]
		var e: Array = expect[i]
		if int(a["id"]) != int(e[0]) or str(a["name"]) != str(e[1]):
			ok = false
		if int(a["from"]) != int(e[2]) or int(a["to"]) != int(e[3]):
			ok = false
		if int(a["to"]) - int(a["from"]) != 59:
			ok = false
		if (a["tasks"] as Array).size() != 8:
			ok = false
			printerr("  área %d: tasks != 8" % int(a["id"]))
		var intro_n := (a["intro"] as Array).size()
		if int(a["id"]) == 1 and intro_n != 0:
			ok = false
		if int(a["id"]) > 1 and intro_n != 3:
			ok = false
			printerr("  área %d: intro != 3 falas" % int(a["id"]))
		var story_n := (a["story"] as Array).size()
		if story_n < 6 or story_n > 7:
			ok = false
			printerr("  área %d: story fora de 6-7 falas" % int(a["id"]))
		if str(a["before"]).is_empty() or str(a["after"]).is_empty():
			ok = false
		for line in (a["intro"] as Array) + (a["story"] as Array):
			if (line as Array).size() != 2 or str((line as Array)[0]).is_empty() or str((line as Array)[1]).is_empty():
				ok = false
	_check(ok, "AREAS íntegras (60 fases contíguas 1-300, 8 tasks, intros, stories, artes)")
	# História do Cap 1 mantida exata (texto do renovation.gd).
	var story1: Array = (GS.AREAS[0] as Dictionary)["story"]
	_check((story1[0] as Array)[1] == "Não acredito... o quiosque do vovô...",
		"cap 1: 1a fala exata")
	_check((story1[6] as Array)[0] == "Cláudio"
		and (story1[6] as Array)[1] == "Mas o que a Marina ainda não sabia... é que o Waldomiro tinha um plano para impedir a reforma.",
		"cap 1: 7a fala exata")


func _t_helpers() -> void:
	var gs = _new_gs()
	gs.reset_progress()
	_check(gs.area_of_level(1) == 1 and gs.area_of_level(60) == 1, "area_of_level: 1 e 60 -> 1")
	_check(gs.area_of_level(61) == 2, "area_of_level: 61 -> 2")
	_check(gs.area_of_level(120) == 2 and gs.area_of_level(121) == 3, "area_of_level: 120->2, 121->3")
	_check(gs.area_of_level(240) == 4 and gs.area_of_level(241) == 5, "area_of_level: 240->4, 241->5")
	_check(gs.area_of_level(300) == 5, "area_of_level: 300 -> 5")
	# Unlock linear: área 1 sempre; demais exigem reforma anterior.
	_check(gs.area_unlocked(1), "área 1 sempre liberada")
	_check(not gs.area_unlocked(2), "área 2 bloqueada no início")
	_check(not gs.area_unlocked(0) and not gs.area_unlocked(6), "áreas fora de 1-5 bloqueadas")
	_check(not gs.area_renovation_done(1), "reforma área 1 incompleta no início")
	for t in gs.area_tasks(1):
		gs.complete_task((t as Array)[0])
	_check(gs.area_renovation_done(1), "reforma área 1 completa após 8 tasks")
	_check(gs.area_unlocked(2), "área 2 libera após reforma da área 1")
	_check(not gs.area_unlocked(3), "área 3 ainda bloqueada")
	_check((gs.area_tasks(2) as Array).size() == 8, "area_tasks(2): 8")
	_check((gs.area_intro(1) as Array).is_empty(), "area_intro(1): vazia")
	_check((gs.area_intro(3) as Array).size() == 3, "area_intro(3): 3 falas")
	_check((gs.area_story(5) as Array).size() == 6, "area_story(5): 6 falas")
	# Baús por área.
	_check(not gs.chest_claimed_area(2), "baú área 2 começa fechado")
	gs.claim_chest_area(2)
	_check(gs.chest_claimed_area(2) and not gs.chest_claimed_area(3), "baú área 2 resgatado; área 3 não")
	# Legado: claim_chest()/chest_claimed espelham a área 1.
	gs.claim_chest()
	_check(gs.chest_claimed and gs.chest_claimed_area(1), "legado claim_chest -> área 1")
	# Intros.
	_check(not gs.intro_seen(2), "intro 2 não vista")
	gs.mark_intro_seen(2)
	_check(gs.intro_seen(2) and not gs.intro_seen(3), "intro 2 marcada")
	gs.reset_progress()
	_check(not gs.chest_claimed_area(2) and not gs.intro_seen(2), "reset zera baús e intros")


func _t_save_load_new_fields() -> void:
	var a = _new_gs()
	a.reset_progress()
	a.stars = 42
	a.coins = 777
	a.unlocked_level = 150
	a.current_area = 3
	a.levels_won = {1: true, 150: true}
	a.tasks_done = ["task_rubble", "a3_sink"]
	a.claim_chest_area(1)
	a.claim_chest_area(3)
	a.mark_intro_seen(2)
	a.mark_intro_seen(3)
	a.save_game()
	var b = _new_gs()
	b.load_game()
	_check(b.stars == 42 and b.coins == 777, "save/load: stars+coins")
	_check(b.unlocked_level == 150 and b.current_area == 3, "save/load: unlocked_level+current_area")
	_check(b.level_won_before(1) and b.level_won_before(150) and not b.level_won_before(2),
		"save/load: levels_won")
	_check(b.task_done("task_rubble") and b.task_done("a3_sink") and not b.task_done("a2_counter"),
		"save/load: tasks_done")
	_check(b.chest_claimed_area(1) and b.chest_claimed_area(3) and not b.chest_claimed_area(2),
		"save/load: chests_claimed")
	_check(b.chest_claimed, "save/load: legado chest_claimed lê área 1")
	_check(b.intro_seen(2) and b.intro_seen(3) and not b.intro_seen(4),
		"save/load: intros_seen")
	# Nuvem: roundtrip completo.
	var cloud: Dictionary = b.get_cloud_data()
	_check(int(cloud["unlocked_level"]) == 150 and (cloud["chests_claimed"] as Array).size() == 2,
		"get_cloud_data: campos novos presentes")
	var c = _new_gs()
	c.reset_progress()
	c.apply_cloud_data(cloud)
	_check(c.unlocked_level == 150 and c.chest_claimed_area(3) and c.intro_seen(2),
		"apply_cloud_data: restaura tudo")
	_check(c.task_done("a3_sink") and c.level_won_before(150), "apply_cloud_data: tasks+levels")


func _t_old_save_migration() -> void:
	# Simula um save ANTIGO (formato pré-300 fases): bool chest_claimed + unlocked 10.
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "stars", 5)
	cfg.set_value("progress", "coins", 200)
	cfg.set_value("progress", "unlocked_level", 10)
	cfg.set_value("progress", "levels_won", [1, 2, 3])
	cfg.set_value("progress", "tasks_done", ["task_rubble"])
	cfg.set_value("progress", "chest_claimed", true)
	cfg.save("user://test_save300.cfg")
	var gs = _new_gs()
	gs.load_game()
	_check(gs.unlocked_level == 10, "migração: unlocked_level 10 preservado")
	_check(gs.chest_claimed_area(1) and gs.chest_claimed, "migração: bool antigo -> baú área 1")
	_check(gs.current_area == 1 and gs.intros_seen.is_empty(), "migração: novos campos com default")
	# Save antigo com unlocked além do novo teto (não deve existir, mas blinda).
	cfg.set_value("progress", "unlocked_level", 9999)
	cfg.set_value("progress", "chest_claimed", false)
	cfg.save("user://test_save300.cfg")
	var gs2 = _new_gs()
	gs2.load_game()
	_check(gs2.unlocked_level == 300, "migração: unlocked clampado em 300")
	_check(not gs2.chest_claimed_area(1), "migração: bool false -> baú fechado")
