extends SceneTree
## Testes da lógica pura (RNF04). Roda com:
##   godot --headless --path . --script res://tests/run_tests.gd
## Sai com código 1 se algo falhar.

var _failures := 0
var _checks := 0

func _initialize() -> void:
	# textos em português, seja qual for o idioma da máquina (o CI é inglês)
	Lang.apply("pt")
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
	_test_platform_config()
	_test_invariants()
	_test_always_winnable()
	_test_content_deep()
	_test_hostile_names()
	_test_fonts_cover_languages()
	_test_i18n_catalog()
	_test_i18n_data()
	_test_language_detect()
	_test_lower_first()
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
		{"version": 2, "seed": "x", "config": good["config"], "actions": []},
		{"version": 2, "seed": 1, "config": {"route_len": 50, "deadline": 161, "decoys": "near", "trait_clues": 2}, "actions": []},
		{"version": 2, "seed": 1, "config": {"route_len": 5, "deadline": 99999, "decoys": "near", "trait_clues": 2}, "actions": []},
		{"version": 2, "seed": 1, "config": {"route_len": 5, "deadline": 161, "decoys": "hack", "trait_clues": 2}, "actions": []},
		{"version": 2, "seed": good["seed"], "config": good["config"], "actions": [["t", "cidade_que_nao_existe"]]},
		{"version": 2, "seed": good["seed"], "config": good["config"], "actions": [["i", "cofre_do_banco"]]},
		{"version": 2, "seed": good["seed"], "config": good["config"], "actions": [["p", "disfarce_falso"]]},
		{"version": 2, "seed": good["seed"], "config": good["config"], "actions": [["x"], 7]},
		{"version": 2, "seed": good["seed"], "config": good["config"], "actions": "não é lista"},
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

## Regressões de celular (versão Web): teclado virtual ligado no export e
## barramentos de áudio declarados no layout (criados depois da partida, o
## Web Audio não toca nada neles — o jogo ficava mudo no celular).
func _test_platform_config() -> void:
	var presets := ConfigFile.new()
	_check(presets.load("res://export_presets.cfg") == OK, "export_presets.cfg lido")
	var web := ""
	for section in presets.get_sections():
		if presets.get_value(section, "platform", "") == "Web":
			web = section
	_check(web != "", "preset Web existe")
	_check(presets.get_value(web + ".options", "html/experimental_virtual_keyboard", false) == true, "teclado virtual ligado na versão Web")
	var head: String = presets.get_value(web + ".options", "html/head_include", "")
	# sem viewport-fit=cover o Safari mantém o jogo fora do notch (RF37)
	_check(not head.contains("viewport-fit=cover"), "página Web respeita a área segura (sem viewport-fit=cover)")
	_check(head.contains("status-wifi") and head.contains("Wi-Fi"), "carregamento avisa do tamanho e do Wi-Fi (RF39)")
	var layout_path: String = ProjectSettings.get_setting("audio/buses/default_bus_layout", "")
	_check(layout_path == "res://default_bus_layout.tres", "layout de áudio do projeto definido")
	var layout := load(layout_path)
	_check(layout is AudioBusLayout, "layout de áudio carrega")
	var text := FileAccess.get_file_as_string(layout_path)
	for bus in ["Music", "SFX"]:
		_check(text.contains('&"%s"' % bus), "barramento %s declarado no layout" % bus)
	# versão nas Opções: definida no projeto e gravada pelo CI antes de exportar
	_check(ProjectSettings.has_setting("application/config/version"), "projeto tem versão (application/config/version)")
	var build := FileAccess.get_file_as_string("res://.github/workflows/build.yml")
	_check(build.contains("git describe") and build.contains("config/version=") and build.contains("fetch-depth: 0"), "CI grava a versão do git antes de exportar")
	_check(AudioServer.get_bus_index("Music") != -1 and AudioServer.get_bus_index("SFX") != -1, "barramentos existem desde a partida")

## --- Spec 007 (T64): invariantes sob jogo aleatório -------------------------------

