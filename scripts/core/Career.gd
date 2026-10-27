class_name Career
extends RefCounted
## Carreira do repórter (RF11): nome + casos resolvidos -> cargo.

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

static func rank_for(solved: int) -> Dictionary:
	var current: Dictionary = {}
	for r in GameData.flavor()["ranks"]:
		if solved >= r["min_cases"]:
			current = r
	return current

func to_dict() -> Dictionary:
	return {"player_name": player_name, "cases_solved": cases_solved, "cases_played": cases_played}

static func from_dict(data: Dictionary) -> Career:
	var c := Career.new()
	c.player_name = str(data.get("player_name", ""))
	c.cases_solved = int(data.get("cases_solved", 0))
	c.cases_played = int(data.get("cases_played", 0))
	return c
