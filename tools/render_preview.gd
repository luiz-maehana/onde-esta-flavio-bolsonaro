extends Node
## Renderiza cada tela num PNG em build/preview/ pra conferir layout sem
## precisar jogar (abre uma janela por alguns segundos; não envia tecla
## nenhuma). Roda com: godot --path . res://tools/RenderPreview.tscn

const OUT := "res://build/preview/"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()

func _run() -> void:
	var gm = GameManager
	gm.career = Career.from_dict({"player_name": "Ana Furo", "cases_solved": 2, "cases_played": 3})
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	gm.case = CaseGenerator.generate(rng, 5)
	var case: CaseState = gm.case

	var title = await _shot("res://scenes/TitleScreen.tscn", "01_title", false)
	title._open_name_dialog()
	await _frames(5)
	await _save("01b_change_reporter")
	title.queue_free()
	await _shot("res://scenes/BriefingScreen.tscn", "02_briefing")
	gm.arrival_messages = ["Você desembarca em %s. Hora de trabalhar." % case.start_city()["name"]]
	var city = await _shot("res://scenes/CityScreen.tscn", "03_city", false)
	city._on_location_chosen(case.locations_here()[0])
	await _frames(90)
	await _save("04_witness")
	city.queue_free()
	city = await _shot("res://scenes/CityScreen.tscn", "05_city_dummy", false)
	case.dossier = {"hat": case.disguise["hat"], "snack": case.disguise["snack"]}
	city._open_dossier()
	await _frames(5)
	await _save("05_dossier")
	city.queue_free()
	var travel = await _shot("res://scenes/TravelScreen.tscn", "06_travel", false)
	travel._highlight(case.route[1])
	await _frames(5)
	await _save("06_travel")
	travel.queue_free()
	case.clock.hours = 3 * 24 + 21
	case.travel(case.route[1])
	await _shot("res://scenes/CityScreen.tscn", "07_city_night")
	case.pauta = case.disguise["id"]
	case.stop_index = case.route.size() - 1
	case.current_city = case.route[case.stop_index]
	var final_city = await _shot("res://scenes/CityScreen.tscn", "07b_dummy", false)
	final_city._on_location_chosen(case.locations_here()[case.hideout_slot])
	await _frames(150)
	await _save("07b_capture")
	final_city.queue_free()
	case.outcome = CaseState.Outcome.WIN
	await _shot("res://scenes/EndScreen.tscn", "08_end_win")
	get_tree().quit()

func _shot(scene_path: String, name: String, free_after: bool = true) -> Node:
	var node: Control = load(scene_path).instantiate()
	node.theme = UiTheme.theme()
	get_tree().root.add_child(node)
	await _frames(12)
	await _save(name)
	if free_after:
		node.queue_free()
		await _frames(2)
	return node

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + name + ".png")
	print("preview: ", name)
