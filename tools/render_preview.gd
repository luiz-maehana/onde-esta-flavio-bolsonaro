extends Node
## Renderiza cada tela num PNG em build/preview/ pra conferir layout sem
## precisar jogar (abre uma janela por alguns segundos; não envia tecla
## nenhuma). Roda em modo somente leitura: nunca grava nos saves reais.
## Gera cada tela em 3 tamanhos de janela (RF36): PC, celular deitado e
## celular em pé, nos 3 idiomas (spec 008): build/preview/<idioma>/<tamanho>/.
## Roda com: godot --path . res://tools/RenderPreview.tscn

const OUT := "res://build/preview/"
const SIZES := {"1280x720": Vector2i(1280, 720), "844x390": Vector2i(844, 390), "390x844": Vector2i(390, 844)}

var _dir := OUT

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	SaveService.read_only = true
	for lang in Lang.SUPPORTED:
		Lang.apply(lang)
		for size_name in SIZES:
			_dir = OUT + lang + "/" + size_name + "/"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
			get_window().size = SIZES[size_name]
			await _frames(5)
			# a janela real pode vir em outro tamanho (HiDPI, atraso do SO):
			# a orientação sai do tamanho pedido
			Responsive.forced = 1 if SIZES[size_name].y > SIZES[size_name].x else 0
			# tamanhos de celular: simula tela de toque (botões de 48 px reais)
			Responsive.forced_touch = 0 if size_name == "1280x720" else 1
			UiTheme.reset_theme()
			get_window().content_scale_size = Responsive.base_size()
			await _render_all()
	get_tree().quit()

func _render_all() -> void:
	var gm = GameManager
	gm.settings = Settings.new()
	gm.settings.tips_enabled = false
	gm.career = Career.from_dict({"player_name": "Ana Furo", "cases_solved": 4, "cases_played": 6,
		"best_hours": 88, "clean_wins": 1, "disguises_caught": ["turista", "diva", "mergulhador", "gaucho"],
		"scandals_covered": ["chocolate", "mansao"], "cities_visited": ["rio", "paris", "toquio"],
		"achievements": ["primeiro_furo", "sem_errar", "vexame"]})
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	gm.case = CaseGenerator.generate(rng, CaseGenerator.config_for_rank(gm.career.rank()))
	var case: CaseState = gm.case

	Online.mock = func(m, path, b):
		if path.begins_with("/leaderboard"):
			return {"ok": true, "status": 200, "data": {"entries": [
				{"position": 1, "nickname": "Bia Manchete", "rank_title": "Repórter Sênior", "score": 1240, "hours": 96, "city": "toquio", "is_you": false},
				{"position": 2, "nickname": "Ana Furo", "rank_title": "Repórter", "score": 1105, "hours": 88, "city": "paris", "is_you": true},
				{"position": 3, "nickname": "Repórter Anônimo", "rank_title": "Estagiário(a)", "score": 760, "hours": 120, "city": "rio", "is_you": false},
			]}}
		return {"ok": true, "status": 200, "data": {"online": 37, "interval": 60}}
	await Online.heartbeat()
	Online._timer.stop()
	var title = await _shot("res://scenes/TitleScreen.tscn", "01_title", false)
	title._open_options()
	await _frames(5)
	await _save("01c_options")
	title.queue_free()
	await _shot("res://scenes/BriefingScreen.tscn", "02_briefing")
	await _shot("res://scenes/CareerScreen.tscn", "02b_career")
	var board = await _shot("res://scenes/LeaderboardScreen.tscn", "02c_dummy", false)
	await _frames(5)
	await _save("02c_leaderboard")
	board.queue_free()

	gm.arrival_messages = ["Você desembarca em %s. Hora de trabalhar." % case.start_city()["name"]]
	var city = await _shot("res://scenes/CityScreen.tscn", "03_city", false)
	city._on_location_chosen(case.locations_here()[0])
	await _frames(120)
	await _save("04_witness")
	city.queue_free()

	city = await _shot("res://scenes/CityScreen.tscn", "04b_dummy", false)
	city._open_dossier()
	await _frames(5)
	await _save("04b_dossier")
	city.queue_free()

	city = await _shot("res://scenes/CityScreen.tscn", "05_dummy", false)
	city._open_pause()
	await _frames(5)
	await _save("05_pause")
	city.queue_free()

	gm.settings.tips_enabled = true
	city = await _shot("res://scenes/CityScreen.tscn", "06_tip", false)
	gm.settings.tips_enabled = false
	city.queue_free()

	var travel = await _shot("res://scenes/TravelScreen.tscn", "07_dummy", false)
	travel._highlight(case.route[1])
	travel._map.hovered_id = "cairo"
	await _frames(5)
	await _save("07_travel")
	# avião no meio do voo (spec 012); o pouso troca de tela, então a foto
	# sai antes de ele chegar
	travel._map.fly_to(case.route[1])
	travel._map._flight_t = 0.45
	travel._map.set_process(false)
	travel._map.queue_redraw()
	await _frames(3)
	await _save("07b_flight")
	travel.queue_free()

	case.set_pauta(case.disguise["id"])
	while not case.is_final_stop():
		case.travel(case.route[case.stop_index + 1])
	case.investigate(case.locations_here()[case.hideout_slot])
	gm.last_unlocked = ["primeiro_furo", "relampago"]
	await _shot("res://scenes/EndScreen.tscn", "08_end")

	# caso de parceiro (spec 009)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 7
	gm.case = CaseGenerator.generate(rng2, CaseGenerator.config_for_rank(gm.career.rank()))
	var partner: CaseState = gm.case
	partner.target_id = "marcal"
	partner.scandal_id = "marcal"
	await _shot("res://scenes/BriefingScreen.tscn", "09_parceiro_briefing")
	partner.set_pauta(partner.disguise["id"])
	while not partner.is_final_stop():
		partner.travel(partner.route[partner.stop_index + 1])
	partner.investigate(partner.locations_here()[partner.hideout_slot])
	gm.last_unlocked = []
	await _shot("res://scenes/EndScreen.tscn", "09_parceiro_capa")

func _shot(scene_path: String, shot_name: String, free_after: bool = true) -> Node:
	var node: Control = load(scene_path).instantiate()
	node.theme = UiTheme.theme()
	get_tree().root.add_child(node)
	await _frames(12)
	await _save(shot_name)
	if free_after:
		node.queue_free()
		await _frames(2)
	return node

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_dir + shot_name + ".png")
	print("preview: ", _dir, shot_name)
