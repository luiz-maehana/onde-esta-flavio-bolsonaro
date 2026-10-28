class_name OptionsPanel
extends PanelContainer
## Opções (RF23): volume de música/efeitos, mudo, tela cheia, velocidade do
## texto e dicas. Cada mudança aplica na hora e salva (GameManager).

signal closed

const TIPS_ON := "LIGADAS"
const TIPS_OFF := "DESLIGADAS"
const RESET_TEXT := "REVER DICAS"
const RESET_DONE_TEXT := "DICAS REATIVADAS"
const RESET_FEEDBACK_SECONDS := 1.5
const WEB_FULLSCREEN_ON := "SIM"
const WEB_FULLSCREEN_OFF := "NÃO"
## Folga entre o painel e as bordas da tela (bordas + respiro).
const MARGIN_TO_SCREEN := 90.0
const RANKING_NOTE := "Ranking online: envia o nome do repórter, a pontuação e um código aleatório do aparelho. Nenhum dado pessoal."

var _first: Control
## Botão de tela cheia da versão Web (null fora dela).
var _web_fullscreen: Button

func _ready() -> void:
	# entrar/sair da tela cheia (inclusive pelo Esc do navegador) redimensiona
	get_tree().root.size_changed.connect(_sync_web_fullscreen)

func _init() -> void:
	add_theme_stylebox_override("panel", UiTheme.box(Palette.PAPER))
	custom_minimum_size = Vector2(660 if Responsive.is_portrait() else 720, 0)

func open() -> void:
	for child in get_children():
		child.queue_free()
	_build()
	visible = true
	_first.call_deferred("grab_focus")

