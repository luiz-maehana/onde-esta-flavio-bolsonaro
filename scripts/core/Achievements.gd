class_name Achievements
extends RefCounted
## Conquistas (RF29): textos em data/achievements.json, regra de cada id aqui.

const PATH := "res://data/achievements.json"
const FAST_HOURS := 72
const SLEEPY_NIGHTS := 5
const WORLD_CITIES := 20
const PERSISTENT_CASES := 10

static var _all: Array = []

static func all() -> Array:
	if _all.is_empty():
		var parsed = GameData.localized(PATH)
		_all = parsed if typeof(parsed) == TYPE_ARRAY else []
	return _all

## Troca de idioma: relê os textos.
static func reload() -> void:
	_all = []

static func info(id: String) -> Dictionary:
	for a in all():
		if a["id"] == id:
			return a
	return {}

## Conquistas que passaram a valer com este caso (e ainda não eram da carreira).
static func newly_unlocked(career: Career, case: CaseState) -> Array:
	var out: Array = []
	for a in all():
		if not career.achievements.has(a["id"]) and is_met(a["id"], career, case):
			out.append(a["id"])
	return out

static func is_met(id: String, career: Career, case: CaseState) -> bool:
	var won := case.outcome == CaseState.Outcome.WIN
	match id:
		"primeiro_furo":
			return career.cases_solved >= 1
		"sem_errar":
			return won and case.wrong_cities == 0
		"relampago":
			return won and case.hours_used() <= FAST_HOURS
		"colecionador":
			return career.disguises_caught.size() >= GameData.disguises().size()
		"todos_escandalos":
			return career.scandals_covered.size() >= GameData.scandals().size()
		"globetrotter":
			return career.cities_visited.size() >= WORLD_CITIES
		"editor_chefe":
			var ranks: Array = GameData.flavor()["ranks"]
			return career.rank()["title"] == ranks[-1]["title"]
		"persistente":
			return career.cases_played >= PERSISTENT_CASES
		"insone":
			return case.nights >= SLEEPY_NIGHTS
		"vexame":
			return case.outcome == CaseState.Outcome.WRONG_PAUTA
		"sem_pauta":
			return case.outcome == CaseState.Outcome.NO_PAUTA
	return false
