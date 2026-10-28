class_name CaseState
extends RefCounted
## Estado mutável de um caso em andamento + as regras de ação (investigar,
## viajar, emitir pauta, marcar dossiê). Montado por CaseGenerator; as telas
## só chamam os métodos públicos e leem o resultado — nenhuma regra mora na UI.
##
## Save (RF27): toda ação válida entra em `actions`; o save guarda só
## semente + configuração + ações, e from_save() refaz o caso. Pra isso o rng
## compartilhado só é consumido por ações (investigar); o que a UI calcula
## sob demanda (locais/destinos de cidade fora da rota) usa rng derivado da
## semente, independente da ordem em que a tela pede.

enum Outcome { NONE, WIN, NO_PAUTA, WRONG_PAUTA, TIMEOUT }

## Custo de investigar o 1º, 2º e 3º local novo da mesma cidade (RF03).
const INVESTIGATE_COSTS := [2, 3, 4]
const REVISIT_COST := 1
## Chance de imprevisto em % (sorteio inteiro: o servidor do ranking refaz
## o caso em TypeScript e o randf() do Godot é difícil de replicar bit a bit).
const GAG_PERCENT := 15
const MIN_TRAVEL_HOURS := 2
const MAX_TRAVEL_HOURS := 7
const KM_PER_HOUR := 1600.0
const SAVE_VERSION := 2
## Um caso inteiro não chega perto disso; acima é save adulterado.
const MAX_ACTIONS := 1000

var rng := RandomNumberGenerator.new()
var clock := GameClock.new()
var case_seed := 0
var config: Dictionary = {}

## --- Definido pelo gerador ------------------------------------------------
var route: Array = []
## decoys[i] = 3 cidades-isca oferecidas ao viajar a partir de route[i].
var decoys: Array = []
## route_clues[i] = 3 pistas (uma por local) sobre route[i + 1]: índices em
## `clues` daquela cidade.
var route_clues: Array = []
## Parada -> {"trait": chave, "slot": índice do local que revela}.
var trait_plan: Dictionary = {}
## Parada -> índice do local onde ele deixou um bilhete provocativo.
var taunt_plan: Dictionary = {}
var city_locations: Dictionary = {}
## Idiomas (spec 008): o caso guarda ids e índices, nunca texto — o texto é
## buscado no idioma atual na hora de mostrar. Os sorteios só dependem do
## tamanho das listas, então nada muda em save, replay ou servidor.
var disguise_id := ""
var disguise: Dictionary:
	get:
		return GameData.disguise(disguise_id)
	set(value):
		disguise_id = value.get("id", "")
## Quem o repórter persegue (spec 009): o Flávio ou um parceiro.
var target_id := GameData.DEFAULT_TARGET
var target: Dictionary:
	get:
		return GameData.target(target_id)
## Escândalo real que dá tema ao caso (spec 002), de data/scandals.json ou
## o do parceiro (targets.json).
var scandal_id := ""
var scandal: Dictionary:
	get:
		return GameData.scandal(scandal_id)
	set(value):
		scandal_id = value.get("id", "")
## Motivo da fuga e onde ele é achado: índices nas listas do escândalo.
var reason_index := 0
var reason: String:
	get:
		return scandal["reasons"][reason_index]
var found_spot_index := 0
var found_spot: String:
	get:
		return scandal["found_spots"][found_spot_index]
var hideout_slot := 0

## --- Progresso ------------------------------------------------------------
var stop_index := 0
var current_city := ""
var pauta := ""
## Marcações do Dossiê: característica -> valor ("" = não sei).
var dossier: Dictionary = {}
var outcome := Outcome.NONE
var visited: Dictionary = {}
## Anotações: {"city": id, "speech": receita do ClueBuilder} — o texto sai no
## idioma atual (ClueBuilder.render).
var notes: Array = []
## Ações válidas na ordem: ["i", local] / ["t", cidade] / ["p", disfarce] /
## ["d", característica, valor].
var actions: Array = []
## Pra estatísticas e conquistas (RF28/RF29).
var wrong_cities := 0
var nights := 0
## Partida no servidor do ranking (semente sorteada lá); "" = caso local.
var run_id := ""
var _witness_cache: Dictionary = {}
var _travel_cache: Dictionary = {}

func start_city() -> Dictionary:
	return GameData.city(route[0])

func current_city_data() -> Dictionary:
	return GameData.city(current_city)

func is_on_trail() -> bool:
	return current_city == route[stop_index]

func is_final_stop() -> bool:
	return stop_index == route.size() - 1

func is_over() -> bool:
	return outcome != Outcome.NONE

