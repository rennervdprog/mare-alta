extends Node
## CloudSync — autoload para save na nuvem (Supabase/PostgREST), cross-device.
##
## PRINCÍPIO INEGOCIÁVEL: OFFLINE-FIRST. O jogo funciona 100% sem rede, sem a
## chave e sem a tabela existir. Toda chamada de rede tem timeout de 5s e
## qualquer erro é silencioso (nunca quebra o jogo).
##
## ATIVAÇÃO: com SUPABASE_ANON_KEY vazia (padrão), tudo fica dormente e
## silencioso. Para ativar, o Renner cola a chave `anon public` aqui:
##   Supabase Dashboard -> projeto -> Settings -> Data API -> "anon" "public" key
## Depois de colar a chave, rode o SQL de
## `~/workspace/jogo-quiosque-do-sol/supabase/mare_alta_progress.sql` no
## SQL Editor do dashboard (uma vez) para criar a tabela.
##
## Interface esperada no GameState (outro dono implementa; aqui é defensivo):
##   GameState.get_cloud_data() -> Dictionary
##   GameState.apply_cloud_data(d: Dictionary)
##   GameState.save_game() chama CloudSync.schedule_sync() se o nó existir.

const SUPABASE_URL := "https://qkjhguziuchqsbxzruea.supabase.co/rest/v1"
## VAZIA = dormente. Cole a anon public key (Settings -> Data API) para ativar.
const SUPABASE_ANON_KEY := ""

const CLOUD_CFG := "user://cloud.cfg"
const CODE_ALPHABET := "ABCDEFGHJKMNPQRSTUVWXYZ23456789" # sem ambíguos (0/O, 1/I/L)
const REQUEST_TIMEOUT := 5.0
const SYNC_DEBOUNCE := 5.0
const TABLE := "mare_alta_progress"

## Caminho do arquivo de identidade (sobrescrito nos testes).
var cfg_path: String = CLOUD_CFG
## Override da chave só para testes (permite exercitar o debounce sem rede).
var anon_key_override: String = ""

var player_id: String = ""
var code: String = ""

var _last_sync: String = "" # updated_at da nuvem do último sync bem-sucedido
var _status: String = "offline" # offline | ok | unavailable
var _sync_timer: Timer = null
var _inflight := {} # HTTPRequest -> Callable
var _busy := false

signal status_changed(text: String)


func _ready() -> void:
	_load_identity()
	if not is_enabled():
		_set_status("offline")
		return
	_set_status("ok") # otimista; a checagem abaixo corrige em ~1s se falhar
	_probe_after_scene()


func _probe_after_scene() -> void:
	# O autoload acorda antes da cena principal; espera 2 frames para a cena
	# existir antes de checar conflito / sondar a nuvem.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_enabled():
		return
	_fetch_own_row()


# ---------------------------------------------------------------- identidade

func get_code() -> String:
	return code


func get_player_id() -> String:
	return player_id


func is_enabled() -> bool:
	return not _effective_key().is_empty()


func _effective_key() -> String:
	if not anon_key_override.is_empty():
		return anon_key_override
	return SUPABASE_ANON_KEY


static func make_code(rng: RandomNumberGenerator) -> String:
	var s := ""
	for i in 8:
		s += CODE_ALPHABET[rng.randi_range(0, CODE_ALPHABET.length() - 1)]
	return s


static func make_player_id(rng: RandomNumberGenerator) -> String:
	var b := PackedByteArray()
	b.resize(16)
	for i in 16:
		b[i] = rng.randi_range(0, 255)
	b[6] = (b[6] & 0x0F) | 0x40 # versão 4
	b[8] = (b[8] & 0x3F) | 0x80 # variante RFC 4122
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
		b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]]


func _load_identity() -> void:
	var cfg := ConfigFile.new()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if cfg.load(cfg_path) == OK:
		player_id = str(cfg.get_value("cloud", "player_id", ""))
		code = str(cfg.get_value("cloud", "code", ""))
		_last_sync = str(cfg.get_value("cloud", "last_sync", ""))
	if player_id.is_empty() or code.is_empty() or not _code_valid(code):
		player_id = make_player_id(rng)
		code = make_code(rng)
		_last_sync = ""
		_save_identity()


func _save_identity() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("cloud", "player_id", player_id)
	cfg.set_value("cloud", "code", code)
	cfg.set_value("cloud", "last_sync", _last_sync)
	cfg.save(cfg_path)


static func _code_valid(c: String) -> bool:
	if c.length() != 8:
		return false
	for ch in c:
		if CODE_ALPHABET.find(ch) < 0:
			return false
	return true


# ------------------------------------------------------------------- status

