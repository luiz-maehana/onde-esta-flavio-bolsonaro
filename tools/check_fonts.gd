extends SceneTree
## Lista caracteres usados nos textos do jogo que faltam nas fontes.
func _initialize() -> void:
	var chars := "ÁÉÍÓÚÂÊÔÃÕÇáéíóúâêôãõçàÀü▶►✓★•—–…'\"’“”ºª°"
	for path in ["res://assets/fonts/PressStart2P-Regular.ttf", "res://assets/fonts/VT323-Regular.ttf"]:
		var f: FontFile = load(path)
		var missing := ""
		for ch in chars:
			if not f.has_char(ch.unicode_at(0)):
				missing += ch
		print(path.get_file(), " faltando: ", missing)
	quit()
