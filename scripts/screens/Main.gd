extends Control
## Raiz da árvore. Ouve GameManager.screen_requested e troca a tela atual
## com um fade curto pro preto — as telas nunca se referenciam (mesmo
## desenho do Main do PPKMN).

const SCREENS := {
	"title": preload("res://scenes/TitleScreen.tscn"),
	"briefing": preload("res://scenes/BriefingScreen.tscn"),
	"city": preload("res://scenes/CityScreen.tscn"),
	"travel": preload("res://scenes/TravelScreen.tscn"),
	"ending": preload("res://scenes/EndScreen.tscn"),
	"career": preload("res://scenes/CareerScreen.tscn"),
}
const FADE_SECONDS := 0.18

var _current: Node
var _fade: ColorRect
var _switching := false
var _rotate_hint: Control

func _ready() -> void:
	theme = UiTheme.theme()
	_fade = ColorRect.new()
	_fade.color = Palette.INK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.z_index = 100
	add_child(_fade)
	GameManager.screen_requested.connect(_on_screen_requested)
	_swap("title")
	_fade_to(0.0)
	_build_rotate_hint()
	get_tree().root.size_changed.connect(_update_rotate_hint)
	_update_rotate_hint()

func _on_screen_requested(screen_name: String) -> void:
	if _switching:
		return
	_switching = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0)
	_swap(screen_name)
	await _fade_to(0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_switching = false

func _swap(screen_name: String) -> void:
	if _current:
		_current.queue_free()
	_current = SCREENS[screen_name].instantiate()
	add_child(_current)
	move_child(_fade, -1)

func _fade_to(alpha: float) -> Signal:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, FADE_SECONDS)
	return tween.finished

## Alt+Enter / F11 alterna tela cheia.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			GameManager.settings.fullscreen = not GameManager.settings.fullscreen
			GameManager.save_settings()
			get_viewport().set_input_as_handled()

## Celular em pé (RF34): o jogo é 16:9, então pede pra girar o aparelho.
func _build_rotate_hint() -> void:
	_rotate_hint = ColorRect.new()
	(_rotate_hint as ColorRect).color = Palette.INK
	_rotate_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rotate_hint.mouse_filter = Control.MOUSE_FILTER_STOP
	_rotate_hint.z_index = 200
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rotate_hint.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 30)
	center.add_child(col)
	var text := UiTheme.headline("GIRE O APARELHO", 36, Palette.PAPER)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(text)
	var sub := UiTheme.body("O jogo funciona com o celular deitado.", 34, Palette.YELLOW)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	add_child(_rotate_hint)

func _update_rotate_hint() -> void:
	var window := DisplayServer.window_get_size()
	_rotate_hint.visible = window.y > window.x
	move_child(_rotate_hint, -1)
