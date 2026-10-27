extends Node
## Autoload — dono do estado global (carreira + caso em andamento) e do
## fluxo entre telas. Telas nunca se conhecem: pedem a troca aqui e o Main
## (ouvindo `screen_requested`) instancia a cena certa — mesmo desenho do
## GameManager/Main do PPKMN.

signal screen_requested(screen_name: String)

const TITLE := "title"
const BRIEFING := "briefing"
const CITY := "city"
const TRAVEL := "travel"
const ENDING := "ending"

var career: Career
var case: CaseState
## Mensagens a mostrar quando a CityScreen abrir (chegada, sono...).
var arrival_messages: Array = []

func _ready() -> void:
	career = SaveService.load()

func has_player() -> bool:
	return career.player_name.strip_edges() != ""

func set_player_name(player_name: String) -> void:
	career = Career.new()
	career.player_name = Career.sanitize_name(player_name)
	SaveService.save(career)

func start_new_case() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	case = CaseGenerator.generate(rng, career.rank()["route_len"])
	arrival_messages = []
	screen_requested.emit(BRIEFING)

func go_to_city() -> void:
	screen_requested.emit(CITY)

func open_travel() -> void:
	screen_requested.emit(TRAVEL)

## Aplica a viagem no caso e volta pra cidade (ou pro fim, se o prazo acabou).
func travel_to(city_id: String) -> void:
	var result := case.travel(city_id)
	var city_name: String = GameData.city(city_id)["name"]
	arrival_messages = ["Voo de %dh. Você desembarca em %s." % [result["hours"], city_name]]
	if result["slept"]:
		arrival_messages.append(GameData.random_line("sleep"))
	if case.is_over():
		finish_case()
	else:
		screen_requested.emit(CITY)

## Fecha o caso: atualiza a carreira e mostra a capa de jornal.
func finish_case() -> void:
	career.cases_played += 1
	if case.outcome == CaseState.Outcome.WIN:
		career.cases_solved += 1
	SaveService.save(career)
	screen_requested.emit(ENDING)

func go_to_title() -> void:
	case = null
	screen_requested.emit(TITLE)
