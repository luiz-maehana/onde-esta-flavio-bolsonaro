extends SceneTree
## Testes da lógica pura (RNF04). Roda com:
##   godot --headless --path . --script res://tests/run_tests.gd
## Sai com código 1 se algo falhar.

var _failures := 0
var _checks := 0

func _initialize() -> void:
	_test_content()
	_test_clock()
	_test_dossier()
	_test_generation()
	_test_playthroughs()
	_test_career()
	_test_portraits()
	_test_security()
	_test_case_save()
	_test_difficulty()
	_test_settings_and_career()
	_test_encoding()
	print("\n%d verificações, %d falhas" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FALHOU: ", msg)

func _test_content() -> void:
	var errors := GameData.validate()
	for e in errors:
		printerr("  conteúdo: ", e)
	_check(errors.is_empty(), "conteúdo JSON válido")
	_check(GameData.cities().size() >= 30, "pelo menos 30 cidades")
	_check(GameData.disguises().size() >= 14, "pelo menos 14 disfarces")
	_check(GameData.scandals().size() >= 5, "pelo menos 5 escândalos")
	var used := {}
	for seed in 200:
		var r := RandomNumberGenerator.new()
		r.seed = seed
		used[CaseGenerator.generate(r, {"route_len": 4}).scandal["id"]] = true
	_check(used.size() == GameData.scandals().size(), "todos os escândalos aparecem em 200 casos")
	for c in GameData.cities():
		_check(SkylineLandmarks.has(c["landmark"]), "marco '%s' de %s tem desenho" % [c["landmark"], c["id"]])
		_check(["h", "v", "disc", "hdisc", "diamond", "canton", "cross", "side", "star", "crescent"].has(c.get("flag", {}).get("type", "")), "bandeira de %s válida" % c["id"])
	# draw_colored_polygon não desenha nada se o polígono não triangula
	# (contorno se cruzando), então isso pega erro de digitação no mapa.
	for i in WorldShapes.LANDS.size():
		var pts := PackedVector2Array()
		for p in WorldShapes.LANDS[i]:
			pts.append(Vector2(p[0], -p[1]))
		_check(not Geometry2D.triangulate_polygon(pts).is_empty(), "continente %d triangula" % i)

func _test_clock() -> void:
	var clock := GameClock.new()
	_check(clock.time_text() == "Segunda 09:00", "relógio começa segunda 09:00")
	_check(not clock.advance(2) and clock.hours == 11, "avanço simples sem dormir")
	clock.hours = 21
	_check(clock.advance(3), "passar das 23h dorme")
	_check(clock.hours == 24 + 7, "acorda 07:00 do dia seguinte")
	clock.hours = 22
	_check(clock.advance(7), "cair de madrugada dorme")
	_check(clock.hours == 24 + 7, "madrugada também acorda 07:00 do mesmo dia")
	clock.hours = GameClock.DEADLINE
	_check(not clock.is_expired(), "no limite ainda não expirou")
	clock.advance(1)
	_check(clock.is_expired(), "depois do limite expira")

func _test_dossier() -> void:
	_check(Dossier.matching({}).size() == GameData.disguises().size(), "sem marcação, todos batem")
	var order := GameData.trait_order()
	for d in GameData.disguises():
		for i in order.size():
			for j in range(i + 1, order.size()):
				var sel := {order[i]: d[order[i]], order[j]: d[order[j]]}
				var m := Dossier.matching(sel)
				_check(m.size() == 1 and m[0]["id"] == d["id"], "2 traços identificam %s (%s,%s)" % [d["id"], order[i], order[j]])

func _test_generation() -> void:
	for seed in 500:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var route_len := 4 + seed % 4
		var s := CaseGenerator.generate(rng, {"route_len": route_len})
		_check(s.route.size() == route_len, "rota com tamanho certo (seed %d)" % seed)
		var uniq := {}
		for c in s.route:
			uniq[c] = true
		_check(uniq.size() == route_len, "rota sem repetir cidade (seed %d)" % seed)
		for i in route_len:
			for d in s.decoys[i]:
				_check(not s.route.has(d), "isca fora da rota (seed %d)" % seed)
			var locs: Array = s.city_locations[s.route[i]]
			_check(locs.size() == 3, "3 locais por cidade")
			if locs.has("porto"):
				_check(GameData.city(s.route[i])["coastal"], "porto só em cidade costeira")
		var revealed := {}
		for stop in s.trait_plan:
			var t: String = s.trait_plan[stop]["trait"]
			revealed[t] = s.disguise[t]
		_check(revealed.size() >= 2, "pelo menos 2 traços revelados (seed %d)" % seed)
		_check(Dossier.matching(revealed).size() == 1, "traços revelados identificam o disfarce (seed %d)" % seed)
		_check(s.travel_options().has(s.route[1]), "opções de viagem incluem a próxima cidade")
		_check(s.travel_options().size() == 4, "4 opções de viagem na trilha")
		_check(not s.scandal.is_empty(), "caso tem escândalo (seed %d)" % seed)
		_check(s.scandal["reasons"].has(s.reason), "motivo da fuga vem do escândalo")
		_check(s.scandal["found_spots"].has(s.found_spot), "esconderijo vem do escândalo")
		for key in ["taunts", "gags", "near"]:
			var pool := s.flavor_pool(key)
			_check(pool.size() == GameData.flavor()[key].size() + s.scandal[key].size(), "pool %s mistura genérico + escândalo" % key)

## Joga casos inteiros: perfeito (vence), sem pauta, pauta errada, desvio.
func _test_playthroughs() -> void:
	for seed in 200:
		var rng := RandomNumberGenerator.new()
		rng.seed = 10000 + seed
		var route_len := 4 + seed % 4
		var mode := seed % 3
		var s := CaseGenerator.generate(rng, {"route_len": route_len})
		if mode == 0:
			s.set_pauta(s.disguise["id"])
		elif mode == 1:
			for d in GameData.disguises():
				if d["id"] != s.disguise["id"]:
					s.set_pauta(d["id"])
					break
		# desvio proposital numa cidade errada e volta
		var wrong: String = s.decoys[0][0]
		s.travel(wrong)
		_check(not s.is_on_trail(), "isca tira da trilha")
		var r := s.investigate(s.locations_here()[0])
		_check(r["kind"] == "cold", "cidade errada dá pista fria")
		_check(s.travel_options().has(s.route[0]), "da cidade errada dá pra voltar")
		s.travel(s.route[0])
		_check(s.is_on_trail(), "voltou pra trilha")
		while not s.is_final_stop():
			var res := s.investigate(s.locations_here()[0])
			_check(res["kind"] == "clue", "cidade certa dá pista")
			s.travel(s.route[s.stop_index + 1])
		var res := s.investigate(s.locations_here()[s.hideout_slot])
		_check(res["kind"] == "found", "achou no esconderijo")
		var expected: int = [CaseState.Outcome.WIN, CaseState.Outcome.WRONG_PAUTA, CaseState.Outcome.NO_PAUTA][mode]
		_check(s.outcome == expected, "desfecho %d esperado %d (seed %d, horas %d)" % [s.outcome, expected, seed, s.clock.hours])

## Pentest: save adulterado nunca derruba o jogo nem gera cargo vazio.
func _test_security() -> void:
	var evil := [
		{"player_name": "Ana", "cases_solved": -5},
		{"player_name": "Ana", "cases_solved": 1e30},
		{"player_name": "Ana", "cases_solved": "abc"},
		{"player_name": "x", "cases_solved": null, "cases_played": null},
		{"player_name": ["array"], "cases_solved": NAN},
		{"player_name": "A".repeat(5000), "cases_solved": INF},
		{},
	]
	for d in evil:
		var c := Career.from_dict(d)
		_check(c != null, "save adulterado vira carreira válida: %s" % str(d).left(40))
		_check(not c.rank().is_empty(), "cargo nunca vazio: %s" % str(d).left(40))
		_check(c.cases_solved >= 0 and c.cases_solved <= Career.MAX_CASES, "contagem dentro dos limites")
		_check(c.player_name.length() <= Career.MAX_NAME_LENGTH, "nome truncado")
		_check(c.cases_played >= c.cases_solved, "jogados >= resolvidos")
	_check(not Career.rank_for(-100).is_empty(), "rank_for negativo cai no primeiro cargo")

func _test_portraits() -> void:
	for d in GameData.disguises():
		_check(d.has("portrait"), "disfarce %s tem figurino" % d["id"])
		_check(_painted(PortraitFactory.paint(PortraitFactory.flavio_spec(d.get("portrait", {})))), "retrato de %s gera imagem" % d["id"])
	for loc_id in GameData.flavor()["locations"]:
		var outfit: Dictionary = GameData.location_info(loc_id).get("outfit", {})
		_check(not outfit.is_empty(), "local %s tem figurino" % loc_id)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(loc_id)
		_check(_painted(PortraitFactory.paint(PortraitFactory.witness_spec(rng, outfit))), "testemunha de %s gera imagem" % loc_id)
	_check(_painted(PortraitFactory.paint(PortraitFactory.flavio_official_spec())), "foto oficial gera imagem")

## Retrato "de verdade": boa parte da imagem pintada e contorno presente.
func _painted(img: Image) -> bool:
	var filled := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				filled += 1
	return filled > img.get_width() * img.get_height() / 3

func _test_career() -> void:
	_check(Career.rank_for(0)["title"].begins_with("Estagi"), "começa estagiário")
	_check(Career.rank_for(8)["route_len"] == 7, "editor-chefe tem rota de 7")
	var c := Career.from_dict({"player_name": "Ana", "cases_solved": 3})
	_check(c.rank()["title"] == "Repórter", "3 casos = Repórter")
	_check(Career.from_dict(c.to_dict()).player_name == "Ana", "ida e volta do save")

## Joga ações aleatórias válidas (investigar, viajar, dossiê, pauta).
func _random_play(s: CaseState, r: RandomNumberGenerator, steps: int) -> void:
	for i in steps:
		if s.is_over():
			return
		var roll := r.randf()
		if roll < 0.5:
			var locs := s.locations_here()
			s.investigate(locs[r.randi_range(0, locs.size() - 1)])
		elif roll < 0.8:
			var opts := s.travel_options()
			s.travel(opts[r.randi_range(0, opts.size() - 1)])
		elif roll < 0.9:
			var t: String = GameData.trait_order()[r.randi_range(0, 3)]
			var vals := GameData.trait_values(t)
			s.set_dossier(t, vals[r.randi_range(0, vals.size() - 1)])
		else:
			var ds := GameData.disguises()
			s.set_pauta(ds[r.randi_range(0, ds.size() - 1)]["id"])

## RF27: save = semente + ações; refazer dá exatamente o mesmo caso, mesmo
## depois de passar pelo JSON; save adulterado é recusado.
func _test_case_save() -> void:
	for seed in 150:
		var r := RandomNumberGenerator.new()
		r.seed = 5000 + seed
		var config := CaseGenerator.config_for_rank(GameData.flavor()["ranks"][seed % 5])
		var g := RandomNumberGenerator.new()
		g.seed = 1 + seed * 7919
		var s := CaseGenerator.generate(g, config)
		_random_play(s, r, 25)
		var json := JSON.stringify(s.to_save())
		var back := CaseState.from_save(JSON.parse_string(json))
		_check(back != null, "save refeito (seed %d)" % seed)
		if back == null:
			continue
		_check(back.current_city == s.current_city and back.stop_index == s.stop_index, "mesma cidade/parada (seed %d)" % seed)
		_check(back.clock.hours == s.clock.hours and back.outcome == s.outcome, "mesmo relógio/desfecho (seed %d)" % seed)
		_check(back.notes.size() == s.notes.size() and back.pauta == s.pauta and back.dossier == s.dossier, "mesmas anotações/pauta/dossiê (seed %d)" % seed)
		_check(back.wrong_cities == s.wrong_cities and back.nights == s.nights, "mesmos contadores (seed %d)" % seed)
	# adulterações
	var g2 := RandomNumberGenerator.new()
	g2.seed = 42
	var base := CaseGenerator.generate(g2, CaseGenerator.config_for_rank(GameData.flavor()["ranks"][0]))
	base.investigate(base.locations_here()[0])
	var good: Dictionary = JSON.parse_string(JSON.stringify(base.to_save()))
	var evil := [
		{"version": 99},
		{"version": 1, "seed": "x", "config": good["config"], "actions": []},
		{"version": 1, "seed": 1, "config": {"route_len": 50, "deadline": 161, "decoys": "near", "trait_clues": 2}, "actions": []},
		{"version": 1, "seed": 1, "config": {"route_len": 5, "deadline": 99999, "decoys": "near", "trait_clues": 2}, "actions": []},
		{"version": 1, "seed": 1, "config": {"route_len": 5, "deadline": 161, "decoys": "hack", "trait_clues": 2}, "actions": []},
		{"version": 1, "seed": good["seed"], "config": good["config"], "actions": [["t", "cidade_que_nao_existe"]]},
		{"version": 1, "seed": good["seed"], "config": good["config"], "actions": [["i", "cofre_do_banco"]]},
		{"version": 1, "seed": good["seed"], "config": good["config"], "actions": [["p", "disfarce_falso"]]},
		{"version": 1, "seed": good["seed"], "config": good["config"], "actions": [["x"], 7]},
		{"version": 1, "seed": good["seed"], "config": good["config"], "actions": "não é lista"},
	]
	for e in evil:
		_check(CaseState.from_save(e) == null, "save adulterado recusado: %s" % str(e).left(60))

	# bug corrigido: voltar mais tarde a uma cidade errada oferece a cidade certa ATUAL
	var g3 := RandomNumberGenerator.new()
	g3.seed = 77
	var s3 := CaseGenerator.generate(g3, {"route_len": 7})
	var wrong: String = s3.decoys[0][0]
	s3.travel(wrong)
	s3.travel(s3.route[0])
	s3.travel(s3.route[1])
	s3.travel(s3.route[2])
	if s3.decoys[2].has(wrong):
		s3.travel(wrong)
		_check(s3.travel_options().has(s3.route[2]), "cidade errada revisitada oferece a parada atual")

## Taxa de vitória jogando "cuidadoso" (os 3 locais de cada cidade) com
## `errors` desvios por cidades erradas.
func _win_rate(config: Dictionary, errors: int, runs: int) -> float:
	var wins := 0
	for seed in runs:
		var g := RandomNumberGenerator.new()
		g.seed = 90000 + seed
		var s := CaseGenerator.generate(g, config)
		s.set_pauta(s.disguise["id"])
		var left := errors
		while not s.is_over():
			if s.is_final_stop():
				for loc in s.locations_here():
					s.investigate(loc)
					if s.is_over():
						break
				break
			for loc in s.locations_here():
				s.investigate(loc)
			if left > 0 and not s.is_over():
				left -= 1
				var opts: Array = s.travel_options().filter(func(c): return c != s.route[s.stop_index + 1])
				s.travel(opts[0])
				s.investigate(s.locations_here()[0])
				s.travel(s.route[s.stop_index])
			s.travel(s.route[s.stop_index + 1])
		if s.outcome == CaseState.Outcome.WIN:
			wins += 1
	return float(wins) / runs

## RF26: curva de dificuldade por cargo.
func _test_difficulty() -> void:
	var ranks: Array = GameData.flavor()["ranks"]
	var intern := CaseGenerator.config_for_rank(ranks[0])
	var editor := CaseGenerator.config_for_rank(ranks[-1])
	var r1 := _win_rate(intern, 3, 200)
	var r2 := _win_rate(editor, 0, 200)
	var r3 := _win_rate(editor, 2, 200)
	print("dificuldade: estagiário+3 erros %.0f%% | editor sem erro %.0f%% | editor+2 erros %.0f%%" % [r1 * 100, r2 * 100, r3 * 100])
	_check(r1 >= 0.85, "estagiário vence com 3 cidades erradas")
	_check(r2 >= 0.85, "editor-chefe vence sem errar")
	_check(r3 <= 0.35, "editor-chefe perde na maioria com 2 erros")
	for r in ranks:
		var c := CaseGenerator.config_for_rank(r)
		_check(c["deadline"] <= GameClock.DEADLINE and c["route_len"] >= 4, "cargo %s com configuração válida" % r["title"])

func _test_settings_and_career() -> void:
	var s := Settings.from_dict({"music_volume": 7, "sfx_volume": NAN, "text_speed": "turbo", "muted": "sim", "seen_tips": ["a", 3, "a", "x".repeat(99)]})
	_check(s.music_volume == 1.0 and s.sfx_volume == 0.9, "volumes limitados/padrão")
	_check(s.text_speed == "normal" and s.muted == false, "valores inválidos ignorados")
	_check(s.seen_tips == ["a"], "dicas vistas sanitizadas")
	var c := Career.from_dict({"disguises_caught": ["turista", 5, "turista"], "achievements": "hack", "clean_wins": 50, "cases_solved": 2})
	_check(c.disguises_caught == ["turista"] and c.achievements.is_empty() and c.clean_wins == 2, "listas e contadores da carreira sanitizados")
	# conquistas num caso vencido sem erro
	var g := RandomNumberGenerator.new()
	g.seed = 3
	var case := CaseGenerator.generate(g, {"route_len": 4})
	case.set_pauta(case.disguise["id"])
	while not case.is_final_stop():
		case.investigate(case.locations_here()[0])
		case.travel(case.route[case.stop_index + 1])
	case.investigate(case.locations_here()[case.hideout_slot])
	var fresh := Career.new()
	var got := fresh.record_case(case)
	_check(got.has("primeiro_furo") and got.has("sem_errar"), "conquistas de primeiro caso limpo")
	_check(fresh.disguises_caught.has(case.disguise["id"]) and fresh.best_hours > 0, "estatísticas registradas")
	for a in Achievements.all():
		_check(a.has("title") and a.has("description"), "conquista %s com textos" % a["id"])

## Texto duplamente codificado (UTF-8 lido como ANSI e regravado) — já
## aconteceu numa edição; padrões que nunca aparecem em português correto.
func _test_encoding() -> void:
	# montados por código pra este arquivo não se acusar
	var bad: Array = [String.chr(0xFEFF), String.chr(0xE2) + String.chr(0x20AC)]
	for second in [0xB3, 0xA9, 0xA1, 0xA7, 0xA3, 0xB5, 0xAA, 0xAD, 0xBA, 0xA2]:
		bad.append(String.chr(0xC3) + String.chr(second))
	for dir in ["res://scripts", "res://data", "res://tests"]:
		for path in _files(dir):
			var text := FileAccess.get_file_as_string(path)
			for b in bad:
				if text.contains(b):
					_check(false, "texto corrompido (%s) em %s" % [b.c_escape(), path])
					break

func _files(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") or f.ends_with(".json"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir + "/" + d))
	return out