const FUZZ_CASES := 2000
const FUZZ_STEPS := 60
## Casos (dos FUZZ_CASES) em que o save é refeito a cada passo (I6) — refazer
## custa O(ações), então só numa parte.
const FUZZ_REPLAY_CASES := 300

## Joga ações aleatórias, válidas e inválidas, em todos os cargos e confere
## I1–I7 depois de cada uma. Na primeira falha de um caso, imprime semente e
## passo e pula pro próximo caso.
func _test_invariants() -> void:
	var ranks: Array = GameData.flavor()["ranks"]
	var failed_cases := 0
	for n in FUZZ_CASES:
		var g := RandomNumberGenerator.new()
		g.seed = 700000 + n
		var s := CaseGenerator.generate(g, CaseGenerator.config_for_rank(ranks[n % ranks.size()]))
		var r := RandomNumberGenerator.new()
		r.seed = n
		var err := _fuzz_case(s, r, n < FUZZ_REPLAY_CASES)
		if err != "":
			failed_cases += 1
			_check(false, "invariante (semente %d): %s" % [700000 + n, err])
	_check(failed_cases == 0, "fuzz: %d casos sem quebrar invariante" % FUZZ_CASES)

func _fuzz_case(s: CaseState, r: RandomNumberGenerator, replay_each: bool) -> String:
	var start_stop := s.stop_index
	for step in FUZZ_STEPS:
		var before := _snapshot(s)
		var was_over := s.is_over()
		var act := _fuzz_action(s, r)
		var ok: bool = act["ok"]
		var after := _snapshot(s)
		var where := "passo %d, %s" % [step, act["desc"]]
		# I1 relógio
		if after["hours"] < before["hours"]:
			return "%s: relógio voltou" % where
		if s.clock.is_expired() and s.outcome != CaseState.Outcome.TIMEOUT:
			return "%s: prazo estourado sem TIMEOUT" % where
		# I2 fim é fim / I4 ação inválida sem efeito
		if (was_over or not act["valid"]) and (ok or after != before):
			return "%s: ação %s mudou o estado" % [where, "depois do fim" if was_over else "inválida"]
		if act["valid"] and not was_over and not ok:
			return "%s: ação válida recusada" % where
		# I5 contadores
		if s.stop_index < start_stop or s.stop_index < before["stop"] or s.stop_index > s.route.size() - 1:
			return "%s: parada fora de ordem (%d)" % [where, s.stop_index]
		var expected_wrong: int = before["wrong"] + (1 if act["kind"] == "t" and ok and not s.is_on_trail() else 0)
		if after["wrong"] != expected_wrong:
			return "%s: cidades erradas %d, esperado %d" % [where, after["wrong"], expected_wrong]
		var seen := {}
		for note in s.notes:
			var spoken := ClueBuilder.render(s, note["speech"])
			var k := "%s|%s|%s" % [note["city"], spoken["role"], spoken["text"]]
			if seen.has(k):
				return "%s: anotação duplicada" % where
			seen[k] = true
		# I3 viagem
		if not s.is_over():
			var opts := s.travel_options()
			var unique := {}
			for o in opts:
				unique[o] = true
			if unique.size() != opts.size() or opts.has(s.current_city):
				return "%s: opções de viagem repetidas ou com a cidade atual: %s" % [where, opts]
			if s.is_on_trail() and not s.is_final_stop() and not opts.has(s.route[s.stop_index + 1]):
				return "%s: trilha sem a próxima parada" % where
			if not s.is_on_trail() and not opts.has(s.route[s.stop_index]):
				return "%s: cidade errada sem volta pra parada atual" % where
		# I6/I7 save refeito dá o mesmo estado
		if replay_each:
			var back := CaseState.from_save(JSON.parse_string(JSON.stringify(s.to_save())))
			if back == null:
				return "%s: save não refaz" % where
			if _snapshot(back) != after:
				return "%s: save refeito diverge" % where
	return ""

