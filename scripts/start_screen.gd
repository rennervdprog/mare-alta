extends Control
## Tela inicial do MARÉ ALTA: logo, botão JOGAR pulsante, topbar e botões secundários.
## O botão JOGAR leva para a fase (res://main.tscn).

@onready var _jogar: Button = $BtnJogar
@onready var _logo_box: VBoxContainer = $LogoBox
@onready var _toast_panel: PanelContainer = $Toast
@onready var _toast_label: Label = $Toast/ToastLabel
@onready var _cloud_label: Label = $CloudLabel

var _pulse_tween: Tween = null
var _toast_tween: Tween = null
var _logo_base_y := 0.0


func _ready() -> void:
	_logo_base_y = _logo_box.position.y
	_start_logo_float()
	_start_jogar_pulse()
	# Valores reais do GameState (vidas ainda é placeholder: 5).
	($TopBar/PillVidas/Row/Label as Label).text = "5"
	($TopBar/PillEstrelas/Row/Label as Label).text = str(GameState.stars)
	($TopBar/PillMoedas/Row/Label as Label).text = str(GameState.coins)
	_jogar.pressed.connect(_on_jogar_pressed)
	_jogar.button_down.connect(_on_jogar_down)
	_jogar.button_up.connect(_on_jogar_up)
	$TopBar/BtnConfig.pressed.connect(_on_config_pressed)
	$SecRow/BtnFases.pressed.connect(_on_fases_pressed)
	$SecRow/BtnPremio.pressed.connect(func() -> void: show_toast("Prêmio diário em breve!"))
	$SecRow/BtnRanking.pressed.connect(func() -> void: show_toast("Ranking em breve!"))
	$SecRow/BtnLoja.pressed.connect(func() -> void: show_toast("Loja em breve!"))
	_update_cloud_status()
	var cs := get_tree().root.get_node_or_null("CloudSync")
	if cs != null and cs.has_signal("status_changed"):
		cs.connect("status_changed", _on_cloud_status_changed)


func _on_config_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/config_screen.tscn")


func _update_cloud_status() -> void:
	var cs := get_tree().root.get_node_or_null("CloudSync")
	if cs != null and cs.has_method("get_status_text"):
		_cloud_label.text = str(cs.call("get_status_text"))
	else:
		_cloud_label.text = ""


func _on_cloud_status_changed(_text: String) -> void:
	_update_cloud_status()


func _start_logo_float() -> void:
	var t := create_tween().set_loops()
	t.tween_property(_logo_box, "position:y", _logo_base_y - 10.0, 1.8).set_trans(Tween.TRANS_SINE)
	t.tween_property(_logo_box, "position:y", _logo_base_y + 6.0, 1.8).set_trans(Tween.TRANS_SINE)


func _start_jogar_pulse() -> void:
	_stop_pulse()
	_jogar.scale = Vector2.ONE
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_jogar, "scale", Vector2(1.06, 1.06), 0.8).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_jogar, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)


func _stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null


func _on_jogar_down() -> void:
	_stop_pulse()
	var t := create_tween()
	t.tween_property(_jogar, "scale", Vector2(0.93, 0.93), 0.08)


func _on_jogar_up() -> void:
	var t := create_tween()
	t.tween_property(_jogar, "scale", Vector2.ONE, 0.12)
	t.tween_callback(_start_jogar_pulse)


func _on_jogar_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_map.tscn")


func _on_fases_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_map.tscn")


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
