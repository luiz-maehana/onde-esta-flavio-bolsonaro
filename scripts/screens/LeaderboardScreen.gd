extends Control
## Ranking online (RF41): top 50 da semana ou geral, vindo da API. Suas
## entradas (mesmo aparelho) aparecem destacadas.

const COLUMNS := [["#", 50], ["REPÓRTER", 300], ["CARGO", 230], ["PONTOS", 120], ["HORAS", 100], ["ONDE", 200]]

var _list: VBoxContainer
var _status: Label
var _tabs: Array = []
var _period := "week"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	AudioManager.play_music("title")
	var page := NewspaperPage.new()
	add_child(page)
	page.set_texts("CLASSIFICADOS DA REDAÇÃO", "RANKING DOS REPÓRTERES")

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for t in [["week", "DA SEMANA"], ["all", "GERAL"]]:
		var b := UiTheme.button(t[1], Vector2(200, 48))
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = t[0] == _period
		b.toggled.connect(func(on):
			if on:
				_period = t[0]
				_load())
		tabs.add_child(b)
		_tabs.append(b)
	var badge := OnlineBadge.new()
	tabs.add_child(badge)
	page.body_column.add_child(tabs)

	page.body_column.add_child(_row(COLUMNS.map(func(c): return c[0]), Palette.RED, true))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 240
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.body_column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_status = UiTheme.body("", 28, Palette.GREY)
	page.body_column.add_child(_status)
	page.photo_column.visible = false

	var back := UiTheme.button("VOLTAR", Vector2(180, 60))
	back.pressed.connect(GameManager.go_to_title)
	page.actions.add_child(back)
	UiTheme.focus_first(_tabs)
	_load()

func _load() -> void:
	for child in _list.get_children():
		child.queue_free()
	_status.text = "Buscando o ranking..."
	var period := _period
	var data := await Online.leaderboard(period)
	if period != _period or not is_inside_tree():
		return
	var entries = data.get("entries")
	if typeof(entries) != TYPE_ARRAY:
		_status.text = "Ranking indisponível agora. Tente de novo mais tarde."
		return
	_status.text = "Ninguém no ranking ainda — seja o primeiro!" if entries.is_empty() else ""
	for e in entries:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var you: bool = e.get("is_you", false) == true
		var city: Dictionary = GameData.city(str(e.get("city", "")))
		_list.add_child(_row([
			"%dº" % int(e.get("position", 0)),
			str(e.get("nickname", "?")) + (" (você)" if you else ""),
			str(e.get("rank_title", "")),
			str(int(e.get("score", 0))),
			"%dh" % int(e.get("hours", 0)),
			city.get("name", "—"),
		], Palette.RED_DARK if you else Palette.INK, false))

## Linha da tabela com larguras fixas por coluna.
func _row(values: Array, color: Color, header: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for i in values.size():
		var l := UiTheme.headline(str(values[i]), 12, color) if header else UiTheme.body(str(values[i]), 26, color)
		l.custom_minimum_size.x = COLUMNS[i][1]
		l.clip_text = true
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(l)
	return row

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameManager.go_to_title()
		get_viewport().set_input_as_handled()
