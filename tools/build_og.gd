extends SceneTree
## Gera assets/web/og.jpg (1200x630) a partir da arte de capa — imagem do
## cartão de compartilhamento (RF35). JPG leve: o WhatsApp ignora prévia
## acima de ~300 KB. Copiada pro site pelo workflow (fora do pacote do jogo).
## Roda com: godot --headless --path . --script res://tools/build_og.gd

func _initialize() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/title_background.png"))
	var w := 1200
	var h := int(round(img.get_height() * (w / float(img.get_width()))))
	img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var cropped := img.get_region(Rect2i(0, (h - 630) / 2, w, 630))
	cropped.save_jpg("res://assets/web/og.jpg", 0.82)
	print("og: ", FileAccess.get_file_as_bytes("res://assets/web/og.jpg").size(), " bytes")
	quit()
