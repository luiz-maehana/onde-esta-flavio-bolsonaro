class_name GameData
extends RefCounted
## Conteúdo do jogo (cidades, disfarces, falas) lido de data/*.json (RNF03).
## Carrega uma vez só (cache estático) — telas e lógica pedem por aqui em vez
## de cada uma abrir arquivo por conta própria.

const CITIES_PATH := "res://data/cities.json"
const DISGUISES_PATH := "res://data/disguises.json"
const FLAVOR_PATH := "res://data/flavor.json"
const SCANDALS_PATH := "res://data/scandals.json"

static var _cities: Array = []
static var _city_by_id: Dictionary = {}
static var _disguise_data: Dictionary = {}
static var _flavor: Dictionary = {}
static var _scandals: Array = []

static func cities() -> Array:
	_ensure_loaded()
	return _cities

static func city(id: String) -> Dictionary:
	_ensure_loaded()
	return _city_by_id.get(id, {})

static func disguises() -> Array:
	_ensure_loaded()
	return _disguise_data.get("disguises", [])

static func disguise(id: String) -> Dictionary:
	for d in disguises():
		if d["id"] == id:
			return d
	return {}

static func trait_order() -> Array:
	_ensure_loaded()
	return _disguise_data.get("trait_order", [])

static func trait_label(trait_key: String) -> String:
	_ensure_loaded()
	return _disguise_data["trait_labels"].get(trait_key, trait_key)

## Valores possíveis de uma característica, na ordem do JSON.
static func trait_values(trait_key: String) -> Array:
	_ensure_loaded()
	return _disguise_data["traits"].get(trait_key, {}).keys()

static func trait_value_info(trait_key: String, value: String) -> Dictionary:
	_ensure_loaded()
	return _disguise_data["traits"].get(trait_key, {}).get(value, {})

static func flavor() -> Dictionary:
	_ensure_loaded()
	return _flavor

## Escândalos reais que dão tema aos casos (spec 002).
static func scandals() -> Array:
	_ensure_loaded()
	return _scandals

static func location_info(loc_id: String) -> Dictionary:
	return flavor()["locations"].get(loc_id, {"name": loc_id, "role": "Testemunha"})

static func _ensure_loaded() -> void:
	if not _cities.is_empty():
		return
	_cities = _read_json(CITIES_PATH)
	for c in _cities:
		_city_by_id[c["id"]] = c
	_disguise_data = _read_json(DISGUISES_PATH)
	_flavor = _read_json(FLAVOR_PATH)
	_scandals = _read_json(SCANDALS_PATH)

static func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GameData: não abriu %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null:
		push_error("GameData: JSON inválido em %s" % path)
		return {}
	return parsed

## Checagem de consistência do conteúdo — usada pelos testes. Retorna a
## lista de problemas (vazia = tudo certo).
static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var city_keys := ["id", "name", "country", "lon", "lat", "coastal", "landmark", "palette", "description", "clues"]
	for c in cities():
		for k in city_keys:
			if not c.has(k):
				errors.append("cidade %s sem campo %s" % [c.get("id", "?"), k])
		if c.get("clues", []).size() < 3:
			errors.append("cidade %s com menos de 3 pistas" % c.get("id", "?"))
	var seen_combo := {}
	for d in disguises():
		var combo := ""
		for t in trait_order():
			if trait_value_info(t, d.get(t, "")).is_empty():
				errors.append("disfarce %s com %s inválido" % [d["id"], t])
			combo += str(d.get(t, "")) + "|"
		if seen_combo.has(combo):
			errors.append("disfarces %s e %s idênticos" % [d["id"], seen_combo[combo]])
		seen_combo[combo] = d["id"]
	var scandal_keys := ["id", "title", "summary", "status", "outlet", "sources", "reasons", "found_spots", "taunts", "gags", "near", "headlines_win"]
	for s in scandals():
		for k in scandal_keys:
			if not s.has(k) or (s[k] is Array and s[k].is_empty()) or (s[k] is String and s[k].strip_edges() == ""):
				errors.append("escândalo %s sem %s" % [s.get("id", "?"), k])
	return errors

## Linha aleatória de uma lista do flavor.json (sono, provocações...). Usa o
## rng global — só pra texto de enfeite, não pra regra do caso.
static func random_line(key: String) -> String:
	var lines: Array = flavor()[key]
	return lines[randi() % lines.size()]
