extends Node
## Testes de regressão da interface: monta cada tela/componente de verdade
## (com autoloads), aperta os botões e confere o estado. Somente leitura —
## nunca grava nos saves reais.
## Roda com: godot --headless --path . res://tests/UiTests.tscn
## Sai com código 1 se algo falhar (o CI também falha em SCRIPT ERROR).

var _failures := 0
var _checks := 0
var _screens: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	SaveService.read_only = true
	GameManager.settings = Settings.new()
	GameManager.settings.tips_enabled = false
	GameManager.career = Career.from_dict({"player_name": "Teste", "cases_solved": 1, "cases_played": 2})
	GameManager.screen_requested.connect(func(s): _screens.append(s))

	await _test_options_panel()
	await _test_tips()
	await _test_pause_menu()
	await _test_title_screen()
	await _test_city_flow()
	await _test_screens_build()

	print("\nUI: %d verificações, %d falhas" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FALHOU (UI): ", msg)

func _frames(n: int = 2) -> void:
	for i in n:
		await get_tree().process_frame

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

## Botão (visível) cujo texto é exatamente `text`, em qualquer profundidade.
func _find_button(root: Node, text: String) -> Button:
	for child in root.get_children():
		if child is Button and child.text == text and child.is_visible_in_tree():
			return child
		var found := _find_button(child, text)
		if found:
			return found
	return null

func _press(root: Node, text: String) -> bool:
	var b := _find_button(root, text)
	if b == null:
		return false
	if b.toggle_mode:
		b.button_pressed = not b.button_pressed
	b.pressed.emit()
	return true

func _mount(node: Node) -> Node:
	if node is Control:
		node.theme = UiTheme.theme()
	add_child(node)
	await _frames(3)
	return node

## --- Opções ---------------------------------------------------------------------

func _test_options_panel() -> void:
	var s := GameManager.settings
	var panel := OptionsPanel.new()
	await _mount(panel)
	panel.open()
	await _frames(3)

	# Regressão: "REVER DICAS" ficava preso em "OK!" e o botão de dicas não
	# acompanhava.
	s.tips_enabled = false
	s.seen_tips = ["city", "briefing"]
	panel.open()
	await _frames(3)
	_check(_find_button(panel, OptionsPanel.TIPS_OFF) != null, "dicas desligadas aparecem como DESLIGADAS")
	_check(_press(panel, OptionsPanel.RESET_TEXT), "botão REVER DICAS existe")
	_check(s.tips_enabled and s.seen_tips.is_empty(), "rever dicas religa e zera as vistas")
	_check(_find_button(panel, OptionsPanel.RESET_DONE_TEXT) != null, "rever dicas mostra confirmação")
	_check(_find_button(panel, OptionsPanel.TIPS_ON) != null, "botão de dicas passa a mostrar LIGADAS")
	await _wait(OptionsPanel.RESET_FEEDBACK_SECONDS + 0.3)
	_check(_find_button(panel, OptionsPanel.RESET_TEXT) != null, "confirmação volta para REVER DICAS")
	_check(_find_button(panel, "OK!") == null, "nunca fica preso em OK!")
	_check(_press(panel, OptionsPanel.RESET_TEXT), "rever dicas pode ser usado de novo")

	# Volume e mudo chegam nos barramentos de áudio.
	var sliders: Array = panel.find_children("*", "HSlider", true, false)
	_check(sliders.size() == 2, "dois sliders de volume")
	if sliders.size() == 2:
		sliders[0].value = 40
		sliders[1].value = 0
		await _frames()
		_check(is_equal_approx(s.music_volume, 0.4), "slider de música altera a opção")
		var music_bus := AudioServer.get_bus_index(AudioManager.MUSIC_BUS)
		var sfx_bus := AudioServer.get_bus_index(AudioManager.SFX_BUS)
		_check(absf(AudioServer.get_bus_volume_db(music_bus) - linear_to_db(0.4)) < 0.1, "volume da música aplicado no barramento")
		_check(AudioServer.is_bus_mute(sfx_bus), "efeitos em 0% silenciam o barramento")
	_check(_press(panel, "LIGADO"), "botão de som existe")
	_check(s.muted and AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "mudo silencia o Master")
	_press(panel, "MUDO")
	_check(not s.muted, "desmutar volta o som")

	_check(_press(panel, "INSTANTÂNEO"), "botão de texto instantâneo existe")
	_check(s.text_speed == "instantanea" and s.chars_per_second() == 0.0, "velocidade do texto aplicada")
	_press(panel, "NORMAL")

	var closed := [false]
	panel.closed.connect(func(): closed[0] = true)
	_press(panel, "FECHAR")
	_check(closed[0] and not panel.visible, "FECHAR fecha e avisa")
	panel.queue_free()
	# restaura padrão pros próximos testes
	GameManager.settings = Settings.new()
	GameManager.settings.tips_enabled = false
	GameManager.apply_settings()

## --- Dicas ------------------------------------------------------------------------

func _test_tips() -> void:
	var tips := TipBox.new()
	await _mount(tips)
	GameManager.settings.tips_enabled = true
	_check(tips.try_show("city") and tips.visible, "dica aparece na primeira vez")
	_press(tips, "ENTENDI")
	_check(not tips.visible, "ENTENDI fecha a dica")
	_check(not tips.try_show("city"), "a mesma dica não aparece de novo")
	_check(not tips.try_show("nao_existe"), "dica inexistente não aparece")
	tips.try_show("travel")
	_press(tips, "DESLIGAR DICAS")
	_check(not GameManager.settings.tips_enabled, "DESLIGAR DICAS desliga")
	_check(not tips.try_show("clue"), "com dicas desligadas nada aparece")
	tips.queue_free()

## --- Pausa ------------------------------------------------------------------------

func _test_pause_menu() -> void:
	var pause := PauseMenu.new()
	await _mount(pause)
	pause.open()
	_check(pause.visible, "pausa abre")
	_press(pause, "OPÇÕES")
	await _frames()
	_check(_find_button(pause, "FECHAR") != null, "opções abrem dentro da pausa")
	_press(pause, "FECHAR")
	await _frames()
	_check(_find_button(pause, "CONTINUAR") != null, "fechar opções volta pro menu da pausa")

	# abandonar pede confirmação em dois toques
	_screens.clear()
	_press(pause, "ABANDONAR CASO")
	_check(_screens.is_empty(), "primeiro toque em abandonar não sai")
	_check(_find_button(pause, "CONFIRMAR ABANDONO?") != null, "abandonar pede confirmação")
	_press(pause, "CONFIRMAR ABANDONO?")
	_check(_screens == ["title"], "segundo toque abandona e vai pro título")

	pause.open()
	var resumed := [false]
	pause.resumed.connect(func(): resumed[0] = true)
	_press(pause, "CONTINUAR")
	_check(resumed[0] and not pause.visible, "CONTINUAR fecha a pausa")
	pause.queue_free()

## --- Título -----------------------------------------------------------------------

func _test_title_screen() -> void:
	var title: Control = load("res://scenes/TitleScreen.tscn").instantiate()
	await _mount(title)
	for label in ["NOVO CASO", "CARREIRA", "OPÇÕES", "TROCAR REPÓRTER"]:
		_check(_find_button(title, label) != null, "título tem %s" % label)
	_press(title, "OPÇÕES")
	await _frames()
	_check(_find_button(title, OptionsPanel.RESET_TEXT) != null, "opções abrem no título")
	_press(title, "FECHAR")
	_press(title, "TROCAR REPÓRTER")
	await _frames()
	_check(_find_button(title, "CANCELAR") != null, "troca de repórter tem CANCELAR")
	_press(title, "CANCELAR")
	await _frames()
	_check(_find_button(title, "CANCELAR") == null, "CANCELAR fecha o crachá")
	_check(GameManager.career.player_name == "Teste", "cancelar mantém o repórter")
	_screens.clear()
	_press(title, "CARREIRA")
	_check(_screens == ["career"], "CARREIRA abre a ficha")
	title.queue_free()

## --- Cidade: investigar, viajar, dossiê, pausa ---------------------------------------

func _test_city_flow() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	GameManager.case = CaseGenerator.generate(rng, CaseGenerator.config_for_rank(GameManager.career.rank()))
	var case: CaseState = GameManager.case
	GameManager.settings.text_speed = "instantanea"
	var city: Control = load("res://scenes/CityScreen.tscn").instantiate()
	await _mount(city)

	_check(_press(city, "INVESTIGAR"), "botão INVESTIGAR")
	await _frames()
	var loc_name: String = GameData.location_info(case.locations_here()[0])["name"].to_upper()
	var loc_button: Button = null
	for b in city.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and b.text.begins_with(loc_name):
			loc_button = b
	_check(loc_button != null, "local aparece no painel de investigação")
	if loc_button:
		loc_button.pressed.emit()
		await _frames()
		_check(case.visited.get(case.current_city, []).size() == 1, "investigar registra a visita")
		_check(case.actions.size() == 1 and case.actions[0][0] == "i", "ação registrada pro save")
		_check(_find_button(city, "CONTINUAR >") != null, "testemunha fala")
		_press(city, "CONTINUAR >")
		await _frames()

	_press(city, "VOLTAR")
	_check(_press(city, "DOSSIÊ"), "botão DOSSIÊ")
	await _frames()
	var hat_label: String = GameData.trait_value_info("hat", case.disguise["hat"])["label"]
	var snack_label: String = GameData.trait_value_info("snack", case.disguise["snack"])["label"]
	_press(city, hat_label)
	_press(city, snack_label)
	_check(case.dossier.get("hat") == case.disguise["hat"], "dossiê marca característica")
	var issue := _find_button(city, "EMITIR PAUTA")
	_check(issue != null and not issue.disabled, "com 2 características dá pra emitir a pauta")
	if issue:
		issue.pressed.emit()
	_check(case.pauta == case.disguise["id"], "pauta emitida é a do disfarce certo")
	_press(city, "FECHAR")
	await _frames()

	_press(city, "MENU (ESC)")
	await _frames()
	_check(_find_button(city, "SALVAR E SAIR") != null, "menu da cidade abre a pausa")
	_press(city, "CONTINUAR")
	city.queue_free()
	await _frames()

## --- Toda tela monta sem erro --------------------------------------------------------

func _test_screens_build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	GameManager.case = CaseGenerator.generate(rng, {"route_len": 4})
	var case: CaseState = GameManager.case
	for scene in ["BriefingScreen", "CityScreen", "TravelScreen", "CareerScreen"]:
		var node: Control = load("res://scenes/%s.tscn" % scene).instantiate()
		await _mount(node)
		_check(node.get_child_count() > 0, "%s monta" % scene)
		node.queue_free()
		await _frames()
	case.set_pauta(case.disguise["id"])
	while not case.is_final_stop():
		case.travel(case.route[case.stop_index + 1])
	case.investigate(case.locations_here()[case.hideout_slot])
	GameManager.last_unlocked = ["primeiro_furo"]
	var end: Control = load("res://scenes/EndScreen.tscn").instantiate()
	await _mount(end)
	_check(_find_button(end, "NOVO CASO") != null, "capa final monta com ações")
	end.queue_free()
	await _frames()