func _build() -> void:
	var s := GameManager.settings
	# título e rodapé fixos; as opções rolam se não couberem (celular deitado,
	# com botões de 48 px reais)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	add_child(outer)
	outer.add_child(UiTheme.headline("OPÇÕES", 20, Palette.RED))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	outer.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 14)
	scroll.add_child(col)

	_first = _slider_row(col, "MÚSICA", s.music_volume, func(v):
		s.music_volume = v
		GameManager.save_settings())
	_slider_row(col, "EFEITOS", s.sfx_volume, func(v):
		s.sfx_volume = v
		GameManager.save_settings()
		AudioManager.play_sfx("clue"))
	_row(col, "SOM", UiTheme.toggle("MUDO", "LIGADO", s.muted, func(on):
		s.muted = on
		GameManager.save_settings()))
	if not OS.has_feature("web"):
		_row(col, "TELA CHEIA", UiTheme.toggle("SIM (F11)", "NÃO (F11)", s.fullscreen, func(on):
			s.fullscreen = on
			GameManager.save_settings()))
	elif not OS.has_feature("web_ios"):
		# navegador: tela cheia só a partir de um clique (não dá pra religar ao
		# abrir o jogo), então não é salva; o botão mostra o estado real, já que
		# Esc no navegador também sai. Safari do iPhone não tem tela cheia.
		_web_fullscreen = UiTheme.toggle(WEB_FULLSCREEN_ON, WEB_FULLSCREEN_OFF, _is_fullscreen(), func(on):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
		_row(col, "TELA CHEIA", _web_fullscreen)

	var speeds := HBoxContainer.new()
	Responsive.fill_row(speeds, true)
	speeds.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for speed in Settings.TEXT_SPEEDS:
		var label: String = {"lenta": "LENTO", "normal": "NORMAL", "instantanea": "INSTANTÂNEO"}[speed]
		var b := UiTheme.button(label, Vector2(150, 48))
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = s.text_speed == speed
		b.toggled.connect(func(on):
			if on:
				s.text_speed = speed
				GameManager.save_settings())
		speeds.add_child(b)
	_row(col, "TEXTO", speeds)

	# idioma (spec 008): cada um escrito nele mesmo; troca na hora
	var languages := HBoxContainer.new()
	Responsive.fill_row(languages, true)
	languages.add_theme_constant_override("separation", 8)
	var language_group := ButtonGroup.new()
	language_group.allow_unpress = false
	for code in Lang.SUPPORTED:
		var lb := UiTheme.button(Lang.NAMES[code], Vector2(150, 48))
		lb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		lb.toggle_mode = true
		lb.button_group = language_group
		lb.button_pressed = code == Lang.current
		lb.toggled.connect(func(on):
			if on:
				GameManager.set_language(code))
		languages.add_child(lb)
	_row(col, "IDIOMA", languages)

	var tips := HBoxContainer.new()
	Responsive.fill_row(tips, true)
	tips.add_theme_constant_override("separation", 8)
	var tips_toggle := UiTheme.toggle(TIPS_ON, TIPS_OFF, s.tips_enabled, func(on):
		s.tips_enabled = on
		GameManager.save_settings())
	tips.add_child(tips_toggle)
	var reset := UiTheme.button(RESET_TEXT, Vector2(240, 48))
	reset.pressed.connect(func(): _reset_tips(tips_toggle, reset))
	tips.add_child(reset)
	_row(col, "DICAS", tips)

	var ranking := HBoxContainer.new()
	Responsive.fill_row(ranking, true)
	ranking.add_theme_constant_override("separation", 8)
	var ranking_group := ButtonGroup.new()
	ranking_group.allow_unpress = false
	for choice in [["yes", "PARTICIPAR"], ["no", "NÃO PARTICIPAR"]]:
		var rb := UiTheme.button(choice[1], Vector2(230, 48))
		rb.toggle_mode = true
		rb.button_group = ranking_group
		rb.button_pressed = s.ranking == choice[0]
		rb.toggled.connect(func(on):
			if on:
				s.ranking = choice[0]
				GameManager.save_settings())
		ranking.add_child(rb)
	_row(col, "RANKING", ranking)
	col.add_child(UiTheme.body(RANKING_NOTE, 22, Palette.GREY))

	var footer := HBoxContainer.new()
	outer.add_child(footer)
	var version := UiTheme.body(version_text(), 22, Palette.GREY)
	version.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	version.size_flags_vertical = Control.SIZE_SHRINK_END
	footer.add_child(version)
	var close := UiTheme.button("FECHAR", Vector2(180, 52))
	close.pressed.connect(func():
		visible = false
		closed.emit())
	footer.add_child(close)
	_fit_height(outer, scroll, col)

## Rolagem só com a altura que faltar: mede um quadro depois de montar (antes
## disso o Godot ainda não calculou o tamanho do texto).
func _fit_height(outer: Control, scroll: ScrollContainer, col: Control) -> void:
	scroll.custom_minimum_size.y = Responsive.base_size().y / 2.0
	await get_tree().process_frame
	if not is_instance_valid(scroll):
		return
	var fixed := outer.get_combined_minimum_size().y - scroll.get_combined_minimum_size().y
	scroll.custom_minimum_size.y = minf(col.get_combined_minimum_size().y, Responsive.base_size().y - MARGIN_TO_SCREEN - fixed)

static func _is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

## Botão da Web acompanha o estado real da janela.
func _sync_web_fullscreen() -> void:
	if is_instance_valid(_web_fullscreen):
		_web_fullscreen.set_pressed_no_signal(_is_fullscreen())
		_web_fullscreen.text = WEB_FULLSCREEN_ON if _is_fullscreen() else WEB_FULLSCREEN_OFF

## Versão do jogo: o CI grava `git describe` (tag + commits depois + hash)
## em application/config/version antes de exportar — diz qual código está no
## ar. Rodando local é "dev".
static func version_text() -> String:
	return Lang.t("Versão %s") % str(ProjectSettings.get_setting("application/config/version", "dev"))

## Rever dicas: zera as vistas e religa as dicas — o botão de liga/desliga ao
## lado passa a mostrar LIGADAS, e o próprio botão confirma por um instante
## e volta ao texto normal (pode ser usado de novo).
func _reset_tips(tips_toggle: Button, reset: Button) -> void:
	var s := GameManager.settings
	s.seen_tips.clear()
	s.tips_enabled = true
	GameManager.save_settings()
	tips_toggle.set_pressed_no_signal(true)
	tips_toggle.text = TIPS_ON
	reset.text = RESET_DONE_TEXT
	# tween preso ao botão: some junto se o painel fechar antes
	var tween := reset.create_tween()
	tween.tween_interval(RESET_FEEDBACK_SECONDS)
	tween.tween_callback(func(): reset.text = RESET_TEXT)

## Rótulo à esquerda (deitado) ou em cima (em pé).
func _row(col: VBoxContainer, label: String, control: Control) -> void:
	var row := Responsive.flow_box()
	row.add_theme_constant_override("separation", 4 if Responsive.is_portrait() else 16)
	var l := UiTheme.body(label, 30)
	l.custom_minimum_size.x = 170
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	col.add_child(row)

## Linha com slider 0–100% (passo de 5) e o valor ao lado.
func _slider_row(col: VBoxContainer, label: String, value: float, on_change: Callable) -> HSlider:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = round(value * 100)
	slider.custom_minimum_size = Vector2(320, 32)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	var pct := UiTheme.body("%d%%" % int(slider.value), 30)
	pct.custom_minimum_size.x = 70
	slider.value_changed.connect(func(v):
		pct.text = "%d%%" % int(v)
		on_change.call(v / 100.0))
	box.add_child(slider)
	box.add_child(pct)
	_row(col, label, box)
	return slider
