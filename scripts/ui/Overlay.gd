class_name Overlay
extends ColorRect
## Camada modal: escurece a tela, bloqueia o clique no que está atrás e
## centraliza um conteúdo. Base de PauseMenu, TipBox e Opções no título.

var center: CenterContainer

func _init() -> void:
	color = Color(Palette.INK, 0.7)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	visible = false
