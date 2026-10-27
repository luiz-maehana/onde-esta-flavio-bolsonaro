class_name UiTheme
extends RefCounted
## Visual compartilhado de UI do jogo inteiro (mesmo papel do UiTheme do
## PPKMN): um Theme único aplicado na raiz de cada tela + fábricas de
## label/painel, pra nenhuma tela inventar estilo solto.
##
## Linguagem: recorte de jornal — sem canto arredondado, borda de tinta de
## 3px e sombra dura deslocada. Botão em papel, foco/hover em amarelo,
## pressionado em vermelho-sobretudo.

## Press Start 2P só nos logotipos (sem acento: os acentos em maiúscula dela
## somem). Títulos e botões usam Pixelify Sans Bold, que cobre o português.
const LOGO_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const HEADLINE_FONT_FILE := preload("res://assets/fonts/PixelifySans.ttf")
const BODY_FONT := preload("res://assets/fonts/VT323-Regular.ttf")
## Pixelify é menor que a Press Start no mesmo tamanho nominal; os tamanhos
## pedidos pelas telas foram pensados na escala da Press Start.
const HEADLINE_SCALE := 1.5

const BORDER := 3
const SHADOW := Vector2(5, 5)
const BODY_SIZE := 30
const BUTTON_FONT_SIZE := 14

static var _theme: Theme
static var _headline_font: FontVariation

static func headline_font() -> FontVariation:
	if _headline_font == null:
		_headline_font = FontVariation.new()
		_headline_font.base_font = HEADLINE_FONT_FILE
		_headline_font.variation_opentype = {"wght": 700}
	return _headline_font

static func scaled(size: int) -> int:
	return int(round(size * HEADLINE_SCALE))

static func theme() -> Theme:
	if _theme == null:
		_theme = _build_theme()
	return _theme

static func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = BODY_FONT
	t.default_font_size = BODY_SIZE

	t.set_stylebox("normal", "Button", box(Palette.PAPER))
	t.set_stylebox("hover", "Button", box(Palette.YELLOW))
	t.set_stylebox("focus", "Button", box(Palette.YELLOW))
	t.set_stylebox("pressed", "Button", box(Palette.RED, Vector2(2, 2)))
	t.set_stylebox("hover_pressed", "Button", box(Palette.RED, Vector2(2, 2)))
	t.set_stylebox("disabled", "Button", box(Palette.PAPER_DARK, Vector2.ZERO))
	t.set_font("font", "Button", headline_font())
	t.set_font_size("font_size", "Button", scaled(BUTTON_FONT_SIZE))
	for c in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(c, "Button", Palette.INK)
	t.set_color("font_pressed_color", "Button", Palette.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Palette.WHITE)
	t.set_color("font_disabled_color", "Button", Palette.GREY)

	t.set_color("font_color", "Label", Palette.INK)
	t.set_stylebox("panel", "PanelContainer", box(Palette.PAPER))

	t.set_color("default_color", "RichTextLabel", Palette.INK)
	t.set_font("normal_font", "RichTextLabel", BODY_FONT)
	t.set_font_size("normal_font_size", "RichTextLabel", BODY_SIZE)

	t.set_stylebox("normal", "LineEdit", box(Palette.WHITE, Vector2.ZERO))
	t.set_stylebox("focus", "LineEdit", box(Palette.WHITE, Vector2.ZERO, Palette.RED))
	t.set_color("font_color", "LineEdit", Palette.INK)
	t.set_color("caret_color", "LineEdit", Palette.RED)
	t.set_font_size("font_size", "LineEdit", 36)

	var bar := StyleBoxFlat.new()
	bar.bg_color = Palette.INK_SOFT
	t.set_stylebox("scroll", "VScrollBar", bar)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Palette.RED
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	return t

## Caixa padrão: fundo chapado, borda de tinta, sombra dura.
static func box(bg: Color, shadow: Vector2 = SHADOW, border: Color = Palette.INK) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(BORDER)
	sb.border_color = border
	if shadow != Vector2.ZERO:
		sb.shadow_color = Palette.INK
		sb.shadow_size = 1
		sb.shadow_offset = shadow
	sb.set_content_margin_all(12)
	return sb

static func panel(bg: Color = Palette.PAPER) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg))
	return p

## Manchete / título (Press Start 2P).
static func headline(text: String, size: int = 24, color: Color = Palette.INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", headline_font())
	l.add_theme_font_size_override("font_size", scaled(size))
	l.add_theme_color_override("font_color", color)
	return l

## Texto corrido (VT323), com quebra de linha.
static func body(text: String, size: int = BODY_SIZE, color: Color = Palette.INK) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func button(text: String, min_size: Vector2 = Vector2(0, 52)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func(): AudioManager.play_sfx(AudioManager.SFX_CLICK))
	return b

## Carimbo inclinado ("URGENTE", "FURO!"), borda colorida sem fundo. Vem
## dentro de um Control simples porque Container zera a rotação dos filhos
## diretos (fit_child_in_rect).
static func stamp(text: String, size: int = 18, color: Color = Palette.RED) -> Control:
	var holder := Control.new()
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(4)
	sb.border_color = color
	sb.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(headline(text, size, color))
	p.rotation_degrees = -6
	holder.add_child(p)
	holder.custom_minimum_size = p.get_combined_minimum_size() + Vector2(0, 24)
	p.position = Vector2(12, 18)
	return holder

## Faz a primeira opção de uma lista de botões receber o foco do teclado
## (RF12) assim que a tela/painel aparecer.
static func focus_first(buttons: Array) -> void:
	for b in buttons:
		if b is Button and b.visible and not b.disabled:
			b.call_deferred("grab_focus")
			return

## Logotipo em Press Start 2P (só texto sem acento: "O FURO", "F.U.R.O.").
static func logo(text: String, size: int, color: Color = Palette.INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", LOGO_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
