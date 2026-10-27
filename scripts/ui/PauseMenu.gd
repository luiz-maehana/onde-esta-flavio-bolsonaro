class_name PauseMenu
extends Overlay
## Pausa do caso (RF24): continuar, opções, salvar e sair, abandonar.

signal resumed

var _menu: PanelContainer
var _options: OptionsPanel
var _buttons: Array = []

func _init() -> void:
	super()
	_menu = UiTheme.panel()
	_menu.custom_minimum_size = Vector2(460, 0)
	center.add_child(_menu)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_menu.add_child(col)
	var title := UiTheme.headline("PAUSA", 22, Palette.RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var resume := UiTheme.button("CONTINUAR", Vector2(0, 60))
	resume.pressed.connect(close)
	var options := UiTheme.button("OPÇÕES", Vector2(0, 60))
	options.pressed.connect(_open_options)
	var save_quit := UiTheme.button("SALVAR E SAIR", Vector2(0, 60))
	save_quit.pressed.connect(func(): GameManager.go_to_title(false))
	var abandon := UiTheme.button("ABANDONAR CASO", Vector2(0, 60))
	UiTheme.make_confirm(abandon, "CONFIRMAR ABANDONO?", func(): GameManager.go_to_title(true))
	_buttons = [resume, options, save_quit, abandon]
	for b in _buttons:
		col.add_child(b)
	col.add_child(UiTheme.body("O caso é salvo automaticamente a cada ação.", 24, Palette.GREY))
	var badge := OnlineBadge.new()
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(badge)

	_options = OptionsPanel.new()
	_options.visible = false
	_options.closed.connect(func():
		_menu.visible = true
		UiTheme.focus_first(_buttons))
	center.add_child(_options)

func open() -> void:
	visible = true
	_menu.visible = true
	_options.visible = false
	UiTheme.focus_first(_buttons)

func close() -> void:
	visible = false
	resumed.emit()

func _open_options() -> void:
	_menu.visible = false
	_options.open()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if _options.visible:
			_options.visible = false
			_menu.visible = true
			UiTheme.focus_first(_buttons)
		else:
			close()
		get_viewport().set_input_as_handled()
