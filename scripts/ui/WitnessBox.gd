class_name WitnessBox
extends PanelContainer
## Fala de testemunha: retrato + cargo + texto datilografado letra a letra
## (com som de máquina de escrever). Mesma ideia do DialogueBox do PPKMN:
## uma fala por vez, quem chama decide o que vem depois via `finished`.
## Enter/clique na primeira vez completa o texto; na segunda, fecha.

signal finished

var _portrait: TextureRect
var _role: Label
var _text: Label
var _scroll: ScrollContainer
var _continue: Button
var _shown := 0.0
var _typing := false
var _type_tick := 0

func _init() -> void:
	add_theme_stylebox_override("panel", UiTheme.box(Palette.PAPER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	add_child(row)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.box(Palette.PAPER_DARK, Vector2.ZERO))
	_portrait = PixelPortrait.make_rect(null, 144)
	frame.add_child(_portrait)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(frame)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	row.add_child(col)
	_role = UiTheme.headline("", 16, Palette.RED)
	col.add_child(_role)
	# fala longa rola dentro da caixa em vez de empurrar o botão pra fora
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_text = UiTheme.body("", 32)
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_text)
	_continue = UiTheme.button("CONTINUAR >", Vector2(260, 48))
	_continue.size_flags_horizontal = Control.SIZE_SHRINK_END
	_continue.pressed.connect(_on_continue)
	col.add_child(_continue)

func show_speech(role: String, text: String, portrait: Texture2D) -> void:
	_role.text = role.to_upper()
	_text.text = text
	_portrait.texture = portrait
	_shown = 0.0
	_text.visible_characters = 0
	_scroll.scroll_vertical = 0
	_typing = true
	visible = true
	_continue.grab_focus()
	if GameManager.settings.chars_per_second() <= 0.0:
		_finish_typing()

func _process(delta: float) -> void:
	if not _typing:
		return
	_shown += delta * GameManager.settings.chars_per_second()
	_text.visible_characters = int(_shown)
	_type_tick += 1
	if _type_tick % 4 == 0:
		AudioManager.play_sfx("type", -14.0)
	if _text.visible_characters >= _text.text.length():
		_finish_typing()

func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1

func _on_continue() -> void:
	if _typing:
		_finish_typing()
		return
	visible = false
	finished.emit()
