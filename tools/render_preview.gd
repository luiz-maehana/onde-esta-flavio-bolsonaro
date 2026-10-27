extends Node
## Renderiza cada tela num PNG em build/preview/ pra conferir layout sem
## precisar jogar (abre uma janela por alguns segundos; não envia tecla
## nenhuma). Roda em modo somente leitura: nunca grava nos saves reais.
## Roda com: godot --path . res://tools/RenderPreview.tscn

const OUT := "res://build/preview/"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()

func _run() -> void:
	SaveService.read_only = true
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

	var title = await _shot("res://scenes/TitleScreen.tscn", "01_title", false)
	title._open_options()
	await _frames(5)
	await _save("01c_options")
	title.queue_free()
	await _shot("res://scenes/BriefingScreen.tscn", "02_briefing")
	await _shot("res://scenes/CareerScreen.tscn", "02b_career")

	gm.arrival_messages = ["Você desembarca em %s. Hora de trabalhar." % case.start_city()["name"]]
	var city = await _shot("res://scenes/CityScreen.tscn", "03_city", false)
	city._on_location_chosen(case.locations_here()[0])
	await _frames(120)
	await _save("04_witness")
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
	travel.queue_free()

	case.set_pauta(case.disguise["id"])
	while not case.is_final_stop():
		case.travel(case.route[case.stop_index + 1])
	case.investigate(case.locations_here()[case.hideout_slot])
	gm.last_unlocked = ["primeiro_furo", "relampago"]
	await _shot("res://scenes/EndScreen.tscn", "08_end")
	get_tree().quit()

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
	get_viewport().get_texture().get_image().save_png(OUT + shot_name + ".png")
	print("preview: ", shot_name)
