class_name OnlineBadge
extends PanelContainer
## "● 12 repórteres na rua agora" (RF40). Some quando o contador está
## indisponível (sem rede / API fora) — nunca mostra erro pro jogador. A
## bolinha é desenhada (nenhuma das fontes tem o "●"; no navegador não há
## fonte do sistema pra emprestar).

const DOT_RADIUS := 6.0

var _label: Label

func _init() -> void:
	var box := UiTheme.box(Color(Palette.INK, 0.9), Vector2.ZERO, Palette.YELLOW)
	box.set_content_margin_all(8)
	add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var dot := Control.new()
	dot.custom_minimum_size = Vector2.ONE * DOT_RADIUS * 2
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.draw.connect(func(): dot.draw_circle(dot.size / 2, DOT_RADIUS, Palette.YELLOW))
	row.add_child(dot)
	_label = UiTheme.body("", 26, Palette.YELLOW)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_label)

func _ready() -> void:
	Online.online_changed.connect(_show)
	_show(Online.online_count)

static func text_for(count: int) -> String:
	if count == 1:
		return Lang.t("1 repórter na rua agora")
	return Lang.t("%d repórteres na rua agora") % count

func _show(count: int) -> void:
	visible = count > 0
	_label.text = text_for(count)