func get_status_text() -> String:
	match _status:
		"ok":
			return "nuvem ok"
		"unavailable":
			return "nuvem indisponível"
		_:
			return "offline"


func _set_status(s: String) -> void:
	if _status == s:
		return
	_status = s
	status_changed.emit(get_status_text())


# --------------------------------------------------------------------- sync

## Chamado pelo GameState.save_game() (se o nó existir). Debounce de 5s.
func schedule_sync() -> void:
	if not is_enabled():
		return
	if _sync_timer == null:
		_sync_timer = Timer.new()
		_sync_timer.one_shot = true
		_sync_timer.timeout.connect(_do_sync)
		add_child(_sync_timer)
	_sync_timer.start(SYNC_DEBOUNCE)


func _do_sync() -> void:
	if _busy or not is_enabled():
		return
	var gs := _game_state()
	if gs == null or not gs.has_method("get_cloud_data"):
		return
	_busy = true
	var body := _upsert_body(gs.call("get_cloud_data"))
	_send(SUPABASE_URL + "/" + TABLE, HTTPClient.METHOD_POST, _post_headers(),
		JSON.stringify(body), _on_upsert_result)


## Corpo do upsert. `updated_at` é omitido de propósito: o banco preenche com
## DEFAULT now() (enviar a string "now()" quebraria o cast para timestamptz).
func _upsert_body(cloud_data: Dictionary) -> Dictionary:
	var data: Dictionary = cloud_data if cloud_data is Dictionary else {}
	return {"player_id": player_id, "code": code, "data": data}


func _on_upsert_result(result: int, code_http: int, _body: PackedByteArray) -> void:
	_busy = false
	if result == HTTPRequest.RESULT_SUCCESS and code_http >= 200 and code_http < 300:
		_set_status("ok")
	else:
		_set_status("unavailable")


# ------------------------------------------------------- checagem de conflito

func _fetch_own_row() -> void:
	var url := "%s/%s?player_id=eq.%s&select=data,updated_at" % [
		SUPABASE_URL, TABLE, player_id.uri_encode()]
	_send(url, HTTPClient.METHOD_GET, _auth_headers(), "", _on_own_row)


