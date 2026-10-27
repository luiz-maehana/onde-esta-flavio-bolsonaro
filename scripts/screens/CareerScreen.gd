extends Control
## Ficha do repórter (RF28/RF29): estatísticas, álbum de flagrantes (disfarce
## ainda não flagrado aparece como silhueta) e conquistas.

const ALBUM_COLUMNS := 7
const ALBUM_PX := 60

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	AudioManager.play_music("title")
	var c := GameManager.career

	var page := NewspaperPage.new()
	add_child(page)
	page.set_texts("FICHA DO REPÓRTER", "%s — %s" % [c.player_name.to_upper(), c.rank()["title"].to_upper()])

	var stats := [
		"Casos resolvidos: %d de %d" % [c.cases_solved, c.cases_played],
		"Casos sem pisar em cidade errada: %d" % c.clean_wins,
		"Melhor tempo: %s" % ("%dh" % c.best_hours if c.best_hours > 0 else "—"),
		"Disfarces flagrados: %d de %d" % [c.disguises_caught.size(), GameData.disguises().size()],
		"Escândalos cobertos: %d de %d" % [c.scandals_covered.size(), GameData.scandals().size()],
		"Cidades visitadas: %d de %d" % [c.cities_visited.size(), GameData.cities().size()],
	]
	page.add_paragraph("\n".join(stats), 26)
	page.body_column.add_child(UiTheme.headline("ÁLBUM DE FLAGRANTES", 14, Palette.RED))
	page.body_column.add_child(_album(c))

	page.photo_column.add_child(UiTheme.headline("CONQUISTAS", 14, Palette.RED))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 330)
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

func _album(c: Career) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = ALBUM_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for d in GameData.disguises():
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", UiTheme.box(Palette.PAPER_DARK, Vector2.ZERO))
		var pic := PixelPortrait.make_rect(PixelPortrait.flavio_disguised(d["id"]), ALBUM_PX)
		if c.disguises_caught.has(d["id"]):
			pic.tooltip_text = d["name"]
		else:
			pic.modulate = Color(0, 0, 0, 0.85)
			pic.tooltip_text = "???"
		frame.add_child(pic)
		grid.add_child(frame)
	return grid

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameManager.go_to_title()
		get_viewport().set_input_as_handled()