## Estado observável do caso (o que o jogador vê e o que vai pro save).
func _snapshot(s: CaseState) -> Dictionary:
	return {
		"hours": s.clock.hours, "outcome": s.outcome, "stop": s.stop_index, "city": s.current_city,
		"pauta": s.pauta, "dossier": s.dossier.duplicate(), "visited": s.visited.duplicate(true),
		"notes": s.notes.duplicate(true), "actions": s.actions.size(), "wrong": s.wrong_cities, "nights": s.nights,
	}

## Uma ação sorteada; ~1/4 inválidas de propósito. Devolve {kind, valid, ok, desc}.
func _fuzz_action(s: CaseState, r: RandomNumberGenerator) -> Dictionary:
	var roll := r.randi_range(0, 99)
	var invalid := r.randi_range(0, 3) == 0
	if roll < 45:
		var loc: String = "cofre_do_banco"
		if not invalid:
			var locs := s.locations_here()
			loc = locs[r.randi_range(0, locs.size() - 1)]
		return {"kind": "i", "valid": not invalid, "ok": not s.investigate(loc).is_empty(), "desc": "investigar %s" % loc}
	if roll < 80:
		var to: String
		if invalid:
			var all: Array = GameData.cities().map(func(c): return c["id"]).filter(func(id): return not s.travel_options().has(id))
			to = all[r.randi_range(0, all.size() - 1)]
		else:
			var opts := s.travel_options()
			to = opts[r.randi_range(0, opts.size() - 1)]
		return {"kind": "t", "valid": not invalid, "ok": not s.travel(to).is_empty(), "desc": "viajar %s" % to}
	if roll < 92:
		var t: String = GameData.trait_order()[r.randi_range(0, GameData.trait_order().size() - 1)]
		var value := "valor_falso"
		if not invalid:
			var vals: Array = [""] + GameData.trait_values(t)
			value = vals[r.randi_range(0, vals.size() - 1)]
		return {"kind": "d", "valid": not invalid, "ok": s.set_dossier(t, value), "desc": "dossiê %s=%s" % [t, value]}
	var id := "disfarce_falso"
	if not invalid:
		var ds := GameData.disguises()
		id = ds[r.randi_range(0, ds.size() - 1)]["id"]
	return {"kind": "p", "valid": not invalid, "ok": s.set_pauta(id), "desc": "pauta %s" % id}

## I8: jogando com cuidado (os 3 locais de cada cidade, rota direta, pauta
## certa) todo caso gerado é vencível, em todos os cargos.
func _test_always_winnable() -> void:
	var ranks: Array = GameData.flavor()["ranks"]
	for rank in ranks:
		var config := CaseGenerator.config_for_rank(rank)
		var lost: Array = []
		for n in 300:
			var g := RandomNumberGenerator.new()
			g.seed = 800000 + n
			var s := CaseGenerator.generate(g, config)
			s.set_pauta(s.disguise["id"])
			while not s.is_over():
				for loc in s.locations_here():
					if not s.is_over():
						s.investigate(loc)
				if not s.is_over() and not s.is_final_stop():
					s.travel(s.route[s.stop_index + 1])
			if s.outcome != CaseState.Outcome.WIN:
				lost.append(800000 + n)
		_check(lost.is_empty(), "%s: jogo cuidadoso sempre vence (perdeu nas sementes %s)" % [rank["title"], str(lost.slice(0, 5))])

## --- Spec 007 (T65): conteúdo e textos ---------------------------------------------

## Marcadores que o código troca (manchetes da capa). Em qualquer outro texto
## um {marcador} apareceria cru pro jogador.
const HEADLINE_PLACEHOLDERS := ["{city}", "{spot}", "{player}"]

