extends Control
## Viagem (US6): mapa-múndi com os destinos oferecidos; focar um botão
## destaca a cidade no mapa, confirmar anima o avião e só então aplica a
## viagem (GameManager.travel_to).

var _case: CaseState
var _map: WorldMapView
var _buttons: Array = []
var _target := ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_case = GameManager.case

	var bg := ColorRect.new()
	bg.color = Palette.INK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	margin.add_child(page)

	var header := NewsHeader.new()
	header.show_place("PARA ONDE?", "Saindo de %s — escolha o próximo voo" % _case.current_city_data()["name"])
	header.show_clock(_case.clock)
	page.add_child(header)

	var frame := PanelContainer.new()
	var frame_box := UiTheme.box(Palette.OCEAN)
	frame_box.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", frame_box)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map = WorldMapView.new()
	_map.origin_id = _case.current_city
	_map.option_ids = _case.travel_options()
	_map.trail_ids = _case.route.slice(0, _case.stop_index + 1)
	_map.flight_finished.connect(_on_landed)
	frame.add_child(_map)
	page.add_child(frame)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	page.add_child(row)
	for id in _case.travel_options():
		var city := GameData.city(id)
		var b := UiTheme.button("%s\n%dh de voo" % [city["name"].to_upper(), _case.travel_hours(id)], Vector2(0, 84))
		b.add_theme_font_size_override("font_size", UiTheme.scaled(12))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_entered.connect(_highlight.bind(id))
		b.mouse_entered.connect(_highlight.bind(id))
		b.pressed.connect(_depart.bind(id))
		row.add_child(b)
		_buttons.append(b)
	var stay := UiTheme.button("FICAR", Vector2(150, 84))
	stay.pressed.connect(GameManager.go_to_city)
	row.add_child(stay)
	_buttons.append(stay)
	UiTheme.focus_first(_buttons)

	var tips := TipBox.new()
	tips.closed.connect(func(): UiTheme.focus_first(_buttons))
	add_child(tips)
	tips.try_show("travel")

func _highlight(id: String) -> void:
	_map.highlighted_id = id

func _depart(id: String) -> void:
	if _target != "":
		return
	_target = id
	_highlight(id)
	for b in _buttons:
		b.disabled = true
	AudioManager.play_sfx("plane")
	_map.fly_to(id)

func _on_landed() -> void:
	GameManager.travel_to(_target)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _target == "":
		GameManager.go_to_city()
		get_viewport().set_input_as_handled()
