class_name DossierPanel
extends PanelContainer
## Dossiê (RF08): o jogador marca as características que ouviu, a lista de
## disfarces compatíveis encolhe e, com 1 só, dá pra emitir a Pauta. A
## seleção mora no CaseState (sobrevive a fechar/abrir o painel).

signal closed

var _case: CaseState
var _matches_label: Label
var _pauta_label: Label
var _issue: Button
var _first_button: Button

func _init() -> void:
	add_theme_stylebox_override("panel", UiTheme.box(Palette.PAPER))

func open(case: CaseState) -> void:
	_case = case
	_first_button = null
	for child in get_children():
		child.queue_free()
	_build()
	_refresh()
	visible = true
	_first_button.call_deferred("grab_focus")

func _build() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	col.add_child(UiTheme.headline("DOSSIÊ DO DISFARCE", 18, Palette.RED))
	col.add_child(UiTheme.body("Marque o que as testemunhas contaram. Com um único disfarce possível, emita a pauta.", 26, Palette.GREY))

	# características e compatíveis rolam (celular em pé, botões de 48 px
	# reais); pauta e botões de ação ficam sempre à vista embaixo
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	# deitado: rótulo à esquerda e botões na linha; em pé: rótulo em cima e
	# botões quebrando linha
	var portrait := Responsive.is_portrait()
	for trait_key in GameData.trait_order():
		var name_label := UiTheme.body(GameData.trait_label(trait_key).to_upper(), 28)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		var row: Container
		if portrait:
			list.add_child(name_label)
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 8)
			flow.add_theme_constant_override("v_separation", 8)
			row = flow
		else:
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 8)
			name_label.custom_minimum_size.x = 170
			line.add_child(name_label)
			row = line
		list.add_child(row)
		var group := ButtonGroup.new()
		var values: Array = [""] + GameData.trait_values(trait_key)
		for value in values:
			var text: String = "?" if value == "" else GameData.trait_value_info(trait_key, value)["label"]
			var b := UiTheme.button(text, Vector2(0, 44))
			b.add_theme_font_size_override("font_size", UiTheme.scaled(10))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.toggle_mode = true
			b.button_group = group
			b.button_pressed = _case.dossier.get(trait_key, "") == value
			b.toggled.connect(func(on: bool):
				if on:
					_case.set_dossier(trait_key, value)
					GameManager.save_case()
					_refresh())
			row.add_child(b)
			if _first_button == null:
				_first_button = b

	_matches_label = UiTheme.body("", 28)
	list.add_child(_matches_label)
	_pauta_label = UiTheme.headline("", 14)
	col.add_child(_pauta_label)

	var actions := HBoxContainer.new()
	Responsive.fill_row(actions)
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 12)
	col.add_child(actions)
	_issue = UiTheme.button("EMITIR PAUTA", Vector2(240, 48))
	_issue.pressed.connect(_on_issue)
	actions.add_child(_issue)
	var back := UiTheme.button("FECHAR", Vector2(160, 48))
	back.pressed.connect(func():
		visible = false
		closed.emit())
	actions.add_child(back)

func _refresh() -> void:
	var matches := Dossier.matching(_case.dossier)
	var names: Array = matches.map(func(d): return d["name"])
	_matches_label.text = Lang.t("Compatíveis (%d): %s") % [matches.size(), ", ".join(names)]
	_issue.disabled = matches.size() != 1
	if _case.pauta == "":
		_pauta_label.text = "PAUTA: nenhuma emitida"
		_pauta_label.add_theme_color_override("font_color", Palette.GREY)
	else:
		_pauta_label.text = Lang.t("PAUTA APROVADA: %s") % GameData.disguise(_case.pauta)["name"].to_upper()
		_pauta_label.add_theme_color_override("font_color", Palette.GREEN)

func _on_issue() -> void:
	var matches := Dossier.matching(_case.dossier)
	if matches.size() != 1:
		return
	if not _case.set_pauta(matches[0]["id"]):
		return
	GameManager.save_case()
	AudioManager.play_sfx("pauta")
	_refresh()
