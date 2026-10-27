extends Node
## Autoload — dono do estado global (carreira, preferências, caso em
## andamento) e do fluxo entre telas. Telas nunca se conhecem: pedem a troca
## aqui e o Main (ouvindo `screen_requested`) instancia a cena certa — mesmo
## desenho do GameManager/Main do PPKMN.

signal screen_requested(screen_name: String)
signal settings_changed

const TITLE := "title"
const BRIEFING := "briefing"
const CITY := "city"
const TRAVEL := "travel"
const ENDING := "ending"
const CAREER := "career"
## Semente cabe em 31 bits: o save é JSON (número = double, 53 bits de
## precisão), e uma semente de 64 bits voltaria diferente no replay.
const MAX_SEED := 2147483647

var career: Career
var settings: Settings
var case: CaseState
## Mensagens a mostrar quando a CityScreen abrir (chegada, sono...).
var arrival_messages: Array = []
## Conquistas desbloqueadas no último caso encerrado (pra capa final).
var last_unlocked: Array = []

func _ready() -> void:
	career = SaveService.load()
	settings = Settings.load_or_default()
	apply_settings.call_deferred()

func has_player() -> bool:
	return career.player_name.strip_edges() != ""

func set_player_name(player_name: String) -> void:
	career = Career.new()
	career.player_name = Career.sanitize_name(player_name)
	SaveService.save(career)
	SaveService.clear_case()

## --- Preferências (RF23) --------------------------------------------------------

func apply_settings() -> void:
	AudioManager.apply_settings(settings)
	if not OS.has_feature("web"):
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	settings_changed.emit()

func save_settings() -> void:
	settings.save()
	apply_settings()

## Dica do primeiro caso (RF32): true se deve mostrar `tip_id` agora (e já
## marca como vista).
func consume_tip(tip_id: String) -> bool:
	if not settings.tips_enabled or settings.seen_tips.has(tip_id):
		return false
	settings.seen_tips.append(tip_id)
	settings.save()
	return true

## --- Caso -----------------------------------------------------------------------

func start_new_case() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	rng.seed = rng.randi_range(1, MAX_SEED)
	case = CaseGenerator.generate(rng, CaseGenerator.config_for_rank(career.rank()))
	arrival_messages = []
	save_case()
	screen_requested.emit(BRIEFING)

func has_saved_case() -> bool:
	return SaveService.load_case() != null

## Retoma o caso salvo (RF27). Volta pro título se o save não servir mais.
func continue_case() -> void:
	case = SaveService.load_case()
	if case == null:
		SaveService.clear_case()
		screen_requested.emit(TITLE)
		return
	arrival_messages = ["Caso retomado em %s. %s." % [case.current_city_data()["name"], case.clock.time_text()]]
	screen_requested.emit(CITY)

func save_case() -> void:
	if case != null and not case.is_over():
		SaveService.save_case(case)

func go_to_city() -> void:
	screen_requested.emit(CITY)

func open_travel() -> void:
	screen_requested.emit(TRAVEL)

## Aplica a viagem no caso e volta pra cidade (ou pro fim, se o prazo acabou).
func travel_to(city_id: String) -> void:
	var result := case.travel(city_id)
	if result.is_empty():
		screen_requested.emit(CITY)
		return
	save_case()
	var city_name: String = GameData.city(city_id)["name"]
	arrival_messages = ["Voo de %dh. Você desembarca em %s." % [result["hours"], city_name]]
	if result["slept"]:
		arrival_messages.append(GameData.random_line("sleep"))
	if case.is_over():
		finish_case()
	else:
		screen_requested.emit(CITY)

## Fecha o caso: atualiza a carreira (estatísticas e conquistas) e mostra a
## capa de jornal.
func finish_case() -> void:
	last_unlocked = career.record_case(case)
	SaveService.save(career)
	SaveService.clear_case()
	screen_requested.emit(ENDING)

## Sai pro título. `abandon` descarta o caso salvo; sem ele, o caso fica pra
## "Continuar caso".
func go_to_title(abandon: bool = false) -> void:
	if abandon:
		SaveService.clear_case()
	else:
		save_case()
	case = null
	screen_requested.emit(TITLE)

func open_career() -> void:
	screen_requested.emit(CAREER)
