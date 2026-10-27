extends Control
## Tela de título (US1/US2): arte do usuário de fundo, faixa de tinta embaixo
## com carreira + menu, aviso de paródia, e o cadastro do nome do repórter.

const BACKGROUND := preload("res://assets/ui/title_background.png")
const DISCLAIMER := "PARÓDIA — piadas e situações são inventadas. Os boxes \"Entenda o caso\" resumem reportagens publicadas, com o status de cada apuração (investigação não é condenação). Sem afiliação com partidos ou com Carmen Sandiego."

var _menu_buttons: Array = []
var _career_label: Label
## Camada modal (escurece o fundo e centraliza o crachá).
var _name_dialog: Control
var _name_edit: LineEdit
var _name_cancel: Button
var _name_warning: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	AudioManager.play_music("title")

	var bg := TextureRect.new()
	bg.texture = BACKGROUND
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_build_bottom_bar()
	_build_name_dialog()
	_refresh()
	if GameManager.has_player():
		UiTheme.focus_first(_menu_buttons)
	else:
		_open_name_dialog()

func _build_bottom_bar() -> void:
	var bar := PanelContainer.new()
	var sb := UiTheme.box(Color(Palette.INK, 0.92), Vector2.ZERO, Palette.RED)
	sb.border_width_left = 0
	sb.border_width_right = 0
	sb.border_width_bottom = 0
	sb.border_width_top = 6
	sb.set_content_margin_all(18)
	bar.add_theme_stylebox_override("panel", sb)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -170
	add_child(bar)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	bar.add_child(col)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	col.add_child(row)

	_career_label = UiTheme.body("", 30, Palette.PAPER)
	_career_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_career_label)

	var new_case := UiTheme.button("NOVO CASO", Vector2(210, 64))
	new_case.pressed.connect(GameManager.start_new_case)
	var change := UiTheme.button("TROCAR REPÓRTER", Vector2(270, 64))
	change.pressed.connect(_open_name_dialog)
	var quit := UiTheme.button("SAIR", Vector2(120, 64))
	quit.pressed.connect(func(): get_tree().quit())
	## No navegador "sair" não fecha nada — só some com o botão.
	quit.visible = not OS.has_feature("web")
	_menu_buttons = [new_case, change, quit]
	for b in _menu_buttons:
		row.add_child(b)

	col.add_child(UiTheme.body(DISCLAIMER, 22, Palette.GREY))

func _build_name_dialog() -> void:
	_name_dialog = ColorRect.new()
	_name_dialog.color = Color(Palette.INK, 0.6)
	_name_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_name_dialog)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_name_dialog.add_child(center)
	var card := UiTheme.panel()
	card.custom_minimum_size = Vector2(620, 0)
	center.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	card.add_child(col)
	col.add_child(UiTheme.headline("CRACHÁ DE IMPRENSA", 20, Palette.RED))
	col.add_child(UiTheme.body("Bem-vindo(a) à Agência F.U.R.O. — Força Unificada de Repórteres Obstinados. Qual é o seu nome?"))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Seu nome"
	_name_edit.max_length = 18
	_name_edit.text_submitted.connect(func(_t): _confirm_name())
	col.add_child(_name_edit)
	_name_warning = UiTheme.body("Atenção: um repórter novo começa a carreira do zero.", 26, Palette.RED)
	col.add_child(_name_warning)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	col.add_child(buttons)
	_name_cancel = UiTheme.button("CANCELAR", Vector2(200, 56))
	_name_cancel.pressed.connect(_close_name_dialog)
	buttons.add_child(_name_cancel)
	var ok := UiTheme.button("ASSINAR CONTRATO", Vector2(0, 56))
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(_confirm_name)
	buttons.add_child(ok)
	_name_dialog.visible = false

func _open_name_dialog() -> void:
	## Cancelar só faz sentido se já existe um repórter pra voltar.
	_name_cancel.visible = GameManager.has_player()
	_name_warning.visible = GameManager.has_player()
	_name_dialog.visible = true
	_name_edit.text = ""
	_name_edit.call_deferred("grab_focus")

func _close_name_dialog() -> void:
	_name_dialog.visible = false
	UiTheme.focus_first(_menu_buttons)

func _confirm_name() -> void:
	if _name_edit.text.strip_edges() == "":
		AudioManager.play_sfx("alert")
		return
	GameManager.set_player_name(_name_edit.text)
	_name_dialog.visible = false
	_refresh()
	UiTheme.focus_first(_menu_buttons)

func _refresh() -> void:
	var c := GameManager.career
	if not GameManager.has_player():
		_career_label.text = "Nenhum repórter contratado ainda."
		return
	var next := c.next_rank()
	var progress := "cargo máximo!" if next.is_empty() else _missing_text(next["min_cases"] - c.cases_solved)
	_career_label.text = "%s — %s\n%d de %d casos resolvidos · %s" % [c.player_name, c.rank()["title"], c.cases_solved, c.cases_played, progress]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _name_dialog.visible and _name_cancel.visible:
		_close_name_dialog()
		get_viewport().set_input_as_handled()

func _missing_text(cases: int) -> String:
	return "falta 1 p/ promoção" if cases == 1 else "faltam %d p/ promoção" % cases
