class_name OnlineBadge
extends PanelContainer
## "● 12 repórteres na rua agora" (RF40). Some quando o contador está
## indisponível (sem rede / API fora) — nunca mostra erro pro jogador.

var _label: Label

func _init() -> void:
	var box := UiTheme.box(Color(Palette.INK, 0.9), Vector2.ZERO, Palette.YELLOW)
	box.set_content_margin_all(8)
	add_theme_stylebox_override("panel", box)
	_label = UiTheme.body("", 26, Palette.YELLOW)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_label)

func _ready() -> void:
	Online.online_changed.connect(_show)
	_show(Online.online_count)

static func text_for(count: int) -> String:
	if count == 1:
		return "● 1 repórter na rua agora"
	return "● %d repórteres na rua agora" % count

func _show(count: int) -> void:
	visible = count > 0
	_label.text = text_for(count)
