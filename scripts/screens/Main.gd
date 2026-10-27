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
}
const FADE_SECONDS := 0.18

var _current: Node
var _fade: ColorRect
var _switching := false

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
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()
