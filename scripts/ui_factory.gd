class_name UIFactory
extends RefCounted
## Fábrica de UI padrão Royal Kingdom para o MARÉ ALTA.
## Constrói: topbar em pílula vinho, tabbar de 5 abas, botões verdes glossy,
## pedestais 3D, etiquetas, painéis — tudo com os assets baked em
## res://assets/ui/baked/ e a fonte Baloo 2. Só apresentação.

const CREAM := Color(1.0, 0.973, 0.906)
const WINE := Color(0.557, 0.122, 0.192)
const WINE_DK := Color(0.43, 0.078, 0.141)
const GOLD := Color(0.961, 0.702, 0.004)
const GOLD_DK := Color(0.369, 0.227, 0.0)
const GREEN_DK_TXT := Color(0.184, 0.42, 0.047)
const NAVY_TXT := Color(0.055, 0.10, 0.15)

const BAKED := "res://assets/ui/baked/"
const ICONS := "res://assets/ui/icons/"
const COIN_CLEAN := "res://assets/ui/icons/icon-moeda-clean.png"
const HEART_ICON := "res://assets/ui/icons/media-generation-icon-coracao-0-b2a50254-7e8f-4ecc-89c6-ce014df89a8b.webp"
const STAR_ICON := "res://assets/ui/icons/media-generation-icon-estrela-0-f26c7110-ac23-448a-93d7-821c08f3c61b.webp"
const GEAR_ICON := "res://assets/ui/icons/media-generation-icon-engrenagem-0-693f1315-f3e2-4f9e-a12a-1fdb7ea90d97.webp"
const SHOP_ICON := "res://assets/ui/icons/media-generation-icon-loja-0-41d9ffa1-503c-42b1-a32f-01af20ab0c1f.webp"
const GIFT_ICON := "res://assets/ui/icons/media-generation-icon-presente-0-9bbdb947-3fc7-4a0a-b2a7-acd94afb67d3.webp"
const TROPHY_ICON := "res://assets/ui/icons/media-generation-icon-trofeu-0-ed77eb1b-d428-484b-b659-5187e939bfa5.webp"
const MAP_ICON := "res://assets/ui/icons/media-generation-icon-mapa-0-59b53f7a-8c14-44ea-8e45-a672a4e6bef6.webp"
const MARINA_CIRCLE := "res://assets/ui/baked/portrait_marina_circle.png"
const CLAUDIO_CIRCLE := "res://assets/ui/baked/portrait_claudio_circle.png"

static var _f800: Font = null
static var _f700: Font = null
static var _styles: Dictionary = {}


static func f800() -> Font:
	if _f800 == null:
		_f800 = load("res://assets/fonts/Baloo2-800.ttf") as Font
	return _f800


static func f700() -> Font:
	if _f700 == null:
		_f700 = load("res://assets/fonts/Baloo2-700.ttf") as Font
	return _f700


static func tex_style(path: String) -> StyleBoxTexture:
	if not _styles.has(path):
		var sb := StyleBoxTexture.new()
		sb.texture = load(path) as Texture2D
		_styles[path] = sb
	return _styles[path] as StyleBoxTexture


## Label bubbly: Baloo 2 ExtraBold, creme, contorno atrás (Godot desenha o
## outline antes do fill — equivalente ao paint-order: stroke fill).
static func bubbly(text: String, size: int, outline_color: Color, outline_px: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f800())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", CREAM)
	l.add_theme_color_override("font_outline_color", outline_color)
	var px := outline_px
	if px <= 0:
		px = maxi(2, int(size * 0.08))
	l.add_theme_constant_override("outline_size", px)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(2, size / 18))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func ui_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f700())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## Botão verde glossy (textura baked 9 camadas).
