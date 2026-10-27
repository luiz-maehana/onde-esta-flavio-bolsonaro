extends Node
## Autoload — cliente da API de ranking e contador online (spec 006-B,
## server/). Tudo opcional e tolerante a falha: sem rede ou com a API fora,
## o jogo segue normal (sem contador; caso local, fora do ranking).
##
## Privacidade: manda só um id aleatório do aparelho (gerado aqui), o
## apelido (nome do repórter) quando o jogador aceita o ranking, e as ações
## do caso. Nenhum dado pessoal.

signal online_changed(count: int)

const BASE_URL := "https://onde-esta-flavio-api.ondeestaflavio.workers.dev"
const HEARTBEAT_SECONDS := 60.0
## Freio do plano grátis do Cloudflare: o servidor diz de quanto em quanto
## tempo mandar o próximo sinal (mais gente online = mais espaçado); se a
## API falhar, as tentativas se espaçam (2, 4, 8... até 15 min).
const MIN_INTERVAL := 60.0
const MAX_INTERVAL := 90000.0
const BACKOFF_START := 120.0
const BACKOFF_MAX := 900.0
const TIMEOUT_SECONDS := 8.0
const DEVICE_PATH := "user://onde_esta_flavio_device.json"

## -1 = indisponível (sem rede, API fora, ou desligado).
var online_count := -1
var device_id := ""
var session_id := ""
## Testes desligam a rede ou trocam as respostas por um Callable
## (method, path, body) -> {"ok", "status", "data"}.
var enabled := true
var mock := Callable()

var _timer: Timer
var _backoff := 0.0

func _ready() -> void:
	# Testes e ferramentas (cenas em res://tests e res://tools) nunca falam
	# com a API de produção — não contam como gente online.
	for arg in OS.get_cmdline_args():
		if arg.begins_with("res://tests/") or arg.begins_with("res://tools/"):
			enabled = false
	device_id = _load_or_create_device()
	session_id = _random_id()
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = HEARTBEAT_SECONDS
	_timer.timeout.connect(heartbeat)
	add_child(_timer)
	if enabled:
		heartbeat.call_deferred()

func is_available() -> bool:
	return enabled or mock.is_valid()

## --- Rotas ------------------------------------------------------------------------

func heartbeat() -> void:
	var res := await _request(HTTPClient.METHOD_POST, "/presence", {"session": session_id})
	var count := -1
	if res["ok"] and typeof(res["data"]) == TYPE_DICTIONARY:
		count = int(res["data"].get("online", -1))
		_backoff = 0.0
		_schedule(clampf(float(res["data"].get("interval", HEARTBEAT_SECONDS)), MIN_INTERVAL, MAX_INTERVAL))
	else:
		_backoff = BACKOFF_START if _backoff == 0.0 else minf(_backoff * 2.0, BACKOFF_MAX)
		_schedule(_backoff)
	if count != online_count:
		online_count = count
		online_changed.emit(count)

## Próximo sinal (timer de disparo único, reagendado a cada resposta).
func _schedule(seconds: float) -> void:
	if _timer and is_inside_tree():
		_timer.start(seconds)

## Partida com semente do servidor. {} se não deu (aí o caso é local).
func start_run(rank_index: int) -> Dictionary:
	var res := await _request(HTTPClient.METHOD_POST, "/runs/start", {"device": device_id, "rank": rank_index})
	if not res["ok"] or typeof(res["data"]) != TYPE_DICTIONARY:
		return {}
	return res["data"]

## O servidor refaz o caso e devolve {outcome, score, published, position}.
func finish_run(run_id: String, actions: Array, nickname: String, publish: bool) -> Dictionary:
	var res := await _request(HTTPClient.METHOD_POST, "/runs/finish", {
		"run_id": run_id, "device": device_id, "actions": actions, "nickname": nickname, "publish": publish,
	})
	return res["data"] if res["ok"] and typeof(res["data"]) == TYPE_DICTIONARY else {}

func publish_run(run_id: String, nickname: String) -> Dictionary:
	var res := await _request(HTTPClient.METHOD_POST, "/runs/publish", {"run_id": run_id, "device": device_id, "nickname": nickname})
	return res["data"] if res["ok"] and typeof(res["data"]) == TYPE_DICTIONARY else {}

## {"period", "entries": [{position, nickname, rank_title, score, hours, city, is_you}]} ou {}.
func leaderboard(period: String) -> Dictionary:
	var res := await _request(HTTPClient.METHOD_GET, "/leaderboard?period=%s&device=%s" % [period, device_id], {})
	return res["data"] if res["ok"] and typeof(res["data"]) == TYPE_DICTIONARY else {}

## --- HTTP -------------------------------------------------------------------------

func _request(method: int, path: String, body: Dictionary) -> Dictionary:
	if mock.is_valid():
		return mock.call(method, path, body)
	if not enabled:
		return {"ok": false, "status": 0, "data": null}
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_SECONDS
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var payload := JSON.stringify(body) if method == HTTPClient.METHOD_POST else ""
	var err := http.request(BASE_URL + path, headers, method, payload)
	if err != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "data": null}
	var r: Array = await http.request_completed
	http.queue_free()
	var status: int = r[1]
	var data = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8()) if r[0] == HTTPRequest.RESULT_SUCCESS else null
	return {"ok": r[0] == HTTPRequest.RESULT_SUCCESS and status >= 200 and status < 300, "status": status, "data": data}

## --- Identificador do aparelho -------------------------------------------------------

static func _random_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

func _load_or_create_device() -> String:
	var file := FileAccess.open(DEVICE_PATH, FileAccess.READ)
	if file and file.get_length() < 1024:
		var data = JSON.parse_string(file.get_as_text())
		if typeof(data) == TYPE_DICTIONARY and CaseState.is_hex_id(data.get("device")):
			return data["device"]
	var id := _random_id()
	if not SaveService.read_only:
		var out := FileAccess.open(DEVICE_PATH, FileAccess.WRITE)
		if out:
			out.store_string(JSON.stringify({"device": id}))
	return id
