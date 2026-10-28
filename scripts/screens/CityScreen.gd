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
var _pause: PauseMenu
var _tips: TipBox
## Falas ainda na fila depois da atual (imprevisto, sono...).
var _speech_queue: Array = []
## Último resultado de investigação (pra dica certa ao fim da fala).
var _last_result: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_case = GameManager.case
	# remontada ao girar o aparelho durante a última fala: o caso já acabou
	if _case.is_over():
		GameManager.finish_case.call_deferred()
	_build()
	_refresh()
	_show_info(GameManager.arrival_messages)
	GameManager.arrival_messages = []
	UiTheme.focus_first(_actions)
	_tips.try_show("city")

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

	var portrait := Responsive.is_portrait()
	var body := Responsive.flow_box()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	page.add_child(body)

	var left := Control.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	bottom.custom_minimum_size.y = 420 if portrait else 250
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

	# deitado: coluna à direita; em pé: grade de 3 embaixo
	var actions: Container
	if portrait:
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		actions = grid
	else:
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 300
		column.add_theme_constant_override("separation", 14)
		actions = column
	body.add_child(actions)
	var defs := [
		["INVESTIGAR", _open_investigate],
		["VIAJAR", GameManager.open_travel],
		["DOSSIÊ", _open_dossier],
		["ANOTAÇÕES", _open_notes],
	]
	for d in defs:
		var b := UiTheme.button(d[0], Vector2(0, 76))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(d[1])
		actions.add_child(b)
		_actions.append(b)
	if not portrait:
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		actions.add_child(spacer)
		# celular deitado: botões de 48 px reais não deixam altura pro cartaz
		if Responsive.touch_target() < 80.0:
			actions.add_child(_wanted_poster())
	# no toque não tem Esc nem motivo pra letra miúda
	var compact := not portrait and not Responsive.is_touch()
	var menu := UiTheme.button("MENU (ESC)" if compact else "MENU", Vector2(0, 44 if compact else 76))
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if compact:
		menu.add_theme_font_size_override("font_size", UiTheme.scaled(10))
	menu.pressed.connect(_open_pause)
	actions.add_child(menu)
	_actions.append(menu)
	if portrait:
		actions.add_child(_wanted_poster())  # 6ª casa da grade 3x2

	_investigate.visible = false
	_witness.visible = false
	_dossier.visible = false
	_notes.visible = false

	_pause = PauseMenu.new()
	_pause.resumed.connect(func(): UiTheme.focus_first(_actions))
	add_child(_pause)
	_tips = TipBox.new()
	_tips.closed.connect(func(): UiTheme.focus_first(_actions + [_witness]))
	add_child(_tips)

## Cartaz de procurado do Flávio ao lado das ações.
func _wanted_poster() -> PanelContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.box(Palette.PAPER_DARK))
	var face := PixelPortrait.make_rect(PixelPortrait.flavio(), 96)
	face.tooltip_text = "Procurado para entrevista"
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.add_child(face)
	return frame

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
	# dossiê/anotações abertos escondem a cena — o painel de locais fica nela
	_dossier.visible = false
	_notes.visible = false
	_scene_area.visible = true
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
	if result.is_empty():
		_back_to_actions()
		return
	GameManager.save_case()
	_last_result = result
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
	_show_tip_for(_last_result)

## Dica conforme o que a testemunha acabou de dizer (RF32).
func _show_tip_for(result: Dictionary) -> void:
	if result.get("trait", "") != "" and _tips.try_show("trait"):
		return
	match result.get("kind", ""):
		"clue":
			_tips.try_show("clue")
		"cold":
			_tips.try_show("cold")
		"near":
			_tips.try_show("near")

func _open_pause() -> void:
	_pause.open()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _dossier.visible or _notes.visible:
			_dossier.visible = false
			_notes.visible = false
			_back_to_actions()
		elif _investigate.visible:
			_back_to_actions()
		elif not _witness.visible:
			_open_pause()
		get_viewport().set_input_as_handled()
