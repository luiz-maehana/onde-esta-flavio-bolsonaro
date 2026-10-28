class_name GameData
extends RefCounted
## Conteúdo do jogo (cidades, disfarces, falas) lido de data/*.json (RNF03).
## Carrega uma vez só (cache estático) — telas e lógica pedem por aqui em vez
## de cada uma abrir arquivo por conta própria.
##
## Idiomas (spec 008): o português de data/*.json é a fonte (ids, estrutura,
## números); data/i18n/<idioma>/<arquivo>.json traz só os textos, nos mesmos
## ids e com listas do mesmo tamanho, e é aplicado por cima.

const CITIES_PATH := "res://data/cities.json"
const DISGUISES_PATH := "res://data/disguises.json"
const FLAVOR_PATH := "res://data/flavor.json"
const SCANDALS_PATH := "res://data/scandals.json"
const TARGETS_PATH := "res://data/targets.json"
## Cenário de cada cidade (spec 011): só ids, sem texto — não tem tradução.
const SCENERY_PATH := "res://data/scenery.json"
## Alvo padrão: o Flávio (os outros são os "parceiros", spec 009).
const DEFAULT_TARGET := "flavio"
const I18N_DIR := "res://data/i18n/"

static var _cities: Array = []
static var _city_by_id: Dictionary = {}
static var _disguise_data: Dictionary = {}
static var _flavor: Dictionary = {}
static var _scandals: Array = []
static var _targets: Array = []
static var _scenery_by_id: Dictionary = {}

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

## Escândalo pelo id: os do Flávio (scandals.json) ou o de um parceiro.
static func scandal(id: String) -> Dictionary:
	for s in scandals():
		if s["id"] == id:
			return s
	for t in targets():
		if t.has("scandal") and t["scandal"]["id"] == id:
			return t["scandal"]
	return {}

## Alvos possíveis de um caso: o Flávio e os parceiros (spec 009).
static func targets() -> Array:
	_ensure_loaded()
	return _targets

static func target(id: String) -> Dictionary:
	for t in targets():
		if t["id"] == id:
			return t
	return {}

## Parceiros: os alvos com escândalo próprio (todos menos o Flávio).
static func partners() -> Array:
	return targets().filter(func(t): return t.has("scandal"))

## Terreno, fundo, vegetação e estilo dos prédios da cidade (spec 011).
static func scenery(city_id: String) -> Dictionary:
	if _scenery_by_id.is_empty():
		for s in _read_json(SCENERY_PATH):
			_scenery_by_id[s["id"]] = s
	return _scenery_by_id.get(city_id, {})

## Escândalos reais que dão tema aos casos (spec 002).
static func scandals() -> Array:
	_ensure_loaded()
	return _scandals

static func location_info(loc_id: String) -> Dictionary:
	return flavor()["locations"].get(loc_id, {"name": loc_id, "role": "Testemunha"})

static func _ensure_loaded() -> void:
	if not _cities.is_empty():
		return
	_cities = localized(CITIES_PATH)
	for c in _cities:
		_city_by_id[c["id"]] = c
	_disguise_data = localized(DISGUISES_PATH)
	_flavor = localized(FLAVOR_PATH)
	_scandals = localized(SCANDALS_PATH)
	_targets = localized(TARGETS_PATH)

## Esquece o cache (troca de idioma): a próxima consulta relê no idioma atual.
static func reload() -> void:
	_cities = []
	_city_by_id = {}

## Arquivo de dados no idioma atual: português + tradução por cima.
static func localized(path: String) -> Variant:
	var base: Variant = _read_json(path)
	if Lang.current == "pt":
		return base
	var over_path := I18N_DIR + Lang.current + "/" + path.get_file()
	if not FileAccess.file_exists(over_path):
		return base
	return overlay(base, _read_json(over_path))

## Aplica os textos de `over` em `base`: dicionário por chave, lista de
## objetos por "id", lista de textos por posição (só se tiver o mesmo
## tamanho — os sorteios dependem do tamanho). Só troca texto por texto:
## número, id e chave que não existe no português ficam como estão.
static func overlay(base: Variant, over: Variant) -> Variant:
	if base is Dictionary and over is Dictionary:
		for k in over:
			if base.has(k):
				base[k] = overlay(base[k], over[k])
		return base
	if base is Array and over is Array:
		if not base.is_empty() and base[0] is Dictionary and base[0].has("id"):
			var by_id := {}
			for item in over:
				if item is Dictionary and item.has("id"):
					by_id[item["id"]] = item
			for i in base.size():
				if by_id.has(base[i].get("id")):
					base[i] = overlay(base[i], by_id[base[i]["id"]])
			return base
		if base.size() == over.size():
			for i in base.size():
				base[i] = overlay(base[i], over[i])
		return base
	if base is String and over is String and over != "":
		return over
	return base

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
	var all_scandals: Array = scandals() + partners().map(func(t): return t["scandal"])
	for s in all_scandals:
		for k in scandal_keys:
			if not s.has(k) or (s[k] is Array and s[k].is_empty()) or (s[k] is String and s[k].strip_edges() == ""):
				errors.append("escândalo %s sem %s" % [s.get("id", "?"), k])
	# alvos (spec 009): o Flávio sem escândalo próprio, parceiros com
	for t in targets():
		for k in ["id", "name", "title", "role", "intro", "signature", "face"]:
			if not t.has(k) or (t[k] is String and t[k].strip_edges() == ""):
				errors.append("alvo %s sem %s" % [t.get("id", "?"), k])
	if target(DEFAULT_TARGET).is_empty() or target(DEFAULT_TARGET).has("scandal"):
		errors.append("alvo padrão (flavio) ausente ou com escândalo próprio")
	return errors

## Linha aleatória de uma lista do flavor.json (sono, provocações...). Usa o
## rng global — só pra texto de enfeite, não pra regra do caso.
static func random_line(key: String) -> String:
	var lines: Array = flavor()[key]
	return lines[randi() % lines.size()]
