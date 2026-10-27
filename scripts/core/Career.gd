class_name Career
extends RefCounted
## Carreira do repórter (RF11): nome + casos resolvidos -> cargo.

## Limites de sanidade pra dado vindo de fora (save editável à mão): nome do
## tamanho do campo da tela de título, contadores sem negativo nem estouro.
const MAX_NAME_LENGTH := 18
const MAX_CASES := 99999

var player_name := ""
var cases_solved := 0
var cases_played := 0

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
	return (value as String).strip_edges().left(MAX_NAME_LENGTH)

func to_dict() -> Dictionary:
	return {"player_name": player_name, "cases_solved": cases_solved, "cases_played": cases_played}

## Tolerante a save corrompido ou adulterado: tipo errado, null, negativo,
## NaN ou número gigante viram valor válido em vez de derrubar o jogo.
static func from_dict(data: Dictionary) -> Career:
	var c := Career.new()
	c.player_name = sanitize_name(data.get("player_name", ""))
	c.cases_solved = _count(data.get("cases_solved", 0))
	c.cases_played = maxi(_count(data.get("cases_played", 0)), c.cases_solved)
	return c

static func _count(value: Variant) -> int:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return 0
	var f := float(value)
	if is_nan(f) or is_inf(f):
		return 0
	return int(clampf(f, 0.0, MAX_CASES))
