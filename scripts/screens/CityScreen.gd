extends Control
## Hub da cidade (US4/US5/US7/US8): cabeçalho com relógio, paisagem da
## cidade, coluna de ações e um painel inferior que alterna entre descrição,
## locais e fala de testemunha. Dossiê/Anotações ocupam a área da esquerda.
## Regras ficam no CaseState; aqui só se encadeia UI e som.

var _case: CaseState
var _header: NewsHeader
var _skyline: SkylineView
var _info_panel: PanelContainer
var _info_label: Label
var _investigate: InvestigatePanel
var _witness: WitnessBox
var _dossier: DossierPanel
var _notes: NotesPanel
var _scene_area: VBoxContainer
var _actions: Array = []
## Falas ainda na fila depois da atual (imprevisto, sono...).
var _speech_queue: Array = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_case = GameManager.case
	_build()
	_refresh()
	_show_info(GameManager.arrival_messages)
	GameManager.arrival_messages = []
	UiTheme.focus_first(_actions)

func _build() -> void:
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
	_header = NewsHeader.new()
	page.add_child(_header)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	page.add_child(body)

	var left := Control.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)

	_scene_area = VBoxContainer.new()
	_scene_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scene_area.add_theme_constant_override("separation", 12)
	left.add_child(_scene_area)

	var sky_frame := PanelContainer.new()
	var sky_box := UiTheme.box(Palette.INK)
	sky_box.set_content_margin_all(0)
	sky_frame.add_theme_stylebox_override("panel", sky_box)
	sky_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skyline = SkylineView.new()
	sky_frame.add_child(_skyline)
	_scene_area.add_child(sky_frame)

	var bottom := Control.new()
	bottom.custom_minimum_size.y = 250
	_scene_area.add_child(bottom)
	_info_panel = UiTheme.panel()
	_info_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_info_label = UiTheme.body("", 30)
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info_panel.add_child(_info_label)
	bottom.add_child(_info_panel)
	_investigate = InvestigatePanel.new()
	_investigate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_investigate.location_chosen.connect(_on_location_chosen)
	_investigate.cancelled.connect(_back_to_actions)
	bottom.add_child(_investigate)
	_witness = WitnessBox.new()
	_witness.set_anchors_preset(Control.PRESET_FULL_RECT)
	_witness.finished.connect(_on_speech_finished)
	bottom.add_child(_witness)

	_dossier = DossierPanel.new()
	_dossier.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dossier.closed.connect(_back_to_actions)
	left.add_child(_dossier)
	_notes = NotesPanel.new()
	_notes.set_anchors_preset(Control.PRESET_FULL_RECT)
	_notes.closed.connect(_back_to_actions)
	left.add_child(_notes)

	var actions := VBoxContainer.new()
	actions.custom_minimum_size.x = 300
	actions.add_theme_constant_override("separation", 14)
	body.add_child(actions)
	var defs := [
		["INVESTIGAR", _open_investigate],
		["VIAJAR", GameManager.open_travel],
		["DOSSIÊ", _open_dossier],
		["ANOTAÇÕES", _open_notes],
	]
	for d in defs:
		var b := UiTheme.button(d[0], Vector2(0, 76))
		b.pressed.connect(d[1])
		actions.add_child(b)
		_actions.append(b)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var portrait_frame := PanelContainer.new()
	portrait_frame.add_theme_stylebox_override("panel", UiTheme.box(Palette.PAPER_DARK))
	var face := PixelPortrait.make_rect(PixelPortrait.flavio(), 96)
	face.tooltip_text = "Procurado para entrevista"
	portrait_frame.add_child(face)
	actions.add_child(portrait_frame)
	var quit := UiTheme.button("ABANDONAR CASO", Vector2(0, 44))
	quit.add_theme_font_size_override("font_size", UiTheme.scaled(10))
	quit.pressed.connect(GameManager.go_to_title)
	actions.add_child(quit)
	_actions.append(quit)

	_investigate.visible = false
	_witness.visible = false
	_dossier.visible = false
	_notes.visible = false

func _refresh() -> void:
	var city := _case.current_city_data()
	_header.show_place(city["name"].to_upper(), city["country"])
	_header.show_clock(_case.clock)
	_skyline.city = city
	_skyline.hour = _case.clock.hour_of_day()
	var tense := (_case.is_on_trail() and _case.is_final_stop()) or _case.clock.hours_left() < 24
	AudioManager.play_music("tension" if tense else "city")

func _show_info(messages: Array) -> void:
	var city := _case.current_city_data()
	var lines := messages.duplicate()
	lines.append(city["description"])
	_info_label.text = "\n\n".join(lines)
	_info_panel.visible = true

func _set_actions_enabled(enabled: bool) -> void:
	for b in _actions:
		b.disabled = not enabled

func _back_to_actions() -> void:
	_investigate.visible = false
	_scene_area.visible = true
	_set_actions_enabled(true)
	_show_info([])
	UiTheme.focus_first(_actions)

func _open_investigate() -> void:
	_info_panel.visible = false
	_investigate.show_for(_case)

func _open_dossier() -> void:
	_scene_area.visible = false
	_notes.visible = false
	_dossier.open(_case)

func _open_notes() -> void:
	_scene_area.visible = false
	_dossier.visible = false
	_notes.open(_case)

func _on_location_chosen(loc_id: String) -> void:
	_investigate.visible = false
	_set_actions_enabled(false)
	var result := _case.investigate(loc_id)
	_refresh()

	var portrait: Texture2D = PixelPortrait.witness("%s:%s" % [_case.current_city, loc_id], loc_id)
	match result["kind"]:
		"clue":
			AudioManager.play_sfx("clue")
		"near":
			AudioManager.play_sfx("alert")
		"found":
			portrait = PixelPortrait.flavio_disguised(_case.disguise["id"])
			AudioManager.play_sfx("pauta")

	_speech_queue.clear()
	if not result["gag"].is_empty():
		_speech_queue.append(["IMPREVISTO (+%dh)" % result["gag"]["hours"], result["gag"]["text"], PixelPortrait.witness("gag", "taxi")])
	if result["slept"]:
		_speech_queue.append(["Diário do repórter", GameData.random_line("sleep"), PixelPortrait.witness("reporter", "shopping")])
	var gag_hours: int = result["gag"].get("hours", 0)
	var role := "%s · %dh" % [result["role"], result["hours"] - gag_hours]
	_witness.show_speech(role, result["text"], portrait)

func _on_speech_finished() -> void:
	if not _speech_queue.is_empty():
		var next: Array = _speech_queue.pop_front()
		if next[0] == "Diário do repórter":
			AudioManager.play_sfx("sleep")
		_witness.show_speech(next[0], next[1], next[2])
		return
	if _case.is_over():
		GameManager.finish_case()
		return
	_set_actions_enabled(true)
	_open_investigate()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _dossier.visible or _notes.visible:
			_dossier.visible = false
			_notes.visible = false
			_back_to_actions()
		elif _investigate.visible:
			_back_to_actions()
		get_viewport().set_input_as_handled()
