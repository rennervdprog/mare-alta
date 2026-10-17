extends Control
## Tela inicial do MARÉ ALTA — padrão Royal Kingdom.
## Topbar em pílula vinho (avatar da Marina vazando, moedas com "+", vidas
## "Cheio", estrelas, engrenagem), título bubbly Baloo 2, botão JOGAR verde
## glossy pulsante e tabbar de 5 abas com centro elevado.
## JOGAR leva para a home (res://scenes/home_screen.tscn).

const KEYART := "res://assets/ui/media-generation-tela-inicial-keyart-0-f07ba8e3-8ee1-4ff0-aaf6-93e84967cc1d.webp"

var _jogar: Button
var _pulse_tween: Tween = null
var _logo_box: VBoxContainer
var _logo_base_y := 0.0
var _cloud_label: Label
var _tb: Dictionary = {}


func _ready() -> void:
	_build_background()
	_build_topbar()
	_build_logo()
	_build_jogar()
	_build_tabbar()
	_build_cloud_label()
	_start_logo_float()
	_start_jogar_pulse()


func _build_background() -> void:
	var bg := TextureRect.new()
	bg.texture = load(KEYART) as Texture2D
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)


func _build_topbar() -> void:
	_tb = UIFactory.topbar()
	add_child(_tb["root"] as Control)
	(_tb["gear"] as Button).pressed.connect(_on_config_pressed)
	(_tb["plus"] as Button).pressed.connect(func() -> void: _open_teaser("loja"))
	_refresh_topbar()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_refresh_topbar)
	add_child(timer)
	timer.start()


## Atualiza moedas/estrelas/vidas; vidas mostram "Cheio" ou o mm:ss da próxima.
func _refresh_topbar() -> void:
	if _tb.is_empty():
		return
	GameState.refresh_lives()
	(_tb["coins"] as Label).text = str(GameState.coins)
	(_tb["stars"] as Label).text = str(GameState.stars)
	(_tb["lives"] as Label).text = str(GameState.lives)
	(_tb["full"] as Label).text = GameState.lives_display()


func _build_logo() -> void:
	_logo_box = VBoxContainer.new()
	_logo_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_logo_box.position = Vector2(60, 150)
	_logo_box.size = Vector2(600, 220)
	_logo_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_logo_box.add_theme_constant_override("separation", 2)
	add_child(_logo_box)
	var title := UIFactory.bubbly("MARÉ ALTA", 104, Color(0.478, 0.29, 0.0))
	_logo_box.add_child(title)
	var sub := UIFactory.bubbly("o quiosque da Marina", 34, Color(0.369, 0.227, 0.0))
	_logo_box.add_child(sub)


func _build_jogar() -> void:
	_jogar = UIFactory.green_button("JOGAR", 56, Vector2(420, 120))
	_jogar.position = Vector2(150, 940)
	_jogar.size = Vector2(420, 120)
	_jogar.pivot_offset = Vector2(210, 60)
	_jogar.pressed.connect(_on_jogar_pressed)
	_jogar.button_down.connect(_on_jogar_down)
	_jogar.button_up.connect(_on_jogar_up)
	add_child(_jogar)


func _build_tabbar() -> void:
	var tb: Dictionary = UIFactory.tabbar({"label": "Início", "icon": UIFactory.MAP_ICON})
	add_child(tb["root"] as Control)
	var tabs: Dictionary = tb["tabs"] as Dictionary
	(tabs["loja"] as Button).pressed.connect(func() -> void: _open_teaser("loja"))
	(tabs["premio"] as Button).pressed.connect(func() -> void: _open_teaser("premio"))
	(tabs["ranking"] as Button).pressed.connect(func() -> void: _open_teaser("ranking"))
	(tabs["fases"] as Button).pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/level_map.tscn"))
	# centro = Início: já estamos aqui.


func _build_cloud_label() -> void:
	_cloud_label = UIFactory.ui_label("", 20, Color(1, 1, 1, 0.75))
	_cloud_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_cloud_label.position = Vector2(160, 1120)
	_cloud_label.size = Vector2(400, 30)
	add_child(_cloud_label)
	_update_cloud_status()
	var cs := get_tree().root.get_node_or_null("CloudSync")
	if cs != null and cs.has_signal("status_changed"):
		cs.connect("status_changed", _on_cloud_status_changed)


func _open_teaser(feature: String) -> void:
	TeaserScreen.feature = feature
	TeaserScreen.return_scene = "res://scenes/start_screen.tscn"
	get_tree().change_scene_to_file("res://scenes/teaser.tscn")


func _on_config_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/config_screen.tscn")


func _on_jogar_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/home_screen.tscn")


func _update_cloud_status() -> void:
	var cs := get_tree().root.get_node_or_null("CloudSync")
	if cs != null and cs.has_method("get_status_text"):
		_cloud_label.text = str(cs.call("get_status_text"))
	else:
		_cloud_label.text = ""


func _on_cloud_status_changed(_text: String) -> void:
	_update_cloud_status()


func _start_logo_float() -> void:
	_logo_base_y = _logo_box.position.y
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
