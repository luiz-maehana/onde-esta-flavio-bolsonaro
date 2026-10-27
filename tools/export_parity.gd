extends SceneTree
## Exporta vetores de paridade pro servidor do ranking (spec 006): sequências
## do RandomNumberGenerator, hash() de strings e casos inteiros (semente +
## ações -> estado final). O porte em TypeScript (server/) tem que bater
## com todos. Regerar sempre que mudar o núcleo ou os dados.
## Roda com: godot --headless --path . --script res://tools/export_parity.gd

const OUT := "res://server/test/vectors.json"
const CASES := 400

func _initialize() -> void:
	var out := {"rng": [], "hash": [], "cases": []}
	for seed in [1, 2, 42, 12345, 2147483647, 987654321]:
		var r := RandomNumberGenerator.new()
		r.seed = seed
		var raw: Array = []
		for i in 8:
			raw.append(r.randi())
		var ranges: Array = []
		for bounds in [[0, 1], [0, 2], [0, 99], [1, 2147483647], [5, 5], [0, 21], [-3, 7]]:
			ranges.append([bounds[0], bounds[1], r.randi_range(bounds[0], bounds[1])])
		out["rng"].append({"seed": seed, "randi": raw, "ranges": ranges})
	for s in ["", "a", "loc:rio", "travel:paris@3", "123:loc:são paulo", "Flávio Ação ç", "%d:%s" % [77, "travel:cairo@0"]]:
		out["hash"].append({"s": s, "h": hash(s)})

	var ranks: Array = GameData.flavor()["ranks"]
	for i in CASES:
		var g := RandomNumberGenerator.new()
		g.seed = 1 + i * 104729
		var config := CaseGenerator.config_for_rank(ranks[i % ranks.size()])
		var s := CaseGenerator.generate(g, config)
		var play := RandomNumberGenerator.new()
		play.seed = 900000 + i
		var smart := i % 2 == 0
		_play(s, play, smart)
		out["cases"].append({
			"seed": s.case_seed, "config": s.config, "actions": s.actions,
			"final": {
				"route": s.route, "disguise": s.disguise["id"], "scandal": s.scandal["id"],
				"hideout_slot": s.hideout_slot, "current_city": s.current_city,
				"stop_index": s.stop_index, "hours": s.clock.hours, "outcome": s.outcome,
				"wrong_cities": s.wrong_cities, "nights": s.nights, "pauta": s.pauta,
				"notes": s.notes.size(), "locations": s.locations_here(),
				"options": s.travel_options() if not s.is_over() else [],
			},
		})
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT), FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	print("parity: %d rng, %d hash, %d casos" % [out["rng"].size(), out["hash"].size(), out["cases"].size()])
	quit()

## Metade "esperta" (segue a trilha, emite a pauta certa, às vezes erra
## cidade) pra cobrir vitória; metade aleatória pra cobrir o resto.
func _play(s: CaseState, r: RandomNumberGenerator, smart: bool) -> void:
	for step in 120:
		if s.is_over():
			return
		if smart:
			if step == 0:
				s.set_dossier("hat", s.disguise["hat"])
				s.set_pauta(s.disguise["id"])
			var locs := s.locations_here()
			if s.is_final_stop() and s.is_on_trail():
				s.investigate(locs[r.randi_range(0, locs.size() - 1)])
				continue
			s.investigate(locs[r.randi_range(0, locs.size() - 1)])
			if s.is_over():
				return
			if not s.is_on_trail():
				s.travel(s.route[s.stop_index])
			elif r.randi_range(0, 9) == 0:
				var wrong: Array = s.travel_options().filter(func(c): return c != s.route[s.stop_index + 1])
				s.travel(wrong[0])
			else:
				s.travel(s.route[s.stop_index + 1])
		else:
			var roll := r.randi_range(0, 9)
			if roll < 5:
				var locs := s.locations_here()
				s.investigate(locs[r.randi_range(0, locs.size() - 1)])
			elif roll < 8:
				var opts := s.travel_options()
				s.travel(opts[r.randi_range(0, opts.size() - 1)])
			elif roll < 9:
				var t: String = GameData.trait_order()[r.randi_range(0, 3)]
				var vals := GameData.trait_values(t)
				s.set_dossier(t, vals[r.randi_range(0, vals.size() - 1)])
			else:
				var ds := GameData.disguises()
				s.set_pauta(ds[r.randi_range(0, ds.size() - 1)]["id"])