static func green_button(text: String, font_size: int, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_override("font", f800())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", CREAM)
	b.add_theme_color_override("font_pressed_color", CREAM)
	b.add_theme_color_override("font_outline_color", GREEN_DK_TXT)
	b.add_theme_constant_override("outline_size", maxi(3, int(font_size * 0.09)))
	var normal := (tex_style(BAKED + "btn_green.png") as StyleBoxTexture).duplicate() as StyleBoxTexture
	normal.content_margin_left = 36.0
	normal.content_margin_right = 36.0
	normal.content_margin_top = 14.0
	normal.content_margin_bottom = 14.0
	var pressed := (tex_style(BAKED + "btn_green_pressed.png") as StyleBoxTexture).duplicate() as StyleBoxTexture
	pressed.content_margin_left = 36.0
	pressed.content_margin_right = 36.0
	pressed.content_margin_top = 14.0
	pressed.content_margin_bottom = 14.0
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", normal)
	b.add_theme_stylebox_override("disabled", normal)
	return b


static func flat_button() -> Button:
	var b := Button.new()
	var sb := StyleBoxEmpty.new()
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", sb)
	return b


static func icon_rect(path: String, size: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path) as Texture2D
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Topbar em pílula vinho única: avatar da Marina vazando, moedas com "+",
## vidas com "Cheio", estrelas, engrenagem. Retorna refs dos labels/botões.
static func topbar() -> Dictionary:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.custom_minimum_size = Vector2(720, 140)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pill := Panel.new()
	pill.add_theme_stylebox_override("panel", tex_style(BAKED + "pill_wine.png"))
	pill.position = Vector2(16, 44)
	pill.size = Vector2(688, 68)
	root.add_child(pill)

	var avatar := icon_rect(MARINA_CIRCLE, 88)
	avatar.position = Vector2(0, 28)
	avatar.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(avatar)

	var coin_icon := icon_rect(COIN_CLEAN, 44)
	coin_icon.position = Vector2(104, 56)
	root.add_child(coin_icon)
	var coins := ui_label("120", 30, Color.WHITE)
	coins.position = Vector2(150, 48)
	coins.size = Vector2(90, 60)
	coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(coins)
	var plus := flat_button()
	plus.add_theme_stylebox_override("normal", tex_style(BAKED + "btn_green.png"))
	plus.add_theme_stylebox_override("hover", tex_style(BAKED + "btn_green.png"))
	plus.add_theme_stylebox_override("pressed", tex_style(BAKED + "btn_green_pressed.png"))
	plus.add_theme_stylebox_override("focus", tex_style(BAKED + "btn_green.png"))
	plus.position = Vector2(228, 59)
	plus.size = Vector2(48, 48)
	var plus_l := bubbly("+", 32, GREEN_DK_TXT)
	plus_l.set_anchors_preset(Control.PRESET_FULL_RECT)
	plus_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plus.add_child(plus_l)
	root.add_child(plus)

	var heart_icon := icon_rect(HEART_ICON, 44)
	heart_icon.position = Vector2(286, 56)
	root.add_child(heart_icon)
	var lives := ui_label("5", 30, Color.WHITE)
	lives.position = Vector2(332, 48)
	lives.size = Vector2(44, 60)
	lives.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(lives)
	var full := ui_label("Cheio", 17, Color(0.61, 0.89, 0.08))
	full.position = Vector2(372, 62)
	full.size = Vector2(70, 36)
	full.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(full)

	var star_icon := icon_rect(STAR_ICON, 44)
	star_icon.position = Vector2(452, 56)
	root.add_child(star_icon)
	var stars := ui_label("0", 30, Color.WHITE)
	stars.position = Vector2(498, 48)
	stars.size = Vector2(80, 60)
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(stars)

	var gear := flat_button()
	gear.custom_minimum_size = Vector2(56, 56)
	gear.position = Vector2(632, 50)
	gear.size = Vector2(56, 56)
	var gear_icon := icon_rect(GEAR_ICON, 52)
	gear_icon.position = Vector2(2, 2)
	gear.add_child(gear_icon)
	root.add_child(gear)

	return {"root": root, "coins": coins, "lives": lives, "full": full, "stars": stars,
		"gear": gear, "plus": plus}


## Toast simples centralizado que some sozinho.
static func toast(parent: Node, msg: String) -> void:
	var l := bubbly(msg, 30, WINE_DK)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.position = Vector2(-280, -40)
	l.size = Vector2(560, 80)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	l.modulate.a = 0.0
	var tw := parent.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


## Tabbar de 5 abas com centro elevado rompendo a barra.
## center: {"id": "inicio"/"mapa", "label": "Início"/"Mapa", "icon": path}
## Retorna {"root": Control, "tabs": {id: Button}}.
static func tabbar(center: Dictionary) -> Dictionary:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	root.offset_top = -116.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bar := Panel.new()
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bar_sb := StyleBoxFlat.new()
	bar_sb.bg_color = Color(0.659, 0.137, 0.22)
	bar.add_theme_stylebox_override("panel", bar_sb)
	root.add_child(bar)
	var strip := TextureRect.new()
	strip.texture = load(BAKED + "strip_gold.png") as Texture2D
	strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	strip.custom_minimum_size = Vector2(720, 8)
	strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	strip.stretch_mode = TextureRect.STRETCH_SCALE
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(strip)

	var tabs := {}
	var defs: Array = [
		{"id": "loja", "label": "Loja", "icon": SHOP_ICON},
		{"id": "premio", "label": "Prêmio", "icon": GIFT_ICON},
		{"id": "centro", "label": center["label"], "icon": center["icon"]},
		{"id": "ranking", "label": "Ranking", "icon": TROPHY_ICON},
		{"id": "fases", "label": "Fases", "icon": STAR_ICON},
	]
	var xs := [16.0, 158.0, 285.0, 462.0, 592.0]
	for i in defs.size():
		var d: Dictionary = defs[i]
		var b := flat_button()
		if String(d["id"]) == "centro":
			# Aba central elevada: arco vinho+dourado rompendo a barra (~1/3 pra fora).
			b.add_theme_stylebox_override("normal", tex_style(BAKED + "panel_wine_gold.png"))
			b.add_theme_stylebox_override("hover", tex_style(BAKED + "panel_wine_gold.png"))
			b.add_theme_stylebox_override("pressed", tex_style(BAKED + "panel_wine_gold.png"))
			b.position = Vector2(xs[i], -44)
			b.size = Vector2(150, 150)
			var ic := icon_rect(String(d["icon"]), 62)
			ic.position = Vector2(44, 22)
			b.add_child(ic)
			var lb := ui_label(String(d["label"]), 21, CREAM)
			lb.position = Vector2(0, 96)
			lb.size = Vector2(150, 34)
			lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(lb)
		else:
			b.position = Vector2(xs[i], 12)
			b.size = Vector2(112, 100)
			var ic2 := icon_rect(String(d["icon"]), 54)
			ic2.position = Vector2(29, 4)
			b.add_child(ic2)
			var lb2 := ui_label(String(d["label"]), 19, Color(1.0, 0.85, 0.66))
			lb2.position = Vector2(0, 62)
			lb2.size = Vector2(112, 30)
			lb2.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(lb2)
		root.add_child(b)
		tabs[String(d["id"])] = b
	return {"root": root, "tabs": tabs}


## Pedestal 3D: ícone sobre disco dourado sobre fita vinho (totem).
static func pedestal(icon_path: String, label_text: String) -> Button:
	var b := flat_button()
	b.custom_minimum_size = Vector2(150, 196)
	var icon := icon_rect(icon_path, 62)
	icon.position = Vector2(44, 0)
	b.add_child(icon)
	var disc := TextureRect.new()
	disc.texture = load(BAKED + "disc_gold.png") as Texture2D
	disc.position = Vector2(27, 42)
	disc.size = Vector2(96, 84)
	disc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	disc.stretch_mode = TextureRect.STRETCH_SCALE
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(disc)
	var ribbon := Panel.new()
	ribbon.add_theme_stylebox_override("panel", tex_style(BAKED + "ribbon_wine.png"))
	ribbon.position = Vector2(0, 108)
	ribbon.size = Vector2(150, 80)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ribbon)
	var lb := bubbly(label_text, 25, WINE_DK)
	lb.position = Vector2(0, 118)
	lb.size = Vector2(150, 60)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lb)
	return b


## Etiqueta (Metas/Jogadas) que estranda a borda da pílula.
static func tag_label(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", tex_style(BAKED + "tag_wine.png"))
	var l := bubbly(text, 22, WINE_DK)
	l.add_theme_constant_override("outline_size", 3)
	p.add_child(l)
	return p
