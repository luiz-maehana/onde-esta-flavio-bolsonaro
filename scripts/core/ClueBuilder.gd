class_name ClueBuilder
extends RefCounted
## Monta a fala da testemunha de um local (RF04/05/06/09). Só texto — custo
## de tempo e desfecho ficam no CaseState.
##
## kind: "clue" (pista de rota, talvez + disfarce), "cold" (cidade errada),
## "near" (cidade final, local vazio), "found" (achou o senador).
##
## Idiomas (spec 008): `build` sorteia e devolve a receita da fala (índices
## nas listas, nenhum texto); `render` monta o texto no idioma atual. Os
## sorteios são os mesmos de quando a fala guardava texto.

## Receita: {loc, kind, trait, parts}. Cada parte é uma lista:
## ["clue", cidade, i] / ["trait", característica, valor, i] / ["taunt", i] /
## ["cold", i] / ["near", i] / ["found"].
static func build(state: CaseState, slot: int) -> Dictionary:
	var loc_id: String = state.locations_here()[slot]
	if not state.is_on_trail():
		return _speech(loc_id, "cold", [["cold", _pick(state, GameData.flavor()["cold_trail"])]])

	if state.is_final_stop():
		if slot == state.hideout_slot:
			return _speech(loc_id, "found", [["found"]])
		return _speech(loc_id, "near", [["near", _pick(state, state.flavor_pool("near"))]])

	var parts: Array = [["clue", state.route[state.stop_index + 1], state.route_clues[state.stop_index][slot]]]
	var plan: Dictionary = state.trait_plan.get(state.stop_index, {})
	var revealed := ""
	if not plan.is_empty() and plan["slot"] == slot:
		var value: String = state.disguise[plan["trait"]]
		parts.append(["trait", plan["trait"], value, _pick(state, GameData.trait_value_info(plan["trait"], value)["witness"])])
		revealed = plan["trait"]
	if state.taunt_plan.get(state.stop_index, -1) == slot:
		parts.append(["taunt", _pick(state, state.flavor_pool("taunts"))])
	var speech := _speech(loc_id, "clue", parts)
	speech["trait"] = revealed
	return speech

## Fala pronta pra mostrar, no idioma atual: {role, text, kind, trait}.
static func render(state: CaseState, speech: Dictionary) -> Dictionary:
	var role: String = Lang.t("Você") if speech["kind"] == "found" else GameData.location_info(speech["loc"])["role"]
	var text := ""
	for part in speech["parts"]:
		match part[0]:
			"clue":
				text = GameData.city(part[1])["clues"][part[2]]
			"trait":
				text += " " + GameData.trait_value_info(part[1], part[2])["witness"][part[3]]
			"taunt":
				text += "\n\n" + state.flavor_pool("taunts")[part[1]]
			"cold":
				text = GameData.flavor()["cold_trail"][part[1]]
			"near":
				text = state.flavor_pool("near")[part[1]]
			"found":
				text = found_text(state)
	return {"role": role, "text": text, "kind": speech["kind"], "trait": speech.get("trait", "")}

static func found_text(state: CaseState) -> String:
	return Lang.t("Lá está ele, %s! Flávio Bolsonaro, disfarçado de %s — %s.") % [
		state.found_spot, state.disguise["name"], state.disguise["reveal"]]

static func _speech(loc_id: String, kind: String, parts: Array) -> Dictionary:
	return {"loc": loc_id, "kind": kind, "parts": parts}

## Índice sorteado numa lista (mesmo consumo do rng de antes).
static func _pick(state: CaseState, arr: Array) -> int:
	return state.rng.randi_range(0, arr.size() - 1)
