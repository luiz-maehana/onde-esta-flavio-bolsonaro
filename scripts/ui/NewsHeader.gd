class_name NewsHeader
extends PanelContainer
## Faixa de topo estilo cabeçalho de jornal: selo "F.U.R.O.", local, relógio
## e barra do prazo (US5). API: show_place() + show_clock().

var _place: Label
var _sub: Label
var _clock: Label
var _deadline: ProgressBar

func _init() -> void:
	add_theme_stylebox_override("panel", UiTheme.box(Palette.PAPER, Vector2(0, 5)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	add_child(row)

	var logo := PanelContainer.new()
	var logo_box := UiTheme.box(Palette.RED, Vector2.ZERO)
	logo_box.set_content_margin_all(8)
	logo.add_theme_stylebox_override("panel", logo_box)
	logo.add_child(UiTheme.logo("F.U.R.O.", 18, Palette.WHITE))
	row.add_child(logo)

	var place_col := VBoxContainer.new()
	place_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	place_col.add_theme_constant_override("separation", 2)
	_place = UiTheme.headline("", 20)
	_sub = UiTheme.body("", 24, Palette.GREY)
	place_col.add_child(_place)
	place_col.add_child(_sub)
	row.add_child(place_col)

	var clock_col := VBoxContainer.new()
	clock_col.custom_minimum_size.x = 210 if Responsive.is_portrait() else 300
	_clock = UiTheme.headline("", 16)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_col.add_child(_clock)
	_deadline = ProgressBar.new()
	_deadline.show_percentage = false
	_deadline.custom_minimum_size = Vector2(210 if Responsive.is_portrait() else 300, 16)
	_deadline.max_value = 1.0
	_deadline.add_theme_stylebox_override("background", UiTheme.box(Palette.PAPER_DARK, Vector2.ZERO))
	clock_col.add_child(_deadline)
	row.add_child(clock_col)

func show_place(title: String, subtitle: String) -> void:
	_place.text = title
	_sub.text = subtitle

func show_clock(clock: GameClock) -> void:
	_clock.text = clock.time_text()
	_deadline.value = clock.progress()
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.RED if clock.hours_left() < 24 else Palette.INK
	_deadline.add_theme_stylebox_override("fill", fill)
	_deadline.tooltip_text = "%dh até o fechamento da edição de domingo" % clock.hours_left()