func _test_content_deep() -> void:
	# C1 — todo texto dos JSONs
	var problems: Array = []
	# português e as traduções (spec 008) passam pela mesma revisão
	for dir in ["res://data/", "res://data/i18n/en/", "res://data/i18n/es/"]:
		for f in ["cities", "disguises", "flavor", "scandals", "achievements"]:
			var path: String = dir + f + ".json"
			_scan_text(JSON.parse_string(FileAccess.get_file_as_string(path)), path.trim_prefix("res://data/"), problems)
	var csv := FileAccess.open("res://data/i18n/ui.csv", FileAccess.READ)
	csv.get_csv_line()
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		for i in range(1, row.size()):
			# sufixo colado em outro texto (" (você)") começa com espaço de propósito
			var value: String = row[i].strip_edges() if row[0] != row[0].strip_edges() else row[i]
			_scan_text(value, "ui.csv[%s].%s" % [row[0].left(20), ["", "en", "es"][i]], problems)
	for p in problems.slice(0, 15):
		printerr("  texto: ", p)
	_check(problems.is_empty(), "textos dos JSONs sem espaço sobrando, pontuação torta ou marcador cru (%d problemas)" % problems.size())

	# C1/C2 — falas geradas de verdade em 300 casos jogados
	var bad_speech: Array = []
	var ambiguous := 0
	for n in 300:
		var g := RandomNumberGenerator.new()
		g.seed = 600000 + n
		var s := CaseGenerator.generate(g, CaseGenerator.config_for_rank(GameData.flavor()["ranks"][n % 5]))
		# C2: as pistas da parada i são da cidade route[i+1]
		for i in s.route.size() - 1:
			var next_clues: Array = GameData.city(s.route[i + 1])["clues"]
			for clue in s.route_clues[i]:
				if typeof(clue) != TYPE_INT or clue < 0 or clue >= next_clues.size():
					ambiguous += 1
		s.set_pauta(s.disguise["id"])
		s.travel(s.decoys[0][0])
		var texts: Array = s.locations_here().map(func(loc): return s.investigate(loc).get("text", ""))
		s.travel(s.route[0])
		while not s.is_over():
			for loc in s.locations_here():
				if not s.is_over():
					texts.append(s.investigate(loc).get("text", ""))
			if not s.is_over() and not s.is_final_stop():
				s.travel(s.route[s.stop_index + 1])
		for t in texts:
			if t.strip_edges() == "" or t.contains("{") or t.contains("}") or t.contains("  "):
				bad_speech.append("semente %d: \"%s\"" % [600000 + n, t.left(60)])
	for b in bad_speech.slice(0, 5):
		printerr("  fala: ", b)
	_check(bad_speech.is_empty(), "falas geradas completas (%d ruins)" % bad_speech.size())
	_check(ambiguous == 0, "pistas de cada parada apontam a próxima cidade da rota")

	# C2 — a mesma pista em duas cidades deixaria o jogador sem saber o destino
	var owner := {}
	var shared: Array = []
	for c in GameData.cities():
		for clue in c["clues"]:
			if owner.has(clue) and owner[clue] != c["id"]:
				shared.append("%s / %s: \"%s\"" % [owner[clue], c["id"], clue.left(50)])
			owner[clue] = c["id"]
	for x in shared:
		printerr("  pista repetida: ", x)
	_check(shared.is_empty(), "nenhuma pista usada por duas cidades")

	# C4 — ids únicos, coordenadas no mapa, conquista com regra
	for group in [["cidades", GameData.cities()], ["disfarces", GameData.disguises()], ["escândalos", GameData.scandals()], ["conquistas", Achievements.all()]]:
		var ids := {}
		for item in group[1]:
			ids[item["id"]] = true
		_check(ids.size() == group[1].size(), "ids únicos em %s" % group[0])
	var map_src := FileAccess.get_file_as_string("res://scripts/art/WorldMapView.gd")
	var lat_top: float = _const_value(map_src, "LAT_TOP")
	var lat_bottom: float = _const_value(map_src, "LAT_BOTTOM")
	for c in GameData.cities():
		var on_map: bool = float(c["lon"]) >= -180.0 and float(c["lon"]) <= 180.0 and float(c["lat"]) <= lat_top and float(c["lat"]) >= lat_bottom
		_check(on_map, "%s dentro do mapa" % c["id"])
	var rules := FileAccess.get_file_as_string("res://scripts/core/Achievements.gd")
	for a in Achievements.all():
		_check(rules.contains("\"%s\":" % a["id"]), "conquista %s tem regra" % a["id"])

	# C5 — sons e dicas usados no código existem (e toda dica é usada)
	var code := ""
	for path in _files("res://scripts"):
		if path.ends_with(".gd"):
			code += FileAccess.get_file_as_string(path)
	# AudioManager é autoload (não existe em --script): listas lidas do fonte
	var audio_src := FileAccess.get_file_as_string("res://scripts/autoload/AudioManager.gd")
	var sfx: Array = _const_value(audio_src, "SFX")
	var music: Array = _const_value(audio_src, "MUSIC")
	for name in _calls(code, "play_sfx"):
		_check(sfx.has(name), "efeito '%s' existe" % name)
	for name in _calls(code, "play_music"):
		_check(music.has(name), "música '%s' existe" % name)
	for name in sfx + music:
		var dir: String = _const_value(audio_src, "SFX_DIR") if sfx.has(name) else _const_value(audio_src, "MUSIC_DIR")
		var files: Array = Array(DirAccess.get_files_at(dir)).filter(func(f): return f.get_basename() == name and not f.ends_with(".import"))
		_check(not files.is_empty(), "arquivo de áudio de '%s'" % name)
	var tips: Dictionary = GameData.flavor()["tips"]
	var used_tips := _calls(code, "try_show")
	for name in used_tips:
		_check(tips.has(name), "dica '%s' tem texto" % name)
	for name in tips:
		_check(used_tips.has(name), "dica '%s' é usada no jogo" % name)

