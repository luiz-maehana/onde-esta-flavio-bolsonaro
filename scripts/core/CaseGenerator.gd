class_name CaseGenerator
extends RefCounted
## Sorteia um caso novo (RF01/04/05/07). Recebe o RandomNumberGenerator de
## fora pra ser determinístico nos testes.

const LOCATIONS_PER_CITY := 3
const DECOYS_PER_STOP := 3
const EARTH_RADIUS_KM := 6371.0

static func generate(rng: RandomNumberGenerator, route_len: int) -> CaseState:
	var state := CaseState.new()
	state.rng = rng

	var city_ids: Array = GameData.cities().map(func(c): return c["id"])
	shuffle(rng, city_ids)
	state.route = city_ids.slice(0, route_len)
	state.current_city = state.route[0]

	for i in route_len:
		state.decoys.append(pick_decoys(rng, state.route, DECOYS_PER_STOP))
		state.city_locations[state.route[i]] = pick_locations(rng, GameData.city(state.route[i]))
	for i in route_len - 1:
		var clues: Array = GameData.city(state.route[i + 1])["clues"].duplicate()
		shuffle(rng, clues)
		state.route_clues.append(clues.slice(0, LOCATIONS_PER_CITY))

	var disguises := GameData.disguises()
	state.disguise = disguises[rng.randi_range(0, disguises.size() - 1)]
	_plan_traits(rng, state, route_len - 1)
	state.taunt_plan[rng.randi_range(0, route_len - 2)] = rng.randi_range(0, LOCATIONS_PER_CITY - 1)

	var scandals := GameData.scandals()
	state.scandal = scandals[rng.randi_range(0, scandals.size() - 1)]
	state.reason = _pick(rng, state.scandal["reasons"])
	state.found_spot = _pick(rng, state.scandal["found_spots"])
	state.hideout_slot = rng.randi_range(0, LOCATIONS_PER_CITY - 1)
	return state

## Distribui as características do disfarce pelas paradas não finais, uma
## por parada, em local sorteado. Com 3+ paradas saem 3 ou 4 características;
## os disfarces compartilham no máximo 1 característica entre si, então 2 já
## identificam um único (garantido pelo teste de geração).
static func _plan_traits(rng: RandomNumberGenerator, state: CaseState, stops: int) -> void:
	var traits: Array = GameData.trait_order().duplicate()
	shuffle(rng, traits)
	var stop_order: Array = range(stops)
	shuffle(rng, stop_order)
	for i in mini(traits.size(), stops):
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

## Distância de grande círculo (haversine) entre duas cidades.
static func distance_km(a: Dictionary, b: Dictionary) -> float:
	var lat1 := deg_to_rad(float(a["lat"]))
	var lat2 := deg_to_rad(float(b["lat"]))
	var dlat := lat2 - lat1
	var dlon := deg_to_rad(float(b["lon"]) - float(a["lon"]))
	var h := sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
	return 2.0 * EARTH_RADIUS_KM * asin(sqrt(h))

## Fisher-Yates com o rng do caso (Array.shuffle() usa o rng global e
## quebraria o determinismo dos testes).
static func shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

static func _pick(rng: RandomNumberGenerator, arr: Array) -> Variant:
	return arr[rng.randi_range(0, arr.size() - 1)]
