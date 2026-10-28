extends SceneTree
## Folha de revisão (spec 003): todos os retratos numa imagem só, em
## build/portraits.png. Linha 1: procurado, oficial e os 8 disfarces; linhas
## seguintes: 2 testemunhas de cada local.
## Roda com: godot --headless --path . --script res://tools/build_portrait_sheet.gd

const SCALE := 3
const CELL := PortraitPainter.SIZE * SCALE + 8
const COLS := 10

func _initialize() -> void:
	# o Flávio e os parceiros (spec 009): procurado e foto oficial
	var specs: Array = []
	for t in GameData.targets():
		specs.append(PortraitFactory.target_wanted_spec(t["id"]))
		specs.append(PortraitFactory.target_official_spec(t["id"]))
	for d in GameData.disguises():
		specs.append(PortraitFactory.flavio_spec(d.get("portrait", {})))
	for loc_id in GameData.flavor()["locations"]:
		for i in 2:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("%s:%d" % [loc_id, i])
			specs.append(PortraitFactory.witness_spec(rng, GameData.location_info(loc_id)["outfit"]))
	var rows := ceili(specs.size() / float(COLS))
	var sheet := Image.create(COLS * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#D9CFB4"))
	for i in specs.size():
		var img := PortraitFactory.paint(specs[i])
		img.resize(PortraitPainter.SIZE * SCALE, PortraitPainter.SIZE * SCALE, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % COLS) * CELL + 4, (i / COLS) * CELL + 4))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	sheet.save_png("res://build/portraits.png")
	print("sheet: ", specs.size(), " retratos")
	quit()