## Valor literal de `const NOME := ...` num fonte GDScript.
func _const_value(src: String, name: String) -> Variant:
	var m := RegEx.create_from_string("const " + name + " := (.+)").search(src)
	return str_to_var(m.get_string(1)) if m else null

## Nomes literais passados a `fn("nome")` no código.
func _calls(code: String, fn: String) -> Array:
	var re := RegEx.create_from_string(fn + "\\(\"([a-z_]+)\"")
	var out := {}
	for m in re.search_all(code):
		out[m.get_string(1)] = true
	return out.keys()

## Desce no JSON e confere cada string de texto.
func _scan_text(value: Variant, where: String, problems: Array) -> void:
	if value is Dictionary:
		for k in value:
			_scan_text(value[k], "%s.%s" % [where, k], problems)
	elif value is Array:
		for i in value.size():
			_scan_text(value[i], "%s[%d]" % [where, i], problems)
	elif value is String:
		var s: String = value
		var allowed: Array = HEADLINE_PLACEHOLDERS if where.contains("headlines") else []
		var stripped := s
		for p in allowed:
			stripped = stripped.replace(p, "")
		var issue := ""
		if s != s.strip_edges():
			issue = "espaço nas pontas"
		elif s.contains("  "):
			issue = "espaço duplo"
		elif stripped.contains("{") or stripped.contains("}"):
			issue = "marcador desconhecido"
		elif RegEx.create_from_string(" [,.;:!?](?!\\.)").search(s):
			issue = "espaço antes de pontuação"
		elif RegEx.create_from_string("(?<!\\.)\\.\\.(?!\\.)|,,").search(s):
			issue = "pontuação dobrada"
		elif s.count("\"") % 2 == 1:
			issue = "aspas sem fechar"
		if issue != "":
			problems.append("%s — %s: \"%s\"" % [where, issue, s.left(50)])

## --- Spec 007 (T66): entradas hostis ------------------------------------------------

## E1: nomes que já quebraram (ou quebrariam) manchete, layout ou save.
const HOSTILE_NAMES := ["", "   ", "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWW", "Ana\nFuro", "Ana\tFuro", "\u202Eoruf ana", "Ana\u200B\u200BFuro",
	"{city}", "{player}", "[b]Ana[/b]", "Ana 🎤 Furo", "  Ana    Furo  ", "\u0001\u0002\u007F", "%s %d"]

