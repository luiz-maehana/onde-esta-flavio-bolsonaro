class_name ClueBuilder
extends RefCounted
## Monta a fala da testemunha de um local (RF04/05/06/09). Só texto — custo
## de tempo e desfecho ficam no CaseState.
##
## kind: "clue" (pista de rota, talvez + disfarce), "cold" (cidade errada),
## "near" (cidade final, local vazio), "found" (achou o senador).

static func build(state: CaseState, slot: int) -> Dictionary:
	var loc_id: String = state.locations_here()[slot]
	var role: String = GameData.location_info(loc_id)["role"]
	if not state.is_on_trail():
		return _speech(role, _pick(state, GameData.flavor()["cold_trail"]), "cold")

	if state.is_final_stop():
		if slot == state.hideout_slot:
			return {"role": "Você", "text": found_text(state), "kind": "found"}
		return _speech(role, _pick(state, state.flavor_pool("near")), "near")

	var lines: Array = [state.route_clues[state.stop_index][slot]]
	var plan: Dictionary = state.trait_plan.get(state.stop_index, {})
	if not plan.is_empty() and plan["slot"] == slot:
		lines.append(trait_line(state, plan["trait"]))
	var text := " ".join(lines)
	if state.taunt_plan.get(state.stop_index, -1) == slot:
		text += "\n\n" + _pick(state, state.flavor_pool("taunts"))
	return _speech(role, text, "clue")

static func trait_line(state: CaseState, trait_key: String) -> String:
	var info := GameData.trait_value_info(trait_key, state.disguise[trait_key])
	return _pick(state, info["witness"])

static func found_text(state: CaseState) -> String:
	return "Lá está ele, %s! Flávio Bolsonaro, disfarçado de %s — %s." % [
		state.found_spot, state.disguise["name"], state.disguise["reveal"]]

static func _speech(role: String, text: String, kind: String) -> Dictionary:
	return {"role": role, "text": text, "kind": kind}

static func _pick(state: CaseState, arr: Array) -> String:
	return arr[state.rng.randi_range(0, arr.size() - 1)]
