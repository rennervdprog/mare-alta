class_name TeaserScreen
extends Control
## Teaser de recurso bloqueado — padrão Royal Kingdom: o recurso aparece como
## propaganda dele mesmo ("Alcance a Fase X"), nunca "Em breve!", nunca escondido.
## Uso: TeaserScreen.feature = "loja"|"premio"|"ranking";
##      TeaserScreen.return_scene = "res://scenes/start_screen.tscn";
##      get_tree().change_scene_to_file("res://scenes/teaser.tscn")

static var feature := "loja"
static var return_scene := "res://scenes/start_screen.tscn"

const FEATURES := {
	"loja": {
		"title": "Loja",
		"icon": UIFactory.SHOP_ICON,
		"unlock": 10,
		"benefits": [
			"Moedas e boosters com desconto",
			"Ofertas por tempo limitado",
			"100 moedas [b]GRÁTIS[/b] na abertura",
		],
	},
	"premio": {
		"title": "Prêmio Diário",
		"icon": UIFactory.GIFT_ICON,
		"unlock": 5,
		"benefits": [
			"Um prêmio todo dia",
			"Sequência de 7 dias = baú dourado",
			"Tudo [b]GRÁTIS[/b], sem anúncio",
		],
	},
	"ranking": {
		"title": "Ranking",
		"icon": UIFactory.TROPHY_ICON,
		"unlock": 21,
		"benefits": [
			"Dispute com seus amigos",
			"Prêmios semanais por posição",
			"Suba de liga [b]GRÁTIS[/b]",
		],
	},
}


func _ready() -> void:
	var cfg: Dictionary = FEATURES.get(feature, FEATURES["loja"])
	_build_bg()
	_build_sheet(cfg)
	_build_tabbar()


func _build_bg() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.078, 0.106, 0.173) # navy escuro
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


func _build_sheet(cfg: Dictionary) -> void:
	var sheet := Panel.new()
	sheet.add_theme_stylebox_override("panel", UIFactory.tex_style(UIFactory.BAKED + "panel_navy_gold.png"))
	# Centralizada na área acima da tabbar — acompanha qualquer altura de tela.
	sheet.set_anchors_preset(Control.PRESET_CENTER)
	sheet.offset_left = -320.0
	sheet.offset_right = 320.0
	sheet.offset_top = -440.0
	sheet.offset_bottom = 440.0
	add_child(sheet)

	var title := UIFactory.bubbly(String(cfg["title"]), 52, UIFactory.NAVY_TXT)
	title.position = Vector2(0, 36)
	title.size = Vector2(640, 70)
	sheet.add_child(title)

	var illu := UIFactory.icon_rect(String(cfg["icon"]), 150)
	illu.position = Vector2(245, 130)
	illu.size = Vector2(150, 150)
	sheet.add_child(illu)

	var msg := UIFactory.bubbly("Alcance a Fase %d\npara desbloquear!" % int(cfg["unlock"]), 36, UIFactory.NAVY_TXT)
	msg.position = Vector2(40, 310)
	msg.size = Vector2(560, 110)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet.add_child(msg)

	var y := 450.0
	for b in cfg["benefits"]:
		var row := RichTextLabel.new()
		row.bbcode_enabled = true
		row.text = "[color=#9be315]✓[/color]  [color=#fff8e7]%s[/color]" % String(b).replace("[b]", "[color=#ffd75e][b]").replace("[/b]", "[/b][/color]")
		row.add_theme_font_override("normal_font", UIFactory.f700())
		row.add_theme_font_override("bold_font", UIFactory.f800())
		row.add_theme_font_size_override("normal_font_size", 27)
		row.add_theme_font_size_override("bold_font_size", 27)
		row.position = Vector2(70, y)
		row.size = Vector2(520, 60)
		row.scroll_active = false
		sheet.add_child(row)
		y += 64.0

	var cta := UIFactory.green_button("Entendi", 34, Vector2(320, 92))
	cta.position = Vector2(160, 720)
	cta.size = Vector2(320, 92)
	cta.pressed.connect(_on_back)
	sheet.add_child(cta)


func _build_tabbar() -> void:
	var tb: Dictionary = UIFactory.tabbar({"label": "Início", "icon": UIFactory.MAP_ICON})
	add_child(tb["root"] as Control)
	var tabs: Dictionary = tb["tabs"] as Dictionary
	(tabs["loja"] as Button).pressed.connect(func() -> void: _open_feature("loja"))
	(tabs["premio"] as Button).pressed.connect(func() -> void: _open_feature("premio"))
	(tabs["ranking"] as Button).pressed.connect(func() -> void: _open_feature("ranking"))
	(tabs["fases"] as Button).pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/level_map.tscn"))
	(tabs["centro"] as Button).pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/start_screen.tscn"))


func _open_feature(f: String) -> void:
	TeaserScreen.feature = f
	get_tree().change_scene_to_file("res://scenes/teaser.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file(TeaserScreen.return_scene)
