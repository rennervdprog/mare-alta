extends SceneTree
## Testes headless do CloudSync (save na nuvem) — SEM rede.
## Roda com: godot --headless --path <projeto> --script res://tests/test_cloud.gd
## Saída: linhas PASS/FAIL + ALL_CLOUD_TESTS_PASSED; exit code = nº de falhas.
## Usa user://test_cloud.cfg para não tocar na identidade real.
##
## NOTA: no modo --script os autoloads não carregam e add_child durante _init
## não entra na árvore; por isso os testes que precisam da árvore rodam em
## _run(), após 2 frames reais.

const TEST_CFG := "user://test_cloud.cfg"
const ALPHABET := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

var _failures := 0
var CS := load("res://scripts/cloud_sync.gd")


func _init() -> void:
	_run() # assíncrono: continua após os primeiros frames


func _run() -> void:
	await process_frame
	await process_frame
	_t_code_format()
	_t_player_id_format()
	_t_sanitize_code()
	_t_upsert_payload()
	_t_headers()
	_t_dormant_no_key()
	_t_debounce_no_network()
	_t_do_sync_no_network()
	_t_identity_persists()
	_t_should_prompt()
	_t_data_equal_reordered_keys()
	_t_parse_rows()
	_t_send_without_tree()
	_t_fetch_by_code_dormant()
	_t_config_scene_loads()
	_t_start_screen_wiring()
	_clean()
	if _failures == 0:
		print("ALL_CLOUD_TESTS_PASSED")
	else:
		printerr("CLOUD_TESTS_FAILED: ", _failures)
	quit(_failures)


func _clean() -> void:
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("test_cloud.cfg"):
		dir.remove("test_cloud.cfg")


func _new_cs() -> Node:
	var cs = CS.new()
	cs.cfg_path = TEST_CFG
	return cs


func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_failures += 1
		printerr("FAIL: ", name)


func _t_code_format() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var ok := true
	for i in 200:
		var c: String = CS.make_code(rng)
		if c.length() != 8:
			ok = false
		for ch in c:
			if ALPHABET.find(ch) < 0:
				ok = false
		# sem ambíguos: 0/O, 1/I/L não existem no alfabeto
		for bad in ["0", "O", "1", "I", "L"]:
			if c.find(bad) >= 0:
				ok = false
	_check(ok, "código: 200 amostras com 8 chars do alfabeto, sem ambíguos")


func _t_player_id_format() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var ok := true
	for i in 20:
		var pid: String = CS.make_player_id(rng)
		var parts := pid.split("-")
		if parts.size() != 5:
			ok = false
			continue
		var lens := [8, 4, 4, 4, 12]
		for p in 5:
			if parts[p].length() != lens[p]:
				ok = false
		if not parts[2].begins_with("4"): # versão 4
			ok = false
		if not "89ab".contains(parts[3].substr(0, 1)): # variante RFC 4122
			ok = false
		for ch in pid.replace("-", ""):
			if "0123456789abcdef".find(ch) < 0:
				ok = false
	_check(ok, "player_id: formato UUID v4 (8-4-4-4-12, versão e variante)")


func _t_sanitize_code() -> void:
	_check(CS.sanitize_code("abcd-efgh") == "ABCDEFGH", "sanitize: minúsculas e hífen")
	_check(CS.sanitize_code("K7X2Q9WM") == "K7X2Q9WM", "sanitize: código válido passa")
	_check(CS.sanitize_code("abc") == "", "sanitize: curto demais -> vazio")
	_check(CS.sanitize_code("abcdefghij") == "ABCDEFGH", "sanitize: trunca em 8")
	_check(CS.sanitize_code("0o1ilOO11") == "", "sanitize: só ambíguos -> vazio")


func _t_upsert_payload() -> void:
	var cs = _new_cs()
	cs.player_id = "pid-teste"
	cs.code = "ABCDEFGH"
	var body: Dictionary = cs._upsert_body({"stars": 3, "coins": 120})
	_check(body.get("player_id") == "pid-teste", "upsert: player_id no corpo")
	_check(body.get("code") == "ABCDEFGH", "upsert: code no corpo")
	_check((body.get("data") as Dictionary).get("stars") == 3, "upsert: data no corpo")
	_check(not body.has("updated_at"), "upsert: sem updated_at (banco usa DEFAULT now())")
	var ok_json := true
	if JSON.stringify(body).is_empty():
		ok_json = false
	var empty_body: Dictionary = cs._upsert_body({})
	if (empty_body.get("data") as Dictionary).size() != 0:
		ok_json = false
	_check(ok_json, "upsert: serializa p/ JSON e aceita dicionário vazio")
	cs.free()


