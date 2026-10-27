extends Node
## Autoload — dono do estado global (carreira, preferências, caso em
## andamento) e do fluxo entre telas. Telas nunca se conhecem: pedem a troca
## aqui e o Main (ouvindo `screen_requested`) instancia a cena certa — mesmo
## desenho do GameManager/Main do PPKMN.

signal screen_requested(screen_name: String)
signal settings_changed
## Caso novo sendo preparado (pode esperar o servidor do ranking).
signal case_starting
## Resposta do servidor do ranking pro caso que acabou de terminar.
signal online_result_ready(result: Dictionary)

const TITLE := "title"
const BRIEFING := "briefing"
const CITY := "city"
const TRAVEL := "travel"
const ENDING := "ending"
const CAREER := "career"
const LEADERBOARD := "leaderboard"
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
## Ranking do último caso: {} (caso local) ou {"status": "pending" | "done" |
## "error", "run_id", "outcome", "score", "published", "position"}.
var last_online_result: Dictionary = {}
var _starting := false

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

## Caso novo. Com o ranking ligado (ou ainda "ask"), a semente vem do
## servidor (antitrapaça: ele refaz o caso no fim); se a API não responder,
## o caso é local e simplesmente não entra no ranking.
func start_new_case() -> void:
	if _starting:
		return
	_starting = true
	case_starting.emit()
	var config := CaseGenerator.config_for_rank(career.rank())
	var new_seed := 0
	var run_id := ""
	if settings.ranking != "no" and Online.is_available():
		var run := await Online.start_run(career.rank_index())
		var server_seed = run.get("seed")
		var server_config = run.get("config")
		if CaseState.is_hex_id(run.get("run_id")) and typeof(server_config) == TYPE_DICTIONARY and (typeof(server_seed) == TYPE_INT or typeof(server_seed) == TYPE_FLOAT):
			var checked := CaseState._sanitize_config(server_config)
			if not checked.is_empty() and int(server_seed) >= 1 and int(server_seed) <= MAX_SEED:
				new_seed = int(server_seed)
				config = checked
				run_id = run["run_id"]
	var rng := RandomNumberGenerator.new()
	if new_seed == 0:
		rng.randomize()
		new_seed = rng.randi_range(1, MAX_SEED)
	rng.seed = new_seed
	case = CaseGenerator.generate(rng, config)
	case.run_id = run_id
	arrival_messages = []
	save_case()
	_starting = false
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
	last_online_result = {}
	if case.run_id != "" and settings.ranking != "no":
		last_online_result = {"status": "pending", "run_id": case.run_id}
		_send_finish(case)
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

## --- Ranking online (spec 006-B) ---------------------------------------------------

## Manda as ações pro servidor refazer o caso. Publica direto se o jogador
## já aceitou o ranking; com "ask", só registra (publica se aceitar depois).
func _send_finish(finished: CaseState) -> void:
	var res := await Online.finish_run(finished.run_id, finished.actions, career.player_name, settings.ranking == "yes")
	if res.is_empty():
		last_online_result = {"status": "error", "run_id": finished.run_id}
	else:
		last_online_result = res.duplicate()
		last_online_result["run_id"] = finished.run_id
		# servidor e jogo calculam o desfecho com a mesma lógica: divergência
		# aqui seria bug de paridade, não do jogador
		last_online_result["status"] = "done" if int(res.get("outcome", -1)) == finished.outcome else "mismatch"
	online_result_ready.emit(last_online_result)

## Resposta à pergunta do primeiro caso vencido.
func answer_ranking(accept: bool) -> void:
	settings.ranking = "yes" if accept else "no"
	save_settings()
	var r := last_online_result
	if not accept or r.get("status") != "done" or r.get("published", false) or int(r.get("outcome", 0)) != CaseState.Outcome.WIN:
		online_result_ready.emit(last_online_result)
		return
	last_online_result["status"] = "pending"
	online_result_ready.emit(last_online_result)
	var res := await Online.publish_run(r["run_id"], career.player_name)
	last_online_result["status"] = "done" if not res.is_empty() else "error"
	last_online_result["published"] = res.get("published", false)
	last_online_result["position"] = res.get("position")
	online_result_ready.emit(last_online_result)

func open_leaderboard() -> void:
	screen_requested.emit(LEADERBOARD)