func _test_hostile_names() -> void:
	for raw in HOSTILE_NAMES:
		var name := Career.sanitize_name(raw)
		var shown: String = raw.c_escape().left(30)
		_check(name.length() <= Career.MAX_NAME_LENGTH, "nome '%s' cabe no limite" % shown)
		_check(name == name.strip_edges() and not name.contains("  "), "nome '%s' sem espaço sobrando" % shown)
		var invisible := false
		for ch in name:
			var code := ch.unicode_at(0)
			if code < 32 or code == 127 or (code >= 0x200B and code <= 0x200F) or (code >= 0x202A and code <= 0x202E):
				invisible = true
		_check(not invisible, "nome '%s' sem caractere de controle/direção" % shown)
		var back := Career.from_dict(Career.from_dict({"player_name": raw}).to_dict())
		_check(back.player_name == name, "nome '%s' igual depois do save" % shown)
	_check(Career.sanitize_name("  Ana    Furo  ") == "Ana Furo", "espaços internos colapsam")
	_check(Career.sanitize_name("Ana\nFuro") == "Ana Furo", "quebra de linha vira espaço")
	_check(Career.sanitize_name(42) == "" and Career.sanitize_name(null) == "", "nome que não é texto vira vazio")

## --- Spec 008 (T80): fontes cobrem todo caractere dos 3 idiomas -------------------

## Texto corrido (VT323) e títulos/botões (Pixelify Sans). A Press Start 2P
## só desenha os logotipos ASCII ("O FURO", "F.U.R.O.").
const TEXT_FONTS := ["res://assets/fonts/VT323-Regular.ttf", "res://assets/fonts/PixelifySans.ttf"]

func _test_fonts_cover_languages() -> void:
	var chars := {}
	var paths: Array = ["res://data/i18n/ui.csv"]
	for f in ["cities", "disguises", "flavor", "scandals", "achievements"]:
		paths.append("res://data/%s.json" % f)
		for lang in ["en", "es"]:
			paths.append("res://data/i18n/%s/%s.json" % [lang, f])
	for path in paths:
		for ch in FileAccess.get_file_as_string(path):
			if ch.unicode_at(0) > 126:
				chars[ch] = true
	for font_path in TEXT_FONTS:
		var font: FontFile = load(font_path)
		var missing := ""
		for ch in chars:
			if not font.has_char(ch.unicode_at(0)):
				missing += ch
		_check(missing == "", "%s desenha todos os caracteres dos 3 idiomas (faltam: %s)" % [font_path.get_file(), missing])

## --- Spec 008 (T82): catálogo e dados por idioma ------------------------------------

const LANG_DATA_FILES := ["cities", "disguises", "flavor", "scandals", "achievements"]

## Catálogo da interface: toda chave usada em Lang.t() existe, e toda linha
## tem inglês e espanhol.
func _test_i18n_catalog() -> void:
	var catalog := {}
	var file := FileAccess.open("res://data/i18n/ui.csv", FileAccess.READ)
	var header := file.get_csv_line()
	_check(header == PackedStringArray(["keys", "en", "es"]), "ui.csv com colunas keys,en,es")
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 3:
			continue
		catalog[row[0]] = true
		_check(row[1].strip_edges() != "" and row[2].strip_edges() != "", "tradução completa de '%s'" % row[0].left(40))
	var re := RegEx.create_from_string("Lang\\.t\\(\"((?:[^\"\\\\]|\\\\.)*)\"\\)")
	var missing: Array = []
	var found := 0
	for path in _files("res://scripts"):
		if not path.ends_with(".gd"):
			continue
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			found += 1
			var key := m.get_string(1).replace("\\\"", "\"").replace("\\n", "\n")
			if not catalog.has(key):
				missing.append(key.left(50))
	_check(found >= 40, "achou os Lang.t() do código (%d)" % found)
	_check(missing.is_empty(), "toda chave de Lang.t() está no catálogo (faltam: %s)" % str(missing.slice(0, 5)))