func _t_headers() -> void:
	var cs = _new_cs()
	cs.anon_key_override = "TESTKEY"
	var auth: PackedStringArray = cs._auth_headers()
	_check(auth.has("apikey: TESTKEY"), "headers: apikey")
	_check(auth.has("Authorization: Bearer TESTKEY"), "headers: Authorization Bearer")
	var post: PackedStringArray = cs._post_headers()
	_check(post.has("Content-Type: application/json"), "headers: Content-Type json")
	_check(post.has("Prefer: resolution=merge-duplicates"), "headers: Prefer merge-duplicates")
	cs.free()


func _t_dormant_no_key() -> void:
	var cs = _new_cs()
	root.add_child(cs) # _ready roda de verdade: chave vazia -> dormente
	_check(not cs.is_enabled(), "dormente: is_enabled() falso com ANON_KEY vazia")
	_check(cs.get_status_text() == "offline", "dormente: status 'offline'")
	_check(CS._code_valid(cs.get_code()), "dormente: identidade local gerada mesmo sem chave")
	cs.schedule_sync()
	var timers := 0
	var https := 0
	for c in cs.get_children():
		if c is Timer:
			timers += 1
		if c is HTTPRequest:
			https += 1
	_check(timers == 0 and https == 0, "dormente: schedule_sync não cria timer nem request")
	root.remove_child(cs)
	cs.free()


func _t_debounce_no_network() -> void:
	var cs = _new_cs()
	root.add_child(cs) # _ready dormente (sem chave): nenhuma sonda de rede
	cs.anon_key_override = "k" # finge chave DEPOIS do _ready p/ não sondar
	cs.schedule_sync()
	cs.schedule_sync()
	cs.schedule_sync()
	var timers := []
	for c in cs.get_children():
		if c is Timer:
			timers.append(c)
	_check(timers.size() == 1, "debounce: 3 schedule_sync -> 1 timer só")
	_check((timers[0] as Timer).is_inside_tree(), "debounce: timer dentro da árvore (sem erro)")
	root.remove_child(cs)
	cs.free()


func _t_do_sync_no_network() -> void:
	# 1) Dormente (sem chave): nunca dispara rede, mesmo com GameState presente.
	var cs = _new_cs()
	root.add_child(cs)
	cs._do_sync()
	_check(_count_http(cs) == 0, "_do_sync dormente: nenhuma request mesmo com GameState")
	root.remove_child(cs)
	cs.free()
	# 2) Com chave mas sem o nó GameState: retorna antes de qualquer rede.
	var gs_node := root.get_node_or_null("GameState")
	var had_gs := gs_node != null
	if had_gs:
		root.remove_child(gs_node)
	var cs2 = _new_cs()
	root.add_child(cs2)
	cs2.anon_key_override = "k"
	cs2._do_sync()
	_check(_count_http(cs2) == 0, "_do_sync sem GameState: nenhuma request disparada")
	root.remove_child(cs2)
	cs2.free()
	if had_gs:
		root.add_child(gs_node)


func _count_http(n: Node) -> int:
	var h := 0
	for c in n.get_children():
		if c is HTTPRequest:
			h += 1
	return h


func _t_identity_persists() -> void:
	var a = _new_cs()
	root.add_child(a)
	var pid: String = a.get_player_id()
	var cod: String = a.get_code()
	root.remove_child(a)
	a.free()
	var b = _new_cs()
	root.add_child(b)
	_check(b.get_player_id() == pid and b.get_code() == cod, "identidade: player_id+código persistem no cfg")
	root.remove_child(b)
	b.free()
	# código corrompido no cfg -> regenera válido
	var cfg := ConfigFile.new()
	cfg.set_value("cloud", "player_id", "x")
	cfg.set_value("cloud", "code", "ruim")
	cfg.save(TEST_CFG)
	var c = _new_cs()
	root.add_child(c)
	_check(CS._code_valid(c.get_code()) and c.get_player_id() != "x",
		"identidade: código inválido no cfg é regenerado")
	root.remove_child(c)
	c.free()


func _t_should_prompt() -> void:
	var newer := "2026-10-17T12:00:00+00:00"
	var older := "2026-10-17T10:00:00+00:00"
	var d1 := {"stars": 5, "coins": 120}
	var d2 := {"stars": 6, "coins": 120}
	_check(CS.should_prompt_cloud(newer, d2, "", {}), "prompt: linha nova sem last_sync -> pergunta")
	_check(CS.should_prompt_cloud(newer, d2, older, d1), "prompt: nuvem mais nova e diferente -> pergunta")
	_check(not CS.should_prompt_cloud(newer, d1, older, d1), "prompt: nuvem mais nova mas igual -> não pergunta")
	_check(not CS.should_prompt_cloud(older, d2, newer, d1), "prompt: nuvem mais velha -> não pergunta")
	_check(not CS.should_prompt_cloud(newer, d2, newer, d1), "prompt: mesmo timestamp -> não pergunta")
	_check(not CS.should_prompt_cloud("", d2, "", {}), "prompt: sem timestamp -> não pergunta")


