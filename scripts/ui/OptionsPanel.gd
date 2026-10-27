class_name OptionsPanel
extends PanelContainer
## Opções (RF23): volume de música/efeitos, mudo, tela cheia, velocidade do
## texto e dicas. Cada mudança aplica na hora e salva (GameManager).

signal closed

var _first: Control

func _init() -> void:
	add_theme_stylebox_override("panel", UiTheme.box(Palette.PAPER))
	custom_minimum_size = Vector2(720, 0)

func open() -> void:
	for child in get_children():
		child.queue_free()
	_build()
	visible = true
	_first.call_deferred("grab_focus")

func _build() -> void:
	var s := GameManager.settings
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	col.add_child(UiTheme.headline("OPÇÕES", 20, Palette.RED))

	_first = _slider_row(col, "MÚSICA", s.music_volume, func(v):
		s.music_volume = v
		GameManager.save_settings())
	_slider_row(col, "EFEITOS", s.sfx_volume, func(v):
		s.sfx_volume = v
		GameManager.save_settings()
		AudioManager.play_sfx("clue"))
	_row(col, "SOM", UiTheme.toggle("MUDO", "LIGADO", s.muted, func(on):
		s.muted = on
		GameManager.save_settings()))
	if not OS.has_feature("web"):
		_row(col, "TELA CHEIA", UiTheme.toggle("SIM (F11)", "NÃO (F11)", s.fullscreen, func(on):
			s.fullscreen = on
			GameManager.save_settings()))

	var speeds := HBoxContainer.new()
	speeds.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for speed in Settings.TEXT_SPEEDS:
		var label: String = {"lenta": "LENTO", "normal": "NORMAL", "instantanea": "INSTANTÂNEO"}[speed]
		var b := UiTheme.button(label, Vector2(150, 48))
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = s.text_speed == speed
		b.toggled.connect(func(on):
			if on:
				s.text_speed = speed
				GameManager.save_settings())
		speeds.add_child(b)
	_row(col, "TEXTO", speeds)

	var tips := HBoxContainer.new()
	tips.add_theme_constant_override("separation", 8)
	tips.add_child(UiTheme.toggle("LIGADAS", "DESLIGADAS", s.tips_enabled, func(on):
		s.tips_enabled = on
		GameManager.save_settings()))
	var reset := UiTheme.button("REVER DICAS", Vector2(200, 48))
	reset.pressed.connect(func():
		s.seen_tips.clear()
		s.tips_enabled = true
		GameManager.save_settings()
		reset.text = "OK!")
	tips.add_child(reset)
	_row(col, "DICAS", tips)

	var close := UiTheme.button("FECHAR", Vector2(180, 52))
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(func():
		visible = false
		closed.emit())
	col.add_child(close)

func _row(col: VBoxContainer, label: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := UiTheme.body(label, 30)
	l.custom_minimum_size.x = 170
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	col.add_child(row)

## Linha com slider 0–100% (passo de 5) e o valor ao lado.
func _slider_row(col: VBoxContainer, label: String, value: float, on_change: Callable) -> HSlider:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = round(value * 100)
	slider.custom_minimum_size = Vector2(320, 32)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	var pct := UiTheme.body("%d%%" % int(slider.value), 30)
	pct.custom_minimum_size.x = 70
	slider.value_changed.connect(func(v):
		pct.text = "%d%%" % int(v)
		on_change.call(v / 100.0))
	box.add_child(slider)
	box.add_child(pct)
	_row(col, label, box)
	return slider
