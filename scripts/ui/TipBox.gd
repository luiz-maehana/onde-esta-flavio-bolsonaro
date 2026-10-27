class_name TipBox
extends Overlay
## Dica do primeiro caso (RF32). `try_show(id)` só aparece se as dicas
## estiverem ligadas e essa ainda não tiver sido vista.

signal closed

var _text: Label
var _ok: Button

func _init() -> void:
	super()
	color = Color(Palette.INK, 0.45)
	var card := UiTheme.panel(Palette.YELLOW)
	card.custom_minimum_size = Vector2(640, 0)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	col.add_child(UiTheme.headline("DICA DO EDITOR", 16, Palette.RED))
	_text = UiTheme.body("", 30)
	col.add_child(_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var off := UiTheme.button("DESLIGAR DICAS", Vector2(220, 48))
	off.pressed.connect(func():
		GameManager.settings.tips_enabled = false
		GameManager.save_settings()
		_close())
	row.add_child(off)
	_ok = UiTheme.button("ENTENDI", Vector2(160, 48))
	_ok.pressed.connect(_close)
	row.add_child(_ok)

## Mostra a dica `tip_id` (texto em flavor.json "tips"). Retorna se mostrou.
func try_show(tip_id: String) -> bool:
	var tips: Dictionary = GameData.flavor().get("tips", {})
	if not tips.has(tip_id) or not GameManager.consume_tip(tip_id):
		return false
	_text.text = tips[tip_id]
	visible = true
	_ok.call_deferred("grab_focus")
	return true

func _close() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel")):
		_close()
		get_viewport().set_input_as_handled()
