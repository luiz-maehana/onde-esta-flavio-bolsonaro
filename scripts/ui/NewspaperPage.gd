class_name NewspaperPage
extends Control
## Esqueleto de capa de jornal reutilizado pelo briefing (US3) e pelo
## desfecho (US9): papel, cabeçalho "O FURO", manchete, coluna de texto à
## esquerda, foto à direita e uma linha de botões. Quem usa só preenche.
## Em pé (RF36): uma coluna só, foto em cima; botões quebram linha. O
## miolo rola se não couber.

var body_column: VBoxContainer
var photo_column: VBoxContainer
var actions: Container
var _headline: Label
var _edition: Label

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var paper := ColorRect.new()
	paper.color = Palette.PAPER
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(paper)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var portrait := Responsive.is_portrait()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24 if portrait else 56)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)

	var masthead := UiTheme.logo("O FURO", 44)
	masthead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(masthead)
	_edition = UiTheme.body("", 24, Palette.GREY)
	_edition.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_edition)
	page.add_child(_rule(6))

	_headline = UiTheme.headline("", 22)
	_headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_headline.add_theme_constant_override("line_spacing", -6)
	page.add_child(_headline)
	page.add_child(_rule(2))

	var columns := Responsive.flow_box()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20 if portrait else 36)
	# rola nas duas orientações: capa com história longa + conquistas passa
	# da altura da tela até deitado
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	scroll.add_child(columns)
	body_column = VBoxContainer.new()
	body_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_column.add_theme_constant_override("separation", 14)
	photo_column = VBoxContainer.new()
	photo_column.add_theme_constant_override("separation", 8)
	if portrait:
		photo_column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		columns.add_child(photo_column)
		columns.add_child(body_column)
	else:
		columns.add_child(body_column)
		columns.add_child(photo_column)

	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_END
	flow.add_theme_constant_override("h_separation", 16)
	flow.add_theme_constant_override("v_separation", 12)
	Responsive.fill_row(flow)
	actions = flow
	page.add_child(actions)

func set_texts(edition: String, headline: String) -> void:
	_edition.text = edition
	_headline.text = headline

## Foto emoldurada com legenda (retrato em pixel art, 48px em escala 4).
func add_photo(texture: Texture2D, caption: String) -> void:
	photo_column.add_child(_photo(texture, caption, 192, 280))

## Duas fotos lado a lado (FLAGRANTE x FOTO OFICIAL), escala 3 cada.
func add_photo_pair(left: Texture2D, left_caption: String, right: Texture2D, right_caption: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(_photo(left, left_caption, 144, 160))
	row.add_child(_photo(right, right_caption, 144, 160))
	photo_column.add_child(row)

func _photo(texture: Texture2D, caption: String, display_px: int, caption_width: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.box(Palette.PAPER_DARK))
	frame.add_child(PixelPortrait.make_rect(texture, display_px))
	col.add_child(frame)
	var cap := UiTheme.body(caption, 22, Palette.GREY)
	cap.custom_minimum_size.x = caption_width
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(cap)
	return col

func add_paragraph(text: String, size: int = 30) -> Label:
	var l := UiTheme.body(text, size)
	body_column.add_child(l)
	return l

## Box factual ("ENTENDA O CASO") — fato real, status jurídico e veículo de
## origem, visualmente separado do texto de piada (spec 002, RF14).
func add_fact_box(title: String, summary: String, status: String, outlet: String) -> void:
	var box := PanelContainer.new()
	var style := UiTheme.box(Palette.PAPER_DARK, Vector2.ZERO)
	style.set_content_margin_all(10)
	box.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	box.add_child(col)
	# quebra linha: em inglês/espanhol o título fica bem mais comprido
	var heading := UiTheme.headline(title, 12, Palette.RED)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(heading)
	col.add_child(UiTheme.body(summary, 23))
	col.add_child(UiTheme.body(Lang.t("Status: %s") % status, 23, Palette.RED_DARK))
	col.add_child(UiTheme.body(Lang.t("Fontes: %s") % outlet, 20, Palette.GREY))
	body_column.add_child(box)

func _rule(thickness: int) -> ColorRect:
	var r := ColorRect.new()
	r.color = Palette.INK
	r.custom_minimum_size.y = thickness
	return r