## Dados traduzidos: mesmos ids, listas do mesmo tamanho (os sorteios
## dependem disso), mesmos marcadores, nenhum campo que o português não tem.
func _test_i18n_data() -> void:
	for lang in ["en", "es"]:
		for f in LANG_DATA_FILES:
			var base = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % f))
			var path := "res://data/i18n/%s/%s.json" % [lang, f]
			_check(FileAccess.file_exists(path), "%s existe" % path)
			var errors: Array = []
			_compare_lang(base, JSON.parse_string(FileAccess.get_file_as_string(path)), "%s/%s" % [lang, f], errors)
			for e in errors.slice(0, 5):
				printerr("  ", e)
			_check(errors.is_empty(), "%s/%s com a mesma estrutura do português (%d problemas)" % [lang, f, errors.size()])
	# o caso guarda índice: trocar o idioma não muda o caso, só o texto
	var g := RandomNumberGenerator.new()
	g.seed = 31
	var s := CaseGenerator.generate(g, {"route_len": 5})
	s.investigate(s.locations_here()[0])
	var before := _snapshot(s)
	var texts := {}
	for lang in Lang.SUPPORTED:
		Lang.apply(lang)
		texts[lang] = ClueBuilder.render(s, s.notes[0]["speech"])["text"]
		_check(_snapshot(s) == before, "trocar pra %s não muda o caso" % lang)
		_check(s.disguise["name"] != "" and s.reason != "" and s.found_spot != "", "caso tem textos em %s" % lang)
	Lang.apply("pt")
	_check(texts["pt"] != texts["en"] and texts["en"] != texts["es"], "anotação muda de idioma junto com o jogo")
	var back := CaseState.from_save(JSON.parse_string(JSON.stringify(s.to_save())))
	Lang.apply("es")
	_check(back != null and _snapshot(back) == before, "save feito em português é retomado em espanhol")
	Lang.apply("pt")

func _compare_lang(base: Variant, over: Variant, where: String, errors: Array) -> void:
	if over is Array:
		if not base is Array:
			errors.append("%s: devia ser lista" % where)
			return
		if not over.is_empty() and over[0] is Dictionary and over[0].has("id"):
			var by_id := {}
			for b in base:
				by_id[b["id"]] = b
			if over.size() != base.size():
				errors.append("%s: %d de %d itens" % [where, over.size(), base.size()])
			for o in over:
				if not by_id.has(o["id"]):
					errors.append("%s: id %s não existe" % [where, o["id"]])
				else:
					_compare_lang(by_id[o["id"]], o, "%s[%s]" % [where, o["id"]], errors)
			return
		if over.size() != base.size():
			errors.append("%s: tamanho %d em vez de %d" % [where, over.size(), base.size()])
			return
		for i in over.size():
			_compare_lang(base[i], over[i], "%s[%d]" % [where, i], errors)
	elif over is Dictionary:
		if not base is Dictionary:
			errors.append("%s: devia ser objeto" % where)
			return
		for k in over:
			if k == "id":
				continue
			if not base.has(k):
				errors.append("%s.%s: campo que o português não tem" % [where, k])
			else:
				_compare_lang(base[k], over[k], "%s.%s" % [where, k], errors)
	elif over is String:
		if not base is String:
			errors.append("%s: devia ser texto" % where)
		elif over.strip_edges() == "":
			errors.append("%s: vazio" % where)
		elif _placeholders(base) != _placeholders(over):
			errors.append("%s: marcadores diferentes" % where)

func _placeholders(s: String) -> Array:
	var out: Array = []
	for m in RegEx.create_from_string("\\{[a-z]+\\}").search_all(s):
		out.append(m.get_string())
	out.sort()
	return out

## RF43: primeira vez segue o idioma do sistema/navegador.
func _test_language_detect() -> void:
	for pair in [["pt_BR", "pt"], ["pt-PT", "pt"], ["es_AR", "es"], ["es", "es"], ["en_US", "en"], ["fr_FR", "en"], ["", "en"]]:
		_check(Lang.detect(pair[0]) == pair[1], "idioma do sistema %s vira %s" % pair)
	_check(Settings.from_dict({"language": "klingon"}).language == "" and Settings.from_dict({"language": "es"}).language == "es", "idioma salvo é sanitizado")

func _test_lower_first() -> void:
	_check(Lang.lower_first("A mansão do Lago Sul") == "a mansão do Lago Sul", "só a primeira letra do título vira minúscula")
	_check(Lang.lower_first("") == "", "título vazio continua vazio")
