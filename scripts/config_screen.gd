extends Control
## Tela de configurações do MARÉ ALTA.
## - "Jogar em outro dispositivo": mostra SEU código + botão Copiar.
## - "Usar código": LineEdit + Buscar -> adota o progresso da nuvem.
## - Indicador de status da nuvem (texto simples, sem emoji: a fonte não tem glifos).
## OFFLINE-FIRST: sem chave/tabela, tudo mostra "offline" e o jogo segue local.

@onready var _code_label: Label = $Margin/VBox/CardDevice/VBox/DeviceRow/CodeLabel
@onready var _btn_copiar: Button = $Margin/VBox/CardDevice/VBox/DeviceRow/BtnCopiar
@onready var _code_edit: LineEdit = $Margin/VBox/CardCode/VBox/CodeRow/CodeEdit
@onready var _btn_buscar: Button = $Margin/VBox/CardCode/VBox/CodeRow/BtnBuscar
@onready var _status_label: Label = $Margin/VBox/StatusRow/StatusLabel
@onready var _hint_label: Label = $Margin/VBox/HintLabel
@onready var _btn_voltar: Button = $Margin/VBox/BtnVoltar
@onready var _toast_panel: PanelContainer = $Toast
@onready var _toast_label: Label = $Toast/ToastLabel

var _toast_tween: Tween = null


func _ready() -> void:
	_refresh_from_cloud()
	var cs := _cloud()
	if cs != null and cs.has_signal("status_changed"):
		cs.connect("status_changed", _on_cloud_status)
	_btn_copiar.pressed.connect(_on_copiar)
	_btn_buscar.pressed.connect(_on_buscar)
	_btn_voltar.pressed.connect(_on_voltar)
	_code_edit.text_changed.connect(_on_code_text_changed)


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
