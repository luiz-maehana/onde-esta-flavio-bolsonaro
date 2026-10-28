extends Control
## Ficha do repórter (RF28/RF29): estatísticas, álbum de flagrantes (disfarce
## ainda não flagrado aparece como silhueta) e conquistas. Cada figura tem o
## nome embaixo ("???" se ainda não foi flagrado) — tooltip não aparece no
## toque e ficava ilegível.

const ALBUM_COLUMNS := 7
const ALBUM_PX := 60
const ALBUM_GAP := 8
## Largura mínima da casa do álbum: figura + moldura.
const ALBUM_CELL_MIN := 84
const CAPTION_SIZE := 18
## Largura da coluna de texto da ficha (NewspaperPage): em pé, a página menos
## as margens; deitado, também menos a coluna das conquistas.
const BODY_WIDTH_PORTRAIT := 672
const BODY_WIDTH_LANDSCAPE := 780
## Coluna das conquistas deitado: estreita o bastante pro álbum ter 7 por linha.
const ACHIEVEMENTS_WIDTH_LANDSCAPE := 340
const UNKNOWN := "???"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	AudioManager.play_music("title")
	var c := GameManager.career

	var page := NewspaperPage.new()
	add_child(page)
	page.set_texts("FICHA DO REPÓRTER", "%s — %s" % [c.player_name.to_upper(), c.rank()["title"].to_upper()])

	var stats := [
		Lang.t("Casos resolvidos: %d de %d") % [c.cases_solved, c.cases_played],
		Lang.t("Casos sem pisar em cidade errada: %d") % c.clean_wins,
		Lang.t("Melhor tempo: %s") % ("%dh" % c.best_hours if c.best_hours > 0 else "—"),
		Lang.t("Disfarces flagrados: %d de %d") % [c.disguises_caught.size(), GameData.disguises().size()],
		Lang.t("Escândalos cobertos: %d de %d") % [c.scandals_covered.size(), GameData.scandals().size()],
		Lang.t("Cidades visitadas: %d de %d") % [c.cities_visited.size(), GameData.cities().size()],
	]
	# deitado em 2 colunas: sobra altura pro álbum inteiro sem rolar
	var stats_grid := GridContainer.new()
	stats_grid.columns = 1 if Responsive.is_portrait() else 2
	stats_grid.add_theme_constant_override("h_separation", 24)
	for line in stats:
		var label := UiTheme.body(line, 24)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_grid.add_child(label)
	page.body_column.add_child(stats_grid)
	page.body_column.add_child(UiTheme.headline("ÁLBUM DE FLAGRANTES", 14, Palette.RED))
	page.body_column.add_child(_album(c))
	page.body_column.add_child(UiTheme.headline("PARCEIROS FLAGRADOS", 14, Palette.RED))
	page.body_column.add_child(_partners(c))

	page.photo_column.add_child(UiTheme.headline("CONQUISTAS", 14, Palette.RED))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420 if Responsive.is_portrait() else ACHIEVEMENTS_WIDTH_LANDSCAPE, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.photo_column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for a in Achievements.all():
		var got: bool = c.achievements.has(a["id"])
		var line := UiTheme.body("%s %s\n%s" % ["[X]" if got else "[ ]", a["title"], a["description"]], 24, Palette.INK if got else Palette.GREY)
		list.add_child(line)

	var back := UiTheme.button("VOLTAR", Vector2(180, 60))
	back.pressed.connect(GameManager.go_to_title)
	page.actions.add_child(back)
	back.call_deferred("grab_focus")

## Álbum de flagrantes: os 14 disfarces com o senador.
func _album(c: Career) -> GridContainer:
	var items: Array = GameData.disguises().map(func(d): return {
		"texture": PixelPortrait.flavio_disguised(d["id"]), "name": d["name"], "caught": c.disguises_caught.has(d["id"])})
	return _gallery(items)

## Parceiros flagrados (spec 009): retrato de procurado de cada parceiro.
func _partners(c: Career) -> GridContainer:
	var items: Array = GameData.partners().map(func(t): return {
		"texture": PixelPortrait.target(t["id"]), "name": t["name"], "caught": c.targets_caught.has(t["id"])})
	return _gallery(items)

## Grade de figuras com o nome embaixo ("???" no que falta). A casa tem a
## largura da palavra mais longa das legendas (nunca quebra palavra no meio);
## quantas cabem por linha sai da largura da coluna.
func _gallery(items: Array) -> GridContainer:
	var cell := _cell_width(items.map(func(i): return i["name"]))
	var width := BODY_WIDTH_PORTRAIT if Responsive.is_portrait() else BODY_WIDTH_LANDSCAPE
	var grid := GridContainer.new()
	grid.columns = clampi((width + ALBUM_GAP) / (cell + ALBUM_GAP), 3, ALBUM_COLUMNS)
	grid.add_theme_constant_override("h_separation", ALBUM_GAP)
	grid.add_theme_constant_override("v_separation", 12)
	for item in items:
		var caught: bool = item["caught"]
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		box.custom_minimum_size.x = cell
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", UiTheme.box(Palette.PAPER_DARK, Vector2.ZERO))
		frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var pic := PixelPortrait.make_rect(item["texture"], ALBUM_PX)
		if not caught:
			pic.modulate = Color(0, 0, 0, 0.85)
		frame.add_child(pic)
		box.add_child(frame)
		var caption := UiTheme.body(item["name"] if caught else UNKNOWN, CAPTION_SIZE, Palette.INK if caught else Palette.GREY)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.custom_minimum_size.x = cell
		caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		box.add_child(caption)
		grid.add_child(box)
	return grid

## Largura da casa: a palavra mais longa entre as legendas, na fonte e no
## idioma atuais.
func _cell_width(names: Array) -> int:
	var size := UiTheme.text_size(CAPTION_SIZE)
	var widest := 0.0
	for name in names:
		for word in str(name).split(" "):
			widest = maxf(widest, UiTheme.BODY_FONT.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	return maxi(ALBUM_CELL_MIN, ceili(widest) + 6)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameManager.go_to_title()
		get_viewport().set_input_as_handled()