## Horas gastas desde o começo do caso.
func hours_used() -> int:
	return clock.hours - GameClock.START_HOUR

## Rng próprio de um assunto (ex.: "loc:paris"), derivado da semente: o
## resultado não depende de quando a tela pediu.
func _sub_rng(topic: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d:%s" % [case_seed, topic])
	return r

func locations_here() -> Array:
	if not city_locations.has(current_city):
		city_locations[current_city] = CaseGenerator.pick_locations(_sub_rng("loc:" + current_city), current_city_data())
	return city_locations[current_city]

func was_visited(loc_id: String) -> bool:
	return visited.get(current_city, []).has(loc_id)

func investigate_cost(loc_id: String) -> int:
	if was_visited(loc_id):
		return REVISIT_COST
	var count: int = visited.get(current_city, []).size()
	return INVESTIGATE_COSTS[mini(count, INVESTIGATE_COSTS.size() - 1)]

func can_investigate(loc_id: String) -> bool:
	return not is_over() and locations_here().has(loc_id)

## Visita um local da cidade atual. Retorna {role, text, kind, hours, slept,
## gag, trait} — `kind` é "clue", "cold", "near" ou "found" (ver
## ClueBuilder), texto no idioma atual; {} se a ação for inválida.
func investigate(loc_id: String) -> Dictionary:
	if not can_investigate(loc_id):
		return {}
	actions.append(["i", loc_id])
	var hours := investigate_cost(loc_id)
	var first_visit := not was_visited(loc_id)
	if first_visit:
		if not visited.has(current_city):
			visited[current_city] = []
		visited[current_city].append(loc_id)

	var slot := locations_here().find(loc_id)
	var key := "%s:%s" % [current_city, loc_id]
	if not _witness_cache.has(key):
		_witness_cache[key] = ClueBuilder.build(self, slot)
	var speech: Dictionary = _witness_cache[key]
	var result := ClueBuilder.render(self, speech)

	var gag := {}
	if first_visit and is_on_trail() and not is_final_stop() and rng.randi_range(0, 99) < GAG_PERCENT:
		var gags := flavor_pool("gags")
		gag = gags[rng.randi_range(0, gags.size() - 1)]
		hours += int(gag["hours"])

	result["hours"] = hours
	result["gag"] = gag
	result["slept"] = clock.advance(hours)
	if result["slept"]:
		nights += 1
	if first_visit and result["kind"] != "found":
		notes.append({"city": current_city, "speech": speech})

	if clock.is_expired():
		outcome = Outcome.TIMEOUT
	elif result["kind"] == "found":
		outcome = _capture_outcome()
	return result

func _capture_outcome() -> Outcome:
	if pauta == "":
		return Outcome.NO_PAUTA
	if pauta != disguise["id"]:
		return Outcome.WRONG_PAUTA
	return Outcome.WIN

## Destinos oferecidos a partir da cidade atual (RF07), estáveis enquanto o
## jogador estiver nela. A chave inclui a parada: voltar mais tarde à mesma
## cidade errada tem que oferecer a cidade certa *atual*, não a antiga.
func travel_options() -> Array:
	var key := "%s@%d" % [current_city, stop_index]
	if _travel_cache.has(key):
		return _travel_cache[key]
	var r := _sub_rng("travel:" + key)
	var options: Array = []
	if is_on_trail():
		options = decoys[stop_index].duplicate()
		if not is_final_stop():
			options.append(route[stop_index + 1])
	else:
		options.append(route[stop_index])
		options.append_array(CaseGenerator.pick_decoys(r, route + [current_city], 2))
	CaseGenerator.shuffle(r, options)
	_travel_cache[key] = options
	return options

func travel_hours(to_id: String) -> int:
	var km := CaseGenerator.distance_km(current_city_data(), GameData.city(to_id))
	return clampi(int(ceil(km / KM_PER_HOUR)) + 1, MIN_TRAVEL_HOURS, MAX_TRAVEL_HOURS)

func can_travel(to_id: String) -> bool:
	return not is_over() and travel_options().has(to_id)

## Viaja e retorna {hours, slept}; {} se o destino não foi oferecido.
func travel(to_id: String) -> Dictionary:
	if not can_travel(to_id):
		return {}
	actions.append(["t", to_id])
	var hours := travel_hours(to_id)
	if is_on_trail() and not is_final_stop() and to_id == route[stop_index + 1]:
		stop_index += 1
	current_city = to_id
	if not is_on_trail():
		wrong_cities += 1
	var slept := clock.advance(hours)
	if slept:
		nights += 1
	if clock.is_expired():
		outcome = Outcome.TIMEOUT
	return {"hours": hours, "slept": slept}

## Lista de enfeite (taunts, gags, near) = genéricas do flavor.json + as do
## escândalo do caso. Ponto único de mistura, pra ClueBuilder e investigate()
## não repetirem a regra.
## Troca os marcadores do alvo num texto: {target} nome, {title} cargo sem
## artigo, {role} com artigo, {Role} idem com maiúscula, {signature} a
## assinatura dos bilhetes.
func fill(text: String) -> String:
	var t := target
	return text.format({"target": t["name"], "title": t["title"], "role": t["role"],
		"Role": Lang.upper_first(t["role"]), "signature": t["signature"]})

func flavor_pool(key: String) -> Array:
	var pool: Array = GameData.flavor().get(key, []).duplicate()
	pool.append_array(scandal.get(key, []))
	return pool

func set_pauta(disguise_id: String) -> bool:
	if is_over() or GameData.disguise(disguise_id).is_empty():
		return false
	pauta = disguise_id
	actions.append(["p", disguise_id])
	return true

func set_dossier(trait_key: String, value: String) -> bool:
	if is_over() or not GameData.trait_order().has(trait_key):
		return false
	if value != "" and not GameData.trait_values(trait_key).has(value):
		return false
	dossier[trait_key] = value
	actions.append(["d", trait_key, value])
	return true

## --- Save (RF27) ---------------------------------------------------------------

func to_save() -> Dictionary:
	return {"version": SAVE_VERSION, "seed": case_seed, "config": config, "actions": actions, "run_id": run_id}

## Refaz o caso a partir do save. Devolve null se o save for inválido ou se
## qualquer ação não puder ser refeita (save adulterado/de outra versão).
static func from_save(data: Dictionary) -> CaseState:
	if int(data.get("version", 0)) != SAVE_VERSION:
		return null
	var saved_actions = data.get("actions", [])
	var saved_config = data.get("config", {})
	var saved_seed = data.get("seed", null)
	if typeof(saved_actions) != TYPE_ARRAY or typeof(saved_config) != TYPE_DICTIONARY:
		return null
	if typeof(saved_seed) != TYPE_INT and typeof(saved_seed) != TYPE_FLOAT:
		return null
	if saved_actions.size() > MAX_ACTIONS:
		return null
	var config := _sanitize_config(saved_config)
	if config.is_empty():
		return null
	var r := RandomNumberGenerator.new()
	r.seed = int(saved_seed)
	var state := CaseGenerator.generate(r, config)
	var saved_run = data.get("run_id", "")
	if is_hex_id(saved_run):
		state.run_id = saved_run
	for a in saved_actions:
		if not state._replay(a):
			return null
	return state

func _replay(a: Variant) -> bool:
	if typeof(a) != TYPE_ARRAY or a.is_empty():
		return false
	for part in a:
		if typeof(part) != TYPE_STRING:
			return false
	match a[0]:
		"i":
			return a.size() == 2 and not investigate(a[1]).is_empty()
		"t":
			return a.size() == 2 and not travel(a[1]).is_empty()
		"p":
			return a.size() == 2 and set_pauta(a[1])
		"d":
			return a.size() == 3 and set_dossier(a[1], a[2])
	return false

## Só aceita configuração dentro dos limites que o jogo mesmo gera.
static func _sanitize_config(c: Dictionary) -> Dictionary:
	var route_len = c.get("route_len")
	var deadline = c.get("deadline")
	var traits = c.get("trait_clues")
	for v in [route_len, deadline, traits]:
		if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
			return {}
	if int(route_len) < 3 or int(route_len) > 8:
		return {}
	if int(deadline) < 48 or int(deadline) > GameClock.DEADLINE:
		return {}
	if not c.get("decoys") in ["random", "near"]:
		return {}
	# sem target_chance (save ou partida de antes da spec 009) = só o Flávio
	var chance = c.get("target_chance", 0)
	chance = clampi(int(chance), 0, 100) if typeof(chance) == TYPE_INT or typeof(chance) == TYPE_FLOAT else 0
	return {"route_len": int(route_len), "deadline": int(deadline), "decoys": c["decoys"], "trait_clues": clampi(int(traits), 2, 4), "target_chance": chance}

## Id do servidor do ranking / do aparelho: 32 dígitos hexadecimais.
static func is_hex_id(v: Variant) -> bool:
	if typeof(v) != TYPE_STRING or v.length() != 32:
		return false
	for ch in v:
		if not "0123456789abcdef".contains(ch):
			return false
	return true
