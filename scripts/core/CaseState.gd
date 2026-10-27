class_name CaseState
extends RefCounted
## Estado mutável de um caso em andamento + as regras de ação (investigar,
## viajar, emitir pauta). Montado por CaseGenerator; as telas só chamam os
## métodos públicos e leem o resultado — nenhuma regra mora na UI.

enum Outcome { NONE, WIN, NO_PAUTA, WRONG_PAUTA, TIMEOUT }

## Custo de investigar o 1º, 2º e 3º local novo da mesma cidade (RF03).
const INVESTIGATE_COSTS := [2, 3, 4]
const REVISIT_COST := 1
const GAG_CHANCE := 0.15
const MIN_TRAVEL_HOURS := 2
const MAX_TRAVEL_HOURS := 7
const KM_PER_HOUR := 1600.0

var rng := RandomNumberGenerator.new()
var clock := GameClock.new()

## --- Definido pelo gerador ------------------------------------------------
var route: Array = []
## decoys[i] = 3 cidades-isca oferecidas ao viajar a partir de route[i].
var decoys: Array = []
## route_clues[i] = 3 pistas (uma por local) sobre route[i + 1].
var route_clues: Array = []
## Parada -> {"trait": chave, "slot": índice do local que revela}.
var trait_plan: Dictionary = {}
## Parada -> índice do local onde ele deixou um bilhete provocativo.
var taunt_plan: Dictionary = {}
var city_locations: Dictionary = {}
var disguise: Dictionary = {}
## Escândalo real que dá tema ao caso (spec 002), de data/scandals.json.
var scandal: Dictionary = {}
var reason := ""
var hideout_slot := 0
var found_spot := ""

## --- Progresso ------------------------------------------------------------
var stop_index := 0
var current_city := ""
var pauta := ""
## Marcações do Dossiê: característica -> valor ("" = não sei).
var dossier: Dictionary = {}
var outcome := Outcome.NONE
var visited: Dictionary = {}
var notes: Array = []
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

func locations_here() -> Array:
	if not city_locations.has(current_city):
		city_locations[current_city] = CaseGenerator.pick_locations(rng, current_city_data())
	return city_locations[current_city]

func was_visited(loc_id: String) -> bool:
	return visited.get(current_city, []).has(loc_id)

func investigate_cost(loc_id: String) -> int:
	if was_visited(loc_id):
		return REVISIT_COST
	var count: int = visited.get(current_city, []).size()
	return INVESTIGATE_COSTS[mini(count, INVESTIGATE_COSTS.size() - 1)]

## Visita um local da cidade atual. Retorna {role, text, kind, hours, slept,
## gag} — `kind` é "clue", "cold", "near" ou "found" (ver ClueBuilder).
func investigate(loc_id: String) -> Dictionary:
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
	var result: Dictionary = _witness_cache[key].duplicate()

	var gag := {}
	if first_visit and is_on_trail() and not is_final_stop() and rng.randf() < GAG_CHANCE:
		var gags := flavor_pool("gags")
		gag = gags[rng.randi_range(0, gags.size() - 1)]
		hours += int(gag["hours"])

	result["hours"] = hours
	result["gag"] = gag
	result["slept"] = clock.advance(hours)
	if first_visit and result["kind"] != "found":
		notes.append({"city": current_city_data()["name"], "role": result["role"], "text": result["text"]})

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
## jogador estiver nela (abrir o mapa de novo não reembaralha).
func travel_options() -> Array:
	if _travel_cache.has(current_city):
		return _travel_cache[current_city]
	var options: Array = []
	if is_on_trail():
		options = decoys[stop_index].duplicate()
		if not is_final_stop():
			options.append(route[stop_index + 1])
	else:
		options.append(route[stop_index])
		options.append_array(CaseGenerator.pick_decoys(rng, route + [current_city], 2))
	CaseGenerator.shuffle(rng, options)
	_travel_cache[current_city] = options
	return options

func travel_hours(to_id: String) -> int:
	var km := CaseGenerator.distance_km(current_city_data(), GameData.city(to_id))
	return clampi(int(ceil(km / KM_PER_HOUR)) + 1, MIN_TRAVEL_HOURS, MAX_TRAVEL_HOURS)

## Viaja e retorna {hours, slept}.
func travel(to_id: String) -> Dictionary:
	var hours := travel_hours(to_id)
	if is_on_trail() and not is_final_stop() and to_id == route[stop_index + 1]:
		stop_index += 1
	current_city = to_id
	var slept := clock.advance(hours)
	if clock.is_expired():
		outcome = Outcome.TIMEOUT
	return {"hours": hours, "slept": slept}

## Lista de enfeite (taunts, gags, near) = genéricas do flavor.json + as do
## escândalo do caso. Ponto único de mistura, pra ClueBuilder e investigate()
## não repetirem a regra.
func flavor_pool(key: String) -> Array:
	var pool: Array = GameData.flavor().get(key, []).duplicate()
	pool.append_array(scandal.get(key, []))
	return pool

func set_pauta(disguise_id: String) -> void:
	pauta = disguise_id
