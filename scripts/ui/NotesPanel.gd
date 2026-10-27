class_name NotesPanel
extends PanelContainer
## Caderno do repórter: tudo que as testemunhas disseram, da mais recente
## pra mais antiga (pra reler pista sem gastar hora revisitando).

signal closed

var _list: VBoxContainer
var _close: Button

func _init() -> void:
	add_theme_stylebox_override("panel", UiTheme.box(Palette.PAPER))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	col.add_child(UiTheme.headline("CADERNO DE ANOTAÇÕES", 18, Palette.RED))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)
	_close = UiTheme.button("FECHAR", Vector2(160, 48))
	_close.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close.pressed.connect(func():
		visible = false
		closed.emit())
	col.add_child(_close)

func open(case: CaseState) -> void:
	for child in _list.get_children():
		child.queue_free()
	if case.notes.is_empty():
		_list.add_child(UiTheme.body("Nada anotado ainda. Vá investigar!", 28, Palette.GREY))
	for i in range(case.notes.size() - 1, -1, -1):
		var n: Dictionary = case.notes[i]
		_list.add_child(UiTheme.body("%s · %s: \"%s\"" % [n["city"].to_upper(), n["role"], n["text"]], 26))
	visible = true
	_close.call_deferred("grab_focus")
