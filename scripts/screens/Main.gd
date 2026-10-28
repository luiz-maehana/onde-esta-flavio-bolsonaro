extends Control
## Raiz da árvore. Ouve GameManager.screen_requested e troca a tela atual
## com um fade curto pro preto — as telas nunca se referenciam (mesmo
## desenho do Main do PPKMN).
##
## Orientação (RF36): ao girar o aparelho, troca o tamanho-base (1280x720 /
## 720x1280) e remonta a tela atual no arranjo da nova orientação — o estado
## mora no GameManager, então nada se perde além de uma fala aberta. Trocar o
## idioma (spec 008) remonta do mesmo jeito.

const SCREENS := {
	"title": preload("res://scenes/TitleScreen.tscn"),
	"briefing": preload("res://scenes/BriefingScreen.tscn"),
	"city": preload("res://scenes/CityScreen.tscn"),
	"travel": preload("res://scenes/TravelScreen.tscn"),
	"ending": preload("res://scenes/EndScreen.tscn"),
	"career": preload("res://scenes/CareerScreen.tscn"),
	"leaderboard": preload("res://scenes/LeaderboardScreen.tscn"),
}
const FADE_SECONDS := 0.18

var _current: Node
var _current_name := ""
var _fade: ColorRect
var _switching := false
var _portrait := false

## Teto de quadros no celular pela Web (RF96): a arte é pixel e anima
## devagar, 30 fps bastam e poupam bateria.
const TOUCH_WEB_MAX_FPS := 30

func _ready() -> void:
	if OS.has_feature("web") and Responsive.is_touch():
		Engine.max_fps = TOUCH_WEB_MAX_FPS
	theme = UiTheme.theme()
	_fade = ColorRect.new()
	_fade.color = Palette.INK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.z_index = 100
	add_child(_fade)
	GameManager.screen_requested.connect(_on_screen_requested)
	_portrait = Responsive.is_portrait()
	get_window().content_scale_size = Responsive.base_size()
	get_tree().root.size_changed.connect(_on_window_resized)
	GameManager.language_changed.connect(_remount)
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
	_current_name = screen_name
	_current = SCREENS[screen_name].instantiate()
	add_child(_current)
	move_child(_fade, -1)

func _on_window_resized() -> void:
	var portrait := Responsive.is_portrait()
	if portrait == _portrait:
		return
	_portrait = portrait
	get_window().content_scale_size = Responsive.base_size()
	_remount()

## Remonta a tela atual (girou o aparelho ou trocou o idioma): o estado mora
## no GameManager, então só se perde uma fala aberta.
func _remount() -> void:
	if not _switching and _current_name != "":
		_swap(_current_name)

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
