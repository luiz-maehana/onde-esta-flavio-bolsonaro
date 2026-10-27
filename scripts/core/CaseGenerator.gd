class_name CaseGenerator
extends RefCounted
## Sorteia um caso novo (RF01/04/05/07) a partir da configuração do cargo
## (RF25). Recebe o RandomNumberGenerator de fora pra ser determinístico nos
## testes e no replay do save (RF27).

const LOCATIONS_PER_CITY := 3
const DECOYS_PER_STOP := 3
## Iscas "near": sorteadas entre as N cidades mais próximas do destino certo.
const NEAR_POOL := 6
const EARTH_RADIUS_KM := 6371.0

## Configuração usada quando o chamador não informa um campo.
const DEFAULT_CONFIG := {
	"route_len": 5, "deadline": GameClock.DEADLINE, "decoys": "random", "trait_clues": 4,
}

## Configuração de caso a partir de um cargo de flavor.json (campos que
## faltarem caem no padrão).
static func config_for_rank(rank: Dictionary) -> Dictionary:
	var config := DEFAULT_CONFIG.duplicate()
	for k in config:
		if rank.has(k):
			config[k] = rank[k]
	return config

static func generate(rng: RandomNumberGenerator, config_in: Dictionary) -> CaseState:
	var config := DEFAULT_CONFIG.duplicate()
	config.merge(config_in, true)
	var route_len: int = clampi(int(config["route_len"]), 2, 10)

	var state := CaseState.new()
	state.rng = rng
	state.case_seed = rng.seed
	state.config = config
	state.clock.deadline = int(config["deadline"])

	var city_ids: Array = GameData.cities().map(func(c): return c["id"])
	shuffle(rng, city_ids)
	state.route = city_ids.slice(0, route_len)
	state.current_city = state.route[0]

	for i in route_len:
		var next_city: String = state.route[i + 1] if i + 1 < route_len else ""
		if config["decoys"] == "near" and next_city != "":
			state.decoys.append(pick_near_decoys(rng, state.route, next_city, DECOYS_PER_STOP))
		else:
			state.decoys.append(pick_decoys(rng, state.route, DECOYS_PER_STOP))
		state.city_locations[state.route[i]] = pick_locations(rng, GameData.city(state.route[i]))
	for i in route_len - 1:
		var clues: Array = GameData.city(state.route[i + 1])["clues"].duplicate()
		shuffle(rng, clues)
		state.route_clues.append(clues.slice(0, LOCATIONS_PER_CITY))

	var disguises := GameData.disguises()
	state.disguise = disguises[rng.randi_range(0, disguises.size() - 1)]
	_plan_traits(rng, state, route_len - 1, int(config["trait_clues"]))
	state.taunt_plan[rng.randi_range(0, route_len - 2)] = rng.randi_range(0, LOCATIONS_PER_CITY - 1)

	var scandals := GameData.scandals()
	state.scandal = scandals[rng.randi_range(0, scandals.size() - 1)]
	state.reason = _pick(rng, state.scandal["reasons"])
	state.found_spot = _pick(rng, state.scandal["found_spots"])
	state.hideout_slot = rng.randi_range(0, LOCATIONS_PER_CITY - 1)
	return state

## Distribui características do disfarce pelas paradas não finais, uma por
## parada, em local sorteado. `max_traits` vem do cargo: cargos altos revelam
## só 2 (o mínimo — disfarces dividem no máximo 1 característica entre si,
## então 2 identificam um único; garantido pelo teste de geração).
static func _plan_traits(rng: RandomNumberGenerator, state: CaseState, stops: int, max_traits: int) -> void:
	var traits: Array = GameData.trait_order().duplicate()
	shuffle(rng, traits)
	var stop_order: Array = range(stops)
	shuffle(rng, stop_order)
	for i in mini(mini(traits.size(), stops), maxi(2, max_traits)):
		state.trait_plan[stop_order[i]] = {
			"trait": traits[i],
			"slot": rng.randi_range(0, LOCATIONS_PER_CITY - 1),
		}

static func pick_locations(rng: RandomNumberGenerator, city: Dictionary) -> Array:
	var pool: Array = GameData.flavor()["locations"].keys()
	if not city.get("coastal", false):
		pool.erase("porto")
	shuffle(rng, pool)
	return pool.slice(0, LOCATIONS_PER_CITY)

static func pick_decoys(rng: RandomNumberGenerator, exclude: Array, count: int) -> Array:
	var pool: Array = []
	for c in GameData.cities():
		if not exclude.has(c["id"]):
			pool.append(c["id"])
	shuffle(rng, pool)
	return pool.slice(0, count)

## Iscas difíceis: entre as cidades mais próximas do destino certo (mesma
## região, pistas parecidas), fora da rota.
static func pick_near_decoys(rng: RandomNumberGenerator, exclude: Array, target_id: String, count: int) -> Array:
	var target := GameData.city(target_id)
	var pool: Array = []
	for c in GameData.cities():
		if not exclude.has(c["id"]):
			pool.append(c)
	pool.sort_custom(func(a, b): return distance_km(a, target) < distance_km(b, target))
	var near: Array = pool.slice(0, NEAR_POOL).map(func(c): return c["id"])
	shuffle(rng, near)
	return near.slice(0, count)

## Distância de grande círculo (haversine) entre duas cidades.
static func distance_km(a: Dictionary, b: Dictionary) -> float:
	var lat1 := deg_to_rad(float(a["lat"]))
	var lat2 := deg_to_rad(float(b["lat"]))
	var dlat := lat2 - lat1
	var dlon := deg_to_rad(float(b["lon"]) - float(a["lon"]))
	var h := sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
	return 2.0 * EARTH_RADIUS_KM * asin(sqrt(h))

## Fisher-Yates com o rng do caso (Array.shuffle() usa o rng global e
## quebraria o determinismo dos testes e do replay).
static func shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

static func _pick(rng: RandomNumberGenerator, arr: Array) -> Variant:
	return arr[rng.randi_range(0, arr.size() - 1)]