func _t_data_equal_reordered_keys() -> void:
	# O JSON tem chaves sempre-string ({1: true} vira {"1": true}) e o jsonb do
	# Postgres reordena as chaves e pode devolver int como float.
	var local := {"stars": 5, "coins": 120, "tasks": ["a", "b"], "won": {1: true}}
	var cloud := {"won": {"1": true}, "tasks": ["a", "b"], "coins": 120.0, "stars": 5.0}
	_check(CS.data_equal(local, cloud), "data_equal: chaves int/str + reordem + int/float -> igual")
	_check(not CS.data_equal(local, {"stars": 6, "coins": 120, "tasks": ["a", "b"], "won": {1: true}}),
		"data_equal: valor diferente -> diferente")
	_check(not CS.data_equal({"t": ["a", "b"]}, {"t": ["b", "a"]}),
		"data_equal: ordem de array importa")
	_check(not CS.data_equal({"a": 1}, {"a": 1, "b": 2}), "data_equal: tamanho diferente")


func _t_parse_rows() -> void:
	_check(CS.parse_rows('[{"a":1}]'.to_utf8_buffer()).size() == 1, "parse_rows: array com 1 linha")
	_check(CS.parse_rows('[]'.to_utf8_buffer()).is_empty(), "parse_rows: array vazio")
	_check(CS.parse_rows('não é json'.to_utf8_buffer()).is_empty(), "parse_rows: json inválido -> vazio")
	_check(CS.parse_rows('{"a":1}'.to_utf8_buffer()).is_empty(), "parse_rows: objeto solto -> vazio")


func _t_send_without_tree() -> void:
	var cs = _new_cs()
	cs.anon_key_override = "k"
	var got := []
	cs._send("https://example.invalid/x", HTTPClient.METHOD_GET,
		PackedStringArray(), "",
		func(result: int, _code: int, _body: PackedByteArray) -> void: got.append(result))
	_check(got.size() == 1 and got[0] == HTTPRequest.RESULT_CANT_CONNECT,
		"_send fora da árvore: falha imediata, sem rede")
	cs.free()


func _t_fetch_by_code_dormant() -> void:
	var cs = _new_cs()
	var got := []
	cs.fetch_by_code("ABCDEFGH",
		func(ok: bool, msg: String) -> void: got.append([ok, msg]))
	_check(got.size() == 1 and got[0][0] == false, "fetch_by_code dormente: on_done(false) sem rede")
	_check(cs.get_child_count() == 0, "fetch_by_code dormente: nenhum filho HTTPRequest")
	cs.free()


func _t_config_scene_loads() -> void:
	# config_screen.gd não referencia autoloads direto: instancia de verdade.
	var packed := load("res://scenes/config_screen.tscn") as PackedScene
	_check(packed != null and packed.can_instantiate(), "config_screen.tscn: carrega e instancia")
	if packed == null:
		return
	var inst := packed.instantiate()
	_check(inst.get_node_or_null("Margin/VBox/CardDevice/VBox/DeviceRow/CodeLabel") is Label,
		"config_screen: CodeLabel existe")
	_check(inst.get_node_or_null("Margin/VBox/CardCode/VBox/CodeRow/CodeEdit") is LineEdit,
		"config_screen: CodeEdit existe")
	_check(inst.get_node_or_null("Margin/VBox/StatusRow/StatusLabel") is Label,
		"config_screen: StatusLabel existe")
	_check(inst.get_node_or_null("Margin/VBox/BtnVoltar") is Button,
		"config_screen: BtnVoltar existe")
	_check(inst.get_node_or_null("Toast/ToastLabel") is Label, "config_screen: Toast existe")
	inst.free()


func _t_start_screen_wiring() -> void:
	# start_screen.gd usa o autoload GameState (não compila no modo --script
	# sem autoloads); valida por texto.
	var tscn := _read_text("res://scenes/start_screen.tscn")
	_check(tscn.contains('[node name="CloudLabel"'), "start_screen.tscn: nó CloudLabel")
	var gd := _read_text("res://scripts/start_screen.gd")
	_check(gd.contains("scenes/config_screen.tscn"), "start_screen.gd: BtnConfig abre config_screen")
	_check(gd.contains("get_status_text"), "start_screen.gd: lê status da nuvem")
	_check(not gd.contains("Configurações em breve"), "start_screen.gd: toast antigo removido")
	var proj := _read_text("res://project.godot")
	var gs_pos := proj.find('GameState="*res://scripts/game_state.gd"')
	var cs_pos := proj.find('CloudSync="*res://scripts/cloud_sync.gd"')
	_check(gs_pos >= 0 and cs_pos > gs_pos, "project.godot: autoload CloudSync depois do GameState")