func _on_own_row(result: int, code_http: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code_http < 200 or code_http >= 300:
		_set_status("unavailable")
		return
	_set_status("ok")
	var rows := parse_rows(body)
	if rows.is_empty():
		return
	var row: Dictionary = rows[0]
	var cloud_ts := str(row.get("updated_at", ""))
	var raw_data = row.get("data", {})
	var cloud_data: Dictionary = raw_data if raw_data is Dictionary else {}
	if should_prompt_cloud(cloud_ts, cloud_data, _last_sync, _local_cloud_data()):
		_ask_cloud_conflict(cloud_ts, cloud_data)


## Puro e testável: nuvem mais nova E dados diferentes -> pergunta ao jogador.
## Normaliza as chaves (int->String) porque o JSON tem chaves sempre-string
## (ex.: levels_won {1: true} volta da nuvem como {"1": true}), e o jsonb do
## Postgres reordena as chaves e pode devolver int como float.
static func should_prompt_cloud(cloud_ts: String, cloud_data: Dictionary,
		last_sync: String, local_data: Dictionary) -> bool:
	if cloud_ts.is_empty():
		return false
	if last_sync.is_empty():
		return true # linha existe na nuvem mas nunca sincronizamos aqui
	if cloud_ts <= last_sync:
		return false
	return not data_equal(cloud_data, local_data)


static func data_equal(a, b) -> bool:
	return _data_equal_norm(_norm_keys(a), _norm_keys(b))


static func _norm_keys(v):
	if v is Dictionary:
		var d := {}
		for k in v:
			d[str(k)] = _norm_keys(v[k])
		return d
	if v is Array:
		var out := []
		for e in v:
			out.append(_norm_keys(e))
		return out
	return v


static func _data_equal_norm(a, b) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return float(a) == float(b)
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not _data_equal_norm(a[k], b[k]):
				return false
		return true
	if a is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _data_equal_norm(a[i], b[i]):
				return false
		return true
	return a == b


func _ask_cloud_conflict(cloud_ts: String, cloud_data: Dictionary) -> void:
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene == null:
		_adopt_cloud(cloud_ts, cloud_data) # sem cena (headless): adota direto
		return
	var dlg := AcceptDialog.new()
	dlg.dialog_text = "Encontramos um progresso mais novo na nuvem. Usar o progresso da nuvem?"
	dlg.ok_button_text = "Sim"
	dlg.add_cancel_button("Não")
	dlg.confirmed.connect(_adopt_cloud.bind(cloud_ts, cloud_data))
	dlg.canceled.connect(_ignore_cloud.bind(cloud_ts))
	scene.add_child(dlg)
	dlg.popup_centered()


func _adopt_cloud(cloud_ts: String, cloud_data: Dictionary) -> void:
	var gs := _game_state()
	if gs != null and gs.has_method("apply_cloud_data"):
		gs.call("apply_cloud_data", cloud_data)
	_last_sync = cloud_ts
	_save_identity()


func _ignore_cloud(cloud_ts: String) -> void:
	_last_sync = cloud_ts # não pergunta de novo pelo mesmo snapshot
	_save_identity()


func _local_cloud_data() -> Dictionary:
	var gs := _game_state()
	if gs != null and gs.has_method("get_cloud_data"):
		var d = gs.call("get_cloud_data")
		if d is Dictionary:
			return d
	return {}


# ------------------------------------------------- buscar por código (2º device)

## on_done(success: bool, msg: String). Sem chave -> chama direto, sem rede.
func fetch_by_code(p_code: String, on_done: Callable) -> void:
	var clean := sanitize_code(p_code)
	if not is_enabled():
		on_done.call(false, "Nuvem desativada")
		return
	if clean.is_empty():
		on_done.call(false, "Código inválido")
		return
	var url := "%s/%s?code=eq.%s&select=player_id,data,updated_at" % [
		SUPABASE_URL, TABLE, clean.uri_encode()]
	_send(url, HTTPClient.METHOD_GET, _auth_headers(), "",
		_on_code_row.bind(clean, on_done))


func _on_code_row(result: int, code_http: int, body: PackedByteArray,
		clean: String, on_done: Callable) -> void:
	var rows := parse_rows(body)
	if result != HTTPRequest.RESULT_SUCCESS or code_http < 200 or code_http >= 300 or rows.is_empty():
		_set_status("unavailable")
		on_done.call(false, "Código não encontrado")
		return
	_set_status("ok")
	var row: Dictionary = rows[0]
	player_id = str(row.get("player_id", player_id))
	code = clean # adota o código digitado
	_last_sync = str(row.get("updated_at", ""))
	_save_identity()
	var gs := _game_state()
	if gs != null and gs.has_method("apply_cloud_data"):
		var raw_data = row.get("data", {})
		var cloud_data: Dictionary = raw_data if raw_data is Dictionary else {}
		gs.call("apply_cloud_data", cloud_data)
	on_done.call(true, "Progresso da nuvem carregado!")


## Mantém só caracteres do alfabeto, em maiúsculas, até 8.
static func sanitize_code(raw: String) -> String:
	var s := ""
	for ch in raw.to_upper():
		if CODE_ALPHABET.find(ch) >= 0:
			s += ch
		if s.length() >= 8:
			break
	return s if s.length() == 8 else ""


# ------------------------------------------------------------------ http base

func _auth_headers() -> PackedStringArray:
	var k := _effective_key()
	return PackedStringArray(["apikey: " + k, "Authorization: Bearer " + k])


func _post_headers() -> PackedStringArray:
	var h := _auth_headers()
	h.append("Content-Type: application/json")
	h.append("Prefer: resolution=merge-duplicates")
	return h


static func parse_rows(body: PackedByteArray) -> Array:
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Array:
		return parsed
	return []


## Envia com timeout de 5s via timer (HTTPRequest não tem timeout próprio).
## Qualquer falha chama on_done(result, code, body) — nunca estoura.
func _send(url: String, method: int, headers: PackedStringArray,
		body_text: String, on_done: Callable) -> void:
	if not is_inside_tree():
		on_done.call(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray())
		return
	var http := HTTPRequest.new()
	add_child(http)
	_inflight[http] = on_done
	http.request_completed.connect(_on_request_completed.bind(http))
	var err := http.request(url, headers, method, body_text)
	if err != OK:
		_finish_request(http, HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray())
		return
	var killer := get_tree().create_timer(REQUEST_TIMEOUT)
	killer.timeout.connect(_on_request_timeout.bind(http))


func _on_request_completed(result: int, code_http: int,
		_headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	if not _inflight.has(http):
		return # já tratado pelo timeout
	var cb: Callable = _inflight[http]
	_inflight.erase(http)
	http.queue_free()
	cb.call(result, code_http, body)


func _on_request_timeout(http: HTTPRequest) -> void:
	if not _inflight.has(http):
		return
	http.cancel_request()
	_finish_request(http, HTTPRequest.RESULT_TIMEOUT, 0, PackedByteArray())


func _finish_request(http: HTTPRequest, result: int, code_http: int, body: PackedByteArray) -> void:
	if not _inflight.has(http):
		return
	var cb: Callable = _inflight[http]
	_inflight.erase(http)
	http.queue_free()
	cb.call(result, code_http, body)


func _game_state() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("GameState")
