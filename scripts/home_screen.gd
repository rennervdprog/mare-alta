extends Control
## Home / Mapa do MARÉ ALTA — padrão híbrido Royal Kingdom.
## Arte da área atual como fundo, faixa "Praia · N de 60", botão verde gigante
## "Fase X" (1 toque para jogar), pedestais 3D "Mundo" (mapa de nós p/ rejogar)
## e "Reforma", topbar em pílula vinho e tabbar de 5 abas.

const SHORT_NAMES := ["Praia", "Bar", "Cozinha", "Deck", "Palco"]

var _fase_btn: Button
var _pulse_tween: Tween = null
var _tb: Dictionary = {}


func _ready() -> void:
	var area_id := GameState.area_of_level(GameState.unlocked_level)
	var area: Dictionary = GameState.AREAS[area_id - 1]
	_build_background(area)
	_build_topbar()
	_build_back()
	_build_strip(area_id, area)
	_build_pedestals(area_id)
	_build_fase_button()
	_build_tabbar()
	_start_pulse()


func _build_background(area: Dictionary) -> void:
	var bg := TextureRect.new()
	bg.texture = load(String(area["after"])) as Texture2D
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.12)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _build_topbar() -> void:
	_tb = UIFactory.topbar()
	add_child(_tb["root"] as Control)
	(_tb["gear"] as Button).pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/config_screen.tscn"))
	(_tb["plus"] as Button).pressed.connect(func() -> void: _open_teaser("loja"))
	_refresh_topbar()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_refresh_topbar)
	add_child(timer)
	timer.start()


func _refresh_topbar() -> void:
	if _tb.is_empty():
		return
	GameState.refresh_lives()
	(_tb["coins"] as Label).text = str(GameState.coins)
	(_tb["stars"] as Label).text = str(GameState.stars)
	(_tb["lives"] as Label).text = str(GameState.lives)
	(_tb["full"] as Label).text = GameState.lives_display()


func _build_back() -> void:
	var back := UIFactory.flat_button()
	back.position = Vector2(16, 128)
	back.size = Vector2(150, 56)
	var pill := Panel.new()
	pill.add_theme_stylebox_override("panel", UIFactory.tex_style(UIFactory.BAKED + "pill_wine.png"))
	pill.set_anchors_preset(Control.PRESET_FULL_RECT)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(pill)
	var lb := UIFactory.ui_label("Início", 24, UIFactory.CREAM)
	lb.set_anchors_preset(Control.PRESET_FULL_RECT)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(lb)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/start_screen.tscn"))
	add_child(back)


func _build_strip(area_id: int, area: Dictionary) -> void:
	var from: int = int(area["from"])
	var n := GameState.unlocked_level - from + 1
	var pill := Panel.new()
	pill.add_theme_stylebox_override("panel", UIFactory.tex_style(UIFactory.BAKED + "pill_wine.png"))
	pill.position = Vector2(110, 200)
	pill.size = Vector2(500, 64)
	add_child(pill)
	var lb := UIFactory.bubbly("%s · %d de 60" % [SHORT_NAMES[area_id - 1], n], 30, UIFactory.WINE_DK)
	lb.position = Vector2(110, 200)
	lb.size = Vector2(500, 64)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lb)


func _build_pedestals(area_id: int) -> void:
	var mundo := UIFactory.pedestal(UIFactory.MAP_ICON, "Mundo")
	mundo.position = Vector2(180, 620)
	mundo.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/level_map.tscn"))
	add_child(mundo)
	var reforma := UIFactory.pedestal(UIFactory.GIFT_ICON, "Reforma")
	reforma.position = Vector2(390, 620)
	reforma.pressed.connect(func() -> void: _on_reforma(area_id))
	add_child(reforma)


func _on_reforma(area_id: int) -> void:
	GameState.current_area = area_id
	get_tree().change_scene_to_file("res://scenes/renovation.tscn")


func _build_fase_button() -> void:
	_fase_btn = UIFactory.green_button("Fase %d" % GameState.unlocked_level, 52, Vector2(400, 120))
	_fase_btn.position = Vector2(160, 930)
	_fase_btn.size = Vector2(400, 120)
	_fase_btn.pivot_offset = Vector2(200, 60)
	_fase_btn.pressed.connect(_on_fase_pressed)
	add_child(_fase_btn)


func _on_fase_pressed() -> void:
	if not GameState.can_play():
		UIFactory.toast(self, "Sem vidas! Próxima em %s" % GameState.lives_display())
		return
	GameState.current_level = GameState.unlocked_level
	get_tree().change_scene_to_file("res://main.tscn")


func _build_tabbar() -> void:
	var tb: Dictionary = UIFactory.tabbar({"label": "Mapa", "icon": UIFactory.MAP_ICON})
	add_child(tb["root"] as Control)
	var tabs: Dictionary = tb["tabs"] as Dictionary
	(tabs["loja"] as Button).pressed.connect(func() -> void: _open_teaser("loja"))
	(tabs["premio"] as Button).pressed.connect(func() -> void: _open_teaser("premio"))
	(tabs["ranking"] as Button).pressed.connect(func() -> void: _open_teaser("ranking"))
	(tabs["fases"] as Button).pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/level_map.tscn"))
	# centro = Mapa: já estamos aqui.


func _open_teaser(feature: String) -> void:
	TeaserScreen.feature = feature
	TeaserScreen.return_scene = "res://scenes/home_screen.tscn"
	get_tree().change_scene_to_file("res://scenes/teaser.tscn")


func _start_pulse() -> void:
	_fase_btn.scale = Vector2.ONE
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_fase_btn, "scale", Vector2(1.05, 1.05), 0.9).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_fase_btn, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)
