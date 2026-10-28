class_name Career
extends RefCounted
## Carreira do repórter (RF11): nome + casos resolvidos -> cargo, mais
## estatísticas e conquistas (RF28/RF29).

## Limites de sanidade pra dado vindo de fora (save editável à mão): nome do
## tamanho do campo da tela de título, contadores sem negativo nem estouro,
## listas pequenas de ids conhecidos.
const MAX_NAME_LENGTH := 18
const MAX_CASES := 99999
const MAX_LIST := 200
const MAX_ID_LENGTH := 40

var player_name := ""
var cases_solved := 0
var cases_played := 0
## Menor número de horas num caso vencido (0 = nenhum ainda).
var best_hours := 0
var clean_wins := 0
var disguises_caught: Array = []
var scandals_covered: Array = []
var cities_visited: Array = []
var achievements: Array = []

func rank() -> Dictionary:
	return rank_for(cases_solved)

## Retorna o próximo cargo, ou {} se já está no topo.
func next_rank() -> Dictionary:
	for r in GameData.flavor()["ranks"]:
		if r["min_cases"] > cases_solved:
			return r
	return {}

## Nunca devolve vazio: abaixo do primeiro cargo (contagem inválida) cai no
## primeiro, pra tela nenhuma quebrar lendo ["title"].
static func rank_for(solved: int) -> Dictionary:
	var ranks: Array = GameData.flavor()["ranks"]
	var current: Dictionary = ranks[0]
	for r in ranks:
		if solved >= r["min_cases"]:
			current = r
	return current

static func sanitize_name(value: Variant) -> String:
	if typeof(value) != TYPE_STRING:
		return ""
	# sem caractere de controle nem de direção do texto (save adulterado podia
	# quebrar linha na manchete ou virar o nome de trás pra frente)
	var clean := ""
	for ch in (value as String):
		var code := ch.unicode_at(0)
		var invisible := code < 32 or code == 127 or (code >= 0x200B and code <= 0x200F) \
			or (code >= 0x202A and code <= 0x202E) or (code >= 0x2066 and code <= 0x2069) or code == 0xFEFF
		clean += " " if invisible else ch
	while clean.contains("  "):
		clean = clean.replace("  ", " ")
	return clean.strip_edges().left(MAX_NAME_LENGTH).strip_edges()

## Registra um caso encerrado e devolve as conquistas desbloqueadas agora.
func record_case(case: CaseState) -> Array:
	cases_played = mini(cases_played + 1, MAX_CASES)
	for city_id in case.visited.keys() + [case.current_city]:
		_add_unique(cities_visited, city_id)
	if case.outcome == CaseState.Outcome.WIN:
		cases_solved = mini(cases_solved + 1, MAX_CASES)
		_add_unique(disguises_caught, case.disguise["id"])
		_add_unique(scandals_covered, case.scandal["id"])
		if case.wrong_cities == 0:
			clean_wins = mini(clean_wins + 1, MAX_CASES)
		var used := case.hours_used()
		if best_hours == 0 or used < best_hours:
			best_hours = used
	var unlocked := Achievements.newly_unlocked(self, case)
	achievements.append_array(unlocked)
	return unlocked

static func _add_unique(list: Array, id: String) -> void:
	if id != "" and not list.has(id) and list.size() < MAX_LIST:
		list.append(id)

func to_dict() -> Dictionary:
	return {
		"player_name": player_name, "cases_solved": cases_solved, "cases_played": cases_played,
		"best_hours": best_hours, "clean_wins": clean_wins,
		"disguises_caught": disguises_caught, "scandals_covered": scandals_covered,
		"cities_visited": cities_visited, "achievements": achievements,
	}

## Tolerante a save corrompido ou adulterado: tipo errado, null, negativo,
## NaN ou número gigante viram valor válido em vez de derrubar o jogo.
static func from_dict(data: Dictionary) -> Career:
	var c := Career.new()
	c.player_name = sanitize_name(data.get("player_name", ""))
	c.cases_solved = _count(data.get("cases_solved", 0))
	c.cases_played = maxi(_count(data.get("cases_played", 0)), c.cases_solved)
	c.best_hours = _count(data.get("best_hours", 0))
	c.clean_wins = mini(_count(data.get("clean_wins", 0)), c.cases_solved)
	c.disguises_caught = _ids(data.get("disguises_caught", []))
	c.scandals_covered = _ids(data.get("scandals_covered", []))
	c.cities_visited = _ids(data.get("cities_visited", []))
	c.achievements = _ids(data.get("achievements", []))
	return c

static func _count(value: Variant) -> int:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return 0
	var f := float(value)
	if is_nan(f) or is_inf(f):
		return 0
	return int(clampf(f, 0.0, MAX_CASES))

## Lista de ids: só strings curtas, sem repetição, tamanho limitado.
static func _ids(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for v in value:
		if typeof(v) == TYPE_STRING and v.length() <= MAX_ID_LENGTH:
			_add_unique(out, v)
	return out

## Posição do cargo atual na lista de cargos (o servidor do ranking usa).
func rank_index() -> int:
	return maxi(0, GameData.flavor()["ranks"].find(rank()))
