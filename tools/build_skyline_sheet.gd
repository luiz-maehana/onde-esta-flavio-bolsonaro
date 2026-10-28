extends SceneTree
## Folha de revisão (spec 011): o cenário de todas as cidades numa imagem
## só, de dia (build/skylines_day.png) e à noite (build/skylines_night.png),
## em quadros de fator 2 (a folha inteira cabe numa tela de 1920x1200).
## Precisa de janela (desenha numa SubViewport), não roda com --headless.
## Roda com: godot --path . --script res://tools/build_skyline_sheet.gd

const CELL := Vector2(280, 220)
const COLS := 6
const PAD := 6.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var cities := GameData.cities()
	var rows := ceili(cities.size() / float(COLS))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(int(COLS * (CELL.x + PAD) + PAD), int(rows * (CELL.y + PAD) + PAD))
	var board := ColorRect.new()
	board.color = Color("#151515")
	board.size = Vector2(root.size)
	root.add_child(board)
	var views: Array[SkylineView] = []
	for i in cities.size():
		var view := SkylineView.new()
		view.position = Vector2(PAD + (i % COLS) * (CELL.x + PAD), PAD + (i / COLS) * (CELL.y + PAD))
		view.size = CELL
		board.add_child(view)
		view.city = cities[i]
		views.append(view)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	for shot in [["day", 10], ["night", 22]]:
		for view in views:
			view.hour = shot[1]
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().get_region(Rect2i(Vector2i.ZERO, Vector2i(board.size))).save_png("res://build/skylines_%s.png" % shot[0])
		print("sheet: skylines_%s.png" % shot[0])
	quit()
