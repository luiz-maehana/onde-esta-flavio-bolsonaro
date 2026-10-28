class_name InvestigatePanel
extends PanelContainer
## Os 3 locais da cidade atual com o custo em horas (RF03). Só emite qual
## local foi escolhido — quem aplica a regra é CityScreen/CaseState.

signal location_chosen(loc_id: String)
signal cancelled

var _row: BoxContainer
var _buttons: Array = []

func _init() -> void:
	add_theme_stylebox_override("panel", UiTheme.box(Palette.PAPER))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	# VOLTAR na linha do título: com botões de 48 px reais (celular deitado)
	# uma linha só pra ele não cabe na área da fala
	var top := HBoxContainer.new()
	col.add_child(top)
	var title := UiTheme.headline("ONDE INVESTIGAR?", 16, Palette.RED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var back := UiTheme.button("VOLTAR", Vector2(160, 44))
	back.pressed.connect(func(): cancelled.emit())
	top.add_child(back)
	_row = Responsive.flow_box()
	_row.add_theme_constant_override("separation", 16)
	_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_row)

func show_for(case: CaseState) -> void:
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	for loc_id in case.locations_here():
		var info := GameData.location_info(loc_id)
		var label := "%s\n\n%dh" % [info["name"].to_upper(), case.investigate_cost(loc_id)]
		if case.was_visited(loc_id):
			label += Lang.t(" (revisitar)")
		var b := UiTheme.button(label, Vector2(0, 90 if Responsive.is_portrait() or Responsive.is_touch() else 110))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): location_chosen.emit(loc_id))
		_row.add_child(b)
		_buttons.append(b)
	visible = true
	UiTheme.focus_first(_buttons)
