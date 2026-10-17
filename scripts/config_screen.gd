extends Control
## Tela de configurações do MARÉ ALTA.
## - "Jogar em outro dispositivo": mostra SEU código + botão Copiar.
## - "Usar código": LineEdit + Buscar -> adota o progresso da nuvem.
## - Indicador de status da nuvem (texto simples, sem emoji: a fonte não tem glifos).
## OFFLINE-FIRST: sem chave/tabela, tudo mostra "offline" e o jogo segue local.

@onready var _code_label: Label = $Margin/Scroll/VBox/CardDevice/VBox/DeviceRow/CodeLabel
@onready var _btn_copiar: Button = $Margin/Scroll/VBox/CardDevice/VBox/DeviceRow/BtnCopiar
@onready var _code_edit: LineEdit = $Margin/Scroll/VBox/CardCode/VBox/CodeRow/CodeEdit
@onready var _btn_buscar: Button = $Margin/Scroll/VBox/CardCode/VBox/CodeRow/BtnBuscar
@onready var _status_label: Label = $Margin/Scroll/VBox/StatusRow/StatusLabel
@onready var _hint_label: Label = $Margin/Scroll/VBox/HintLabel
@onready var _btn_voltar: Button = $Margin/Scroll/VBox/BtnVoltar
@onready var _toast_panel: PanelContainer = $Toast
@onready var _toast_label: Label = $Toast/ToastLabel
@onready var _check_sound: CheckButton = $Margin/Scroll/VBox/CardPrefs/VBox/RowSound/CheckSound
@onready var _check_music: CheckButton = $Margin/Scroll/VBox/CardPrefs/VBox/RowMusic/CheckMusic
@onready var _check_notif: CheckButton = $Margin/Scroll/VBox/CardPrefs/VBox/RowNotif/CheckNotif
@onready var _btn_reset: Button = $Margin/Scroll/VBox/BtnReset
@onready var _version_label: Label = $Margin/Scroll/VBox/VersionLabel

var _toast_tween: Tween = null
var _reset_armed: bool = false


func _ready() -> void:
	_refresh_from_cloud()
	_sync_opt_checks()
	_version_label.text = "MARÉ ALTA v" + GameState.GAME_VERSION
	var cs := _cloud()
	if cs != null and cs.has_signal("status_changed"):
		cs.connect("status_changed", _on_cloud_status)
	_btn_copiar.pressed.connect(_on_copiar)
	_btn_buscar.pressed.connect(_on_buscar)
	_btn_voltar.pressed.connect(_on_voltar)
	_btn_reset.pressed.connect(_on_reset_pressed)
	_code_edit.text_changed.connect(_on_code_text_changed)
	_check_sound.toggled.connect(func(on: bool) -> void: GameState.set_opt("sound", on))
	_check_music.toggled.connect(func(on: bool) -> void: GameState.set_opt("music", on))
	_check_notif.toggled.connect(func(on: bool) -> void: GameState.set_opt("notifications", on))


func _cloud() -> Node:
	return get_tree().root.get_node_or_null("CloudSync")


func _refresh_from_cloud() -> void:
	var cs := _cloud()
	var my_code := "--------"
	var status_txt := "offline"
	if cs != null:
		if cs.has_method("get_code"):
			my_code = str(cs.call("get_code"))
		if cs.has_method("get_status_text"):
			status_txt = str(cs.call("get_status_text"))
	_code_label.text = my_code
	_update_status(status_txt)


func _update_status(status_txt: String) -> void:
	_status_label.text = status_txt
	_hint_label.visible = status_txt == "offline"


func _on_cloud_status(text: String) -> void:
	_update_status(text)


func _on_code_text_changed(new_text: String) -> void:
	var up := new_text.to_upper()
	if up != new_text:
		_code_edit.text = up
		_code_edit.caret_column = up.length()


func _on_copiar() -> void:
	var cs := _cloud()
	var my_code := _code_label.text
	if cs != null and cs.has_method("get_code"):
		my_code = str(cs.call("get_code"))
	DisplayServer.clipboard_set(my_code)
	show_toast("Código copiado!")


func _on_buscar() -> void:
	var cs := _cloud()
	if cs == null or not cs.has_method("fetch_by_code"):
		show_toast("Nuvem indisponível")
		return
	var clean := str(cs.call("sanitize_code", _code_edit.text))
	if clean.is_empty():
		show_toast("Digite o código de 8 letras")
		return
	_btn_buscar.disabled = true
	show_toast("Buscando na nuvem...")
	cs.call("fetch_by_code", clean, _on_fetch_done)


func _on_fetch_done(success: bool, msg: String) -> void:
	_btn_buscar.disabled = false
	show_toast(msg)
	if success:
		_refresh_from_cloud()


func _on_voltar() -> void:
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


## Sincroniza os toggles com o GameState (sem disparar o sinal toggled).
func _sync_opt_checks() -> void:
	_check_sound.set_pressed_no_signal(GameState.opt_sound)
	_check_music.set_pressed_no_signal(GameState.opt_music)
	_check_notif.set_pressed_no_signal(GameState.opt_notifications)


## Apagar progresso com confirmação dupla (segundo toque em até 5s).
func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_btn_reset.text = "Toque de novo para confirmar"
		show_toast("Apagar TODO o progresso? Toque de novo.")
		get_tree().create_timer(5.0).timeout.connect(_disarm_reset)
		return
	_reset_armed = false
	_btn_reset.text = "Apagar progresso"
	GameState.reset_progress()
	_sync_opt_checks()
	_refresh_from_cloud()
	show_toast("Progresso apagado.")


func _disarm_reset() -> void:
	_reset_armed = false
	if is_instance_valid(_btn_reset):
		_btn_reset.text = "Apagar progresso"


func show_toast(msg: String) -> void:
	_toast_label.text = msg
	_toast_panel.visible = true
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_panel.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(func() -> void: _toast_panel.visible = false)
