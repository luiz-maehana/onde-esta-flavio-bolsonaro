extends Node
## Testes de regressão da interface: monta cada tela/componente de verdade
## (com autoloads), aperta os botões e confere o estado. Somente leitura —
## nunca grava nos saves reais.
## Roda com: godot --headless --path . res://tests/UiTests.tscn
## Sai com código 1 se algo falhar (o CI também falha em SCRIPT ERROR).

var _failures := 0
var _checks := 0
var _screens: Array[String] = []
var _log := ErrorLog.new()

## Guarda todo erro do motor (erro de script, lambda com captura liberada...)
## pra os testes dizerem em que passo aconteceu.
class ErrorLog extends Logger:
	var errors: PackedStringArray = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, backtrace: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			var where := "%s:%d %s" % [file.get_file(), line, function]
			for bt in backtrace:
				if bt.get_frame_count() > 0:
					where = "%s:%d %s" % [bt.get_frame_file(0).get_file(), bt.get_frame_line(0), bt.get_frame_function(0)]
					break
			errors.append("%s (%s)" % [rationale if rationale != "" else code, where])

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	OS.add_logger(_log)
	SaveService.read_only = true
	GameManager.settings = Settings.new()
	# o GameManager abriu no idioma da máquina (o CI é inglês): fixa o português
	Lang.apply("pt")
	GameManager.settings.tips_enabled = false
	GameManager.career = Career.from_dict({"player_name": "Teste", "cases_solved": 1, "cases_played": 2})
	GameManager.screen_requested.connect(func(s): _screens.append(s))

	await _test_options_panel()
	await _test_tips()
	await _test_pause_menu()
	await _test_title_screen()
	await _test_city_flow()
	await _test_screens_build()
	await _test_career_album()
	await _test_partner_case()
	await _test_layout_all_languages()
	await _test_art_proportions()
	await _test_rotation()
	await _test_reentrancy()
	await _test_monkey()
	await _test_full_game_by_click()
	await _test_hostile_inputs()
	await _test_keyboard()
	await _test_no_portuguese_left()
	await _test_language_switch()
	await _test_online()
	_check(_log.errors.is_empty(), "nenhum erro do motor durante os testes: %s" % "; ".join(_log.errors.slice(0, 5)))

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
	var option_texts: Array = title.find_children("*", "Label", true, false).filter(func(l): return l.is_visible_in_tree()).map(func(l): return l.text)
	_check(option_texts.has(OptionsPanel.version_text()) and OptionsPanel.version_text().begins_with("Versão "), "opções mostram a versão")
	_check(_find_button(title, "SIM (F11)") != null or _find_button(title, "NÃO (F11)") != null, "opções têm tela cheia")
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

## --- Spec 007 (T69): cabe na tela e girar no meio ----------------------------------------

## U5: cada tela e cada overlay, deitado e em pé, com os textos mais longos
## do jogo (nome de 18 letras largas, maior cidade, cargo, escândalo e
## disfarce). Nada visível pode passar das bordas da tela.
## Aparelhos simulados: [nome, orientação, lado curto em px de CSS, toque].
## Celular de 360 px em 16:9 é o pior caso de altura (deitado) e de escala.
const LAYOUT_PROFILES := [
	["PC deitado", 0, 720.0, 0],
	["janela em pé", 1, 720.0, 0],
	["celular deitado", 0, 360.0, 1],
	["celular em pé", 1, 360.0, 1],
]

func _test_layout_fits() -> void:
	GameManager.career = _longest_career()
	for profile in LAYOUT_PROFILES:
		Responsive.forced = profile[1]
		Responsive.forced_short_side = profile[2]
		Responsive.forced_touch = profile[3]
		UiTheme.reset_theme()
		var tag: String = "%s [%s]" % [profile[0], Lang.current]
		_extreme_case()
		var title := await _layout_box(load("res://scenes/TitleScreen.tscn").instantiate())
		_check_fits(title, "Título " + tag)
		var art: Array = title.find_children("*", "TextureRect", true, false).map(func(t): return t.texture)
		var screen: Control = title.get_child(0)
		var expected: String = screen.art_path(Lang.current, Responsive.is_portrait())
		_check(art.any(func(t): return t != null and t.resource_path == expected), "título usa a arte %s (%s)" % [expected.get_file(), tag])
		title.get_child(0)._open_name_dialog()
		await _frames(3)
		_check_fits(title, "Crachá " + tag)
		var badge: Node = title.get_child(0).find_children("*", "OnlineBadge", false, false).front()
		_check(badge.get_index() < title.get_child(0)._name_dialog.get_index(), "selo online fica embaixo do crachá (%s)" % tag)
		if Responsive.is_touch():
			var field: Control = title.get_child(0)._name_edit
			_check(field.get_global_rect().end.y < title.size.y * 0.5, "campo do nome na metade de cima, acima do teclado virtual (%s)" % tag)
		title.get_child(0)._close_name_dialog()
		title.get_child(0)._open_options()
		await _frames(3)
		_check_fits(title, "Opções " + tag)
		await _free_box(title)

		for scene in ["BriefingScreen", "TravelScreen", "CareerScreen", "LeaderboardScreen"]:
			var box := await _layout_box(load("res://scenes/%s.tscn" % scene).instantiate())
			_check_fits(box, "%s %s" % [scene, tag])
			await _free_box(box)

		var city_box := await _layout_box(load("res://scenes/CityScreen.tscn").instantiate())
		var city := city_box.get_child(0)
		_check_fits(city_box, "Cidade " + tag)
		for panel in [["Dossiê", "_open_dossier"], ["Anotações", "_open_notes"], ["Investigar", "_open_investigate"], ["Pausa", "_open_pause"]]:
			city.call(panel[1])
			await _frames(3)
			_check_fits(city_box, "%s %s" % [panel[0], tag])
			city._pause.close()
			city._back_to_actions()
		city._on_location_chosen(GameManager.case.locations_here()[0])
		city._witness.show_speech("TESTEMUNHA · 4H", _longest_speech(), null)
		await _frames(3)
		_check_fits(city_box, "Fala mais longa " + tag)
		var cont: Button = _find_button(city._witness, "CONTINUAR >")
		_check(cont != null and city._witness.get_global_rect().encloses(cont.get_global_rect()), "CONTINUAR dentro da caixa com a fala mais longa (%s)" % tag)
		await _free_box(city_box)

		var tip_box := await _layout_box(TipBox.new())
		GameManager.settings.tips_enabled = true
		GameManager.settings.seen_tips.clear()
		tip_box.get_child(0).try_show(_longest_key(GameData.flavor()["tips"]))
		await _frames(3)
		_check_fits(tip_box, "Dica mais longa " + tag)
		GameManager.settings.tips_enabled = false
		await _free_box(tip_box)

		_finish_extreme_case()
		GameManager.settings.ranking = "ask"
		GameManager.last_online_result = {"status": "done", "published": false, "score": 9999, "outcome": CaseState.Outcome.WIN}
		var end_box := await _layout_box(load("res://scenes/EndScreen.tscn").instantiate())
		_check_fits(end_box, "Capa + pergunta do ranking " + tag)
		await _free_box(end_box)
		# carimbo girado não pode invadir a linha do ranking embaixo dele
		GameManager.settings.ranking = "yes"
		GameManager.last_online_result = {"status": "done", "published": true, "position": 1, "score": 830, "outcome": CaseState.Outcome.WIN}
		end_box = await _layout_box(load("res://scenes/EndScreen.tscn").instantiate())
		var online: Label = end_box.get_child(0)._online_label
		var stamps: Array = end_box.find_children("*", "PanelContainer", true, false).filter(func(p): return p.rotation != 0.0)
		var stamp_bottom := -INF
		for p in stamps:
			var xf: Transform2D = p.get_global_transform()
			for corner in [Vector2.ZERO, Vector2(p.size.x, 0), Vector2(0, p.size.y), p.size]:
				stamp_bottom = maxf(stamp_bottom, (xf * corner).y)
		_check(not stamps.is_empty() and stamp_bottom <= online.get_global_rect().position.y + 1,
			"carimbo acima da linha do ranking (%s: fundo %.0f, linha %.0f)" % [tag, stamp_bottom, online.get_global_rect().position.y])
		await _free_box(end_box)
		GameManager.last_online_result = {}
	Responsive.forced = -1
	Responsive.forced_short_side = -1.0
	Responsive.forced_touch = -1
	UiTheme.reset_theme()
	GameManager.career = Career.from_dict({"player_name": "Teste", "cases_solved": 1, "cases_played": 2})

var _longest_speech_cache := {}

## A fala mais longa que o jogo gera de fato: 300 casos jogados inteiros
## (todo local de toda cidade, com desvio) + imprevistos e diário de sono.
func _longest_speech() -> String:
	if _longest_speech_cache.has(Lang.current):
		return _longest_speech_cache[Lang.current]
	var texts: Array = GameData.flavor()["sleep"].duplicate()
	for g in GameData.flavor()["gags"]:
		texts.append(g["text"])
	for n in 300:
		var rng := RandomNumberGenerator.new()
		rng.seed = 400000 + n
		var s := CaseGenerator.generate(rng, CaseGenerator.config_for_rank(GameData.flavor()["ranks"][n % 5]))
		for g in s.scandal.get("gags", []):
			texts.append(g["text"])
		s.travel(s.decoys[0][0])
		for loc in s.locations_here():
			texts.append(s.investigate(loc).get("text", ""))
		s.travel(s.route[0])
		while not s.is_over():
			for loc in s.locations_here():
				if not s.is_over():
					texts.append(s.investigate(loc).get("text", ""))
			if not s.is_over() and not s.is_final_stop():
				s.travel(s.route[s.stop_index + 1])
	_longest_speech_cache[Lang.current] = _longest(texts)
	return _longest_speech_cache[Lang.current]

## Carreira com o nome mais largo possível e o cargo de título mais longo.
func _longest_career() -> Career:
	var ranks: Array = GameData.flavor()["ranks"]
	var longest: Dictionary = ranks[0]
	for r in ranks:
		if r["title"].length() > longest["title"].length():
			longest = r
	return Career.from_dict({"player_name": "W".repeat(Career.MAX_NAME_LENGTH), "cases_solved": longest["min_cases"], "cases_played": 99,
		"achievements": Achievements.all().map(func(a): return a["id"])})

## Caso com a cidade, o escândalo e o disfarce de textos mais longos (só pra
## desenhar — mexe direto nos campos).
func _extreme_case() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var case := CaseGenerator.generate(rng, CaseGenerator.config_for_rank(GameManager.career.rank()))
	var longest_city: Dictionary = GameData.cities()[0]
	for c in GameData.cities():
		if (c["name"] + c["country"]).length() > (longest_city["name"] + longest_city["country"]).length():
			longest_city = c
	case.route[0] = longest_city["id"]
	case.current_city = longest_city["id"]
	# alvo com a apresentação mais longa (spec 009) e o escândalo mais longo
	# entre os do Flávio e os dos parceiros
	var longest_target: Dictionary = GameData.targets()[0]
	for t in GameData.targets():
		if (t["intro"] + t["name"]).length() > (longest_target["intro"] + longest_target["name"]).length():
			longest_target = t
	case.target_id = longest_target["id"]
	var all_scandals: Array = GameData.scandals() + GameData.partners().map(func(t): return t["scandal"])
	var longest_scandal: Dictionary = all_scandals[0]
	for s in all_scandals:
		if (s["title"] + s["summary"] + s["status"]).length() > (longest_scandal["title"] + longest_scandal["summary"] + longest_scandal["status"]).length():
			longest_scandal = s
	case.scandal = longest_scandal
	case.reason_index = _longest_index(longest_scandal["reasons"])
	case.found_spot_index = _longest_index(longest_scandal["found_spots"])
	var longest_disguise: Dictionary = GameData.disguises()[0]
	for d in GameData.disguises():
		if d["name"].length() > longest_disguise["name"].length():
			longest_disguise = d
	case.disguise = longest_disguise
	var longest_clue := _longest_index(longest_city["clues"])
	for i in 30:
		case.notes.append({"city": longest_city["id"], "speech": {"loc": "banco", "kind": "clue", "parts": [["clue", longest_city["id"], longest_clue]]}})
	GameManager.case = case

func _finish_extreme_case() -> void:
	var case: CaseState = GameManager.case
	case.pauta = case.disguise["id"]
	case.outcome = CaseState.Outcome.WIN
	# o máximo que um caso costuma destravar de uma vez
	GameManager.last_unlocked = Achievements.all().slice(0, 3).map(func(a): return a["id"])

func _longest(values: Array) -> String:
	var best := ""
	for v in values:
		var text := str(v)
		if text.length() > best.length():
			best = text
	return best

func _longest_index(values: Array) -> int:
	var best := 0
	for i in values.size():
		if str(values[i]).length() > str(values[best]).length():
			best = i
	return best

func _longest_key(d: Dictionary) -> String:
	var best := ""
	for k in d:
		if best == "" or str(d[k]).length() > str(d[best]).length():
			best = k
	return best

## Caixa do tamanho-base da orientação atual com o controle dentro.
func _layout_box(screen: Control) -> Control:
	var box := Control.new()
	box.size = Vector2(Responsive.base_size())
	box.theme = UiTheme.theme()
	add_child(box)
	box.add_child(screen)
	await _frames(4)
	return box

func _free_box(box: Control) -> void:
	box.queue_free()
	await _frames()

func _check_fits(box: Control, what: String) -> void:
	var limit := box.get_global_rect().grow(1)
	var out := _overflowing(box, limit)
	_check(out == null, "%s cabe na tela (vazou: %s)" % [what, _describe(out, limit) if out else ""])
	if Responsive.is_portrait():
		_check_symmetry(box, what)
	# RF37: no toque, todo botão visível com pelo menos 48 px reais de altura
	if Responsive.is_touch():
		var small: Array = box.find_children("*", "Button", true, false).filter(func(b):
			return b.is_visible_in_tree() and b.size.y * Responsive.screen_per_base() < Responsive.TOUCH_TARGET_CSS - 1.0)
		_check(small.is_empty(), "%s: botões com 48 px reais (pequenos: %s)" % [what, small.map(func(b): return "%s=%dpx" % [b.text.left(16), int(b.size.y * Responsive.screen_per_base())]).slice(0, 4)])

## RF53/54 (spec 008): em pé, fileira de botões não deixa sobra de um lado
## só. Fileira = contêiner cujos filhos visíveis são todos botões; a sobra é
## medida contra o pai quando ele é uma coluna (fileira encolhida fica
## encostada num lado dela).
## (6: fileira que quebra linha divide a largura com arredondamento)
const SYMMETRY_TOLERANCE := 6.0

func _check_symmetry(box: Control, what: String) -> void:
	var lopsided: Array = []
	for row in box.find_children("*", "Container", true, false):
		if not row.is_visible_in_tree() or row is ScrollContainer:
			continue
		var kids: Array = row.get_children().filter(func(c): return c is Control and c.is_visible_in_tree())
		if kids.is_empty() or not kids.all(func(c): return c is BaseButton):
			continue
		var used := Rect2(kids[0].get_global_rect())
		for k in kids:
			used = used.merge(k.get_global_rect())
		var parent: Control = row.get_parent() as Control
		var span: Rect2 = parent.get_global_rect() if parent is VBoxContainer or parent is MarginContainer or parent is PanelContainer else row.get_global_rect()
		var left := used.position.x - span.position.x
		var right := span.end.x - used.end.x
		if absf(left - right) > SYMMETRY_TOLERANCE:
			lopsided.append("%s [%s] sobra %d|%d" % [row.get_class(), str(kids[0].get("text")).left(14), int(left), int(right)])
	_check(lopsided.is_empty(), "%s: botões sem sobra de um lado só (%s)" % [what, "; ".join(lopsided.slice(0, 4))])

func _describe(c: Control, limit: Rect2) -> String:
	var r := c.get_global_rect()
	var text: String = (" \"%s\"" % str(c.get("text")).left(30)) if c.get("text") != null else ""
	return "%s%s %s fora de %s" % [c.get_class(), text, r, limit]

## Primeiro controle visível que passa da área. Não desce em rolagem nem em
## controle que recorta o conteúdo (lá dentro, passar da borda é normal).
func _overflowing(node: Node, limit: Rect2) -> Control:
	for child in node.get_children():
		if not (child is Control and child.is_visible_in_tree()):
			continue
		var inner: Control = null
		if not (child is ScrollContainer or child.clip_contents):
			inner = _overflowing(child, limit)
		if inner:
			return inner  # o mais fundo que vaza é o culpado
		if not limit.encloses(child.get_global_rect()):
			return child
	return null

## U4: girar o aparelho no meio de cada coisa. O caso não muda, nenhuma
## ação duplica, e a tela remontada continua jogável.
func _test_rotation() -> void:
	Responsive.forced = 0
	GameManager.settings.text_speed = "instantanea"
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	GameManager.case = CaseGenerator.generate(rng, {"route_len": 4})
	var case: CaseState = GameManager.case
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await _wait(0.5)
	GameManager.go_to_city()
	await _settle(main)

	var steps := [
		["fala aberta", func(city): city._on_location_chosen(case.locations_here()[0])],
		["dossiê aberto", func(city): city._open_dossier()],
		["anotações abertas", func(city): city._open_notes()],
		["pausa aberta", func(city): city._open_pause()],
	]
	var orientation := 1
	for s in steps:
		var acted := case.actions.size()
		var errors_before := _log.errors.size()
		s[1].call(main._current)
		await _frames(3)
		acted = case.actions.size()
		await _rotate(main, orientation)
		orientation = 1 - orientation
		_check(main._current_name == "city" and case.actions.size() == acted, "girar com %s mantém o caso" % s[0])
		_check(_usable(main), "girar com %s: tela continua jogável" % s[0])
		_check(_log.errors.size() == errors_before, "girar com %s sem erro" % s[0])

	# no meio do voo: ou o voo some (sem ação) ou chega (uma ação), nunca dois
	GameManager.open_travel()
	await _settle(main)
	var acted_before := case.actions.size()
	var dest := _button_starting(main._current, GameData.city(case.travel_options()[0])["name"].to_upper())
	_click(dest)
	await _wait(0.3)
	await _rotate(main, orientation)
	orientation = 1 - orientation
	await _wait(WorldMapView.FLIGHT_SECONDS + 0.5)
	await _settle(main)
	_check(case.actions.size() - acted_before <= 1, "girar no meio do voo não duplica viagem")
	_check(_usable(main), "girar no meio do voo: tela continua jogável")

	# última fala (o caso já acabou): girar não pode prender na cidade
	if main._current_name != "city":
		GameManager.go_to_city()
		await _settle(main)
	case.set_pauta(case.disguise["id"])
	while not case.is_final_stop():
		case.travel(case.route[case.stop_index + 1])
	GameManager.go_to_city()
	await _settle(main)
	main._current._on_location_chosen(case.locations_here()[case.hideout_slot])
	await _frames(3)
	_check(case.is_over(), "achou o senador")
	await _rotate(main, orientation)
	for i in 5:
		if main._current_name == "ending":
			break
		var cont := _find_button(main._current, "CONTINUAR >")
		if cont:
			_click(cont)
		await _settle(main)
	_check(main._current_name == "ending", "girar na última fala ainda leva à capa (ficou em %s)" % main._current_name)

	main.queue_free()
	await _frames(3)
	Responsive.forced = -1
	get_window().content_scale_size = Responsive.LANDSCAPE_SIZE

func _rotate(main: Control, orientation: int) -> void:
	Responsive.forced = orientation
	main._on_window_resized()
	await _settle(main)

## Algum botão visível e habilitado pra apertar.
func _usable(main: Control) -> bool:
	return main.find_children("*", "BaseButton", true, false).any(func(b): return b.is_visible_in_tree() and not b.disabled)

## --- Spec 007 (T67): partida inteira por clique + salvar e continuar ---------------------

## U1 + U7: do título à capa só apertando botões (sabendo a resposta), nas
## duas orientações; no meio, SALVAR E SAIR e CONTINUAR CASO restauram tudo.
func _test_full_game_by_click() -> void:
	for orientation in [0, 1]:
		var tag := "em pé" if orientation == 1 else "deitado"
		Responsive.forced = orientation
		SaveService.clear_case()
		GameManager.settings = Settings.new()
		GameManager.settings.tips_enabled = false
		GameManager.settings.text_speed = "instantanea"
		GameManager.settings.ranking = "no"
		GameManager.settings.language = "es" if orientation == 1 else "pt"
		Lang.apply(GameManager.settings.language)
		tag += " [%s]" % Lang.current
		GameManager.career = Career.from_dict({"player_name": "Clique", "cases_solved": 0, "cases_played": 0})
		var main: Control = load("res://scenes/Main.tscn").instantiate()
		add_child(main)
		await _wait(0.5)
		var errors_before := _log.errors.size()
		var ok := await _play_by_click(main, tag)
		_check(ok, "partida por clique até a capa (%s)" % tag)
		_check(_log.errors.size() == errors_before, "partida por clique sem erro do motor (%s)" % tag)
		main.queue_free()
		await _frames(3)
	Responsive.forced = -1
	get_window().content_scale_size = Responsive.LANDSCAPE_SIZE
	GameManager.career = Career.from_dict({"player_name": "Teste", "cases_solved": 1, "cases_played": 2})
	GameManager.settings = Settings.new()
	GameManager.settings.tips_enabled = false

## Joga um caso inteiro. Cada passo que não acha o botão esperado falha com o
## nome do passo e a tela em que estava.
func _play_by_click(main: Control, tag: String) -> bool:
	if not await _step(main, "NOVO CASO", "briefing", tag):
		return false
	var case: CaseState = GameManager.case
	# botão montado já traduzido ("EMBARCAR PARA %s")
	if not await _step(main, Lang.t("EMBARCAR PARA %s").replace("%s", ""), "city", tag):
		return false
	var saved_once := false
	while true:
		# investiga os 3 locais (no último, só o esconderijo)
		var locs: Array = [case.locations_here()[case.hideout_slot]] if case.is_final_stop() else case.locations_here()
		for loc in locs:
			if not await _step(main, "INVESTIGAR", "city", tag):
				return false
			if not await _step(main, GameData.location_info(loc)["name"].to_upper(), "city", tag):
				return false
			while _find_button(main._current, "CONTINUAR >") != null and main._current_name == "city":
				_click(_find_button(main._current, "CONTINUAR >"))
				await _settle(main)
			if case.is_over():
				break
			if not await _step(main, "VOLTAR", "city", tag):
				return false
		if case.is_over():
			break
		if case.pauta == "" and not await _issue_pauta_by_click(main, case, tag):
			return false
		if not saved_once and case.stop_index == 1:
			saved_once = true
			if not await _save_and_continue(main, case, tag):
				return false
			case = GameManager.case
		if not await _step(main, "VIAJAR", "travel", tag):
			return false
		# _settle espera o voo inteiro
		if not await _step(main, GameData.city(case.route[case.stop_index + 1])["name"].to_upper(), "city", tag):
			return false
	await _settle(main)
	_check(main._current_name == "ending" and case.outcome == CaseState.Outcome.WIN, "capa de vitória (%s): tela %s, desfecho %d" % [tag, main._current_name, case.outcome])
	_check(saved_once, "salvar e continuar foi exercitado (%s)" % tag)
	return await _step(main, "NOVO CASO", "briefing", tag)

## Aperta o botão cujo texto começa com `prefix` e espera chegar em `screen`.
func _step(main: Control, prefix: String, screen: String, tag: String) -> bool:
	var b: Button = null
	for c in main._current.find_children("*", "Button", true, false):
		if c.is_visible_in_tree() and not c.disabled and c.text.begins_with(prefix):
			b = c
			break
	if b == null:
		_check(false, "botão '%s' na tela %s (%s)" % [prefix, main._current_name, tag])
		return false
	_click(b)
	await _settle(main)
	if screen == "travel" or main._current_name == screen or main._current_name == "ending":
		return true
	_check(false, "'%s' devia levar a %s, foi pra %s (%s)" % [prefix, screen, main._current_name, tag])
	return false

func _issue_pauta_by_click(main: Control, case: CaseState, tag: String) -> bool:
	if not await _step(main, "DOSSIÊ", "city", tag):
		return false
	for t in GameData.trait_order():
		var label: String = GameData.trait_value_info(t, case.disguise[t])["label"]
		if not await _step(main, label, "city", tag):
			return false
	if not await _step(main, "EMITIR PAUTA", "city", tag):
		return false
	_check(case.pauta == case.disguise["id"], "pauta emitida por clique (%s)" % tag)
	return await _step(main, "FECHAR", "city", tag)

## U7: pausa → SALVAR E SAIR → título → CONTINUAR CASO devolve o mesmo caso.
func _save_and_continue(main: Control, case: CaseState, tag: String) -> bool:
	var before := {"city": case.current_city, "hours": case.clock.hours, "pauta": case.pauta, "dossier": case.dossier.duplicate(),
		"notes": case.notes.size(), "actions": case.actions.size(), "stop": case.stop_index}
	if not await _step(main, "MENU", "city", tag):
		return false
	if not await _step(main, "SALVAR E SAIR", "title", tag):
		return false
	if not await _step(main, "CONTINUAR CASO", "city", tag):
		return false
	var back: CaseState = GameManager.case
	var after := {"city": back.current_city, "hours": back.clock.hours, "pauta": back.pauta, "dossier": back.dossier.duplicate(),
		"notes": back.notes.size(), "actions": back.actions.size(), "stop": back.stop_index}
	_check(after == before, "CONTINUAR CASO restaura o caso (%s): %s → %s" % [tag, before, after])
	return after == before

## --- Spec 007 (T66): entradas hostis na interface ------------------------------------------

## E1 na tela: nome hostil no título e na manchete da capa — nada vaza e o
## nome entra literal (um "{city}" no nome não vira o nome da cidade).
func _test_hostile_inputs() -> void:
	var names := ["W".repeat(Career.MAX_NAME_LENGTH), "{city}", "Ana\nFuro", "[b]Ana[/b]", "%s %d"]
	for raw in names:
		GameManager.career = Career.from_dict({"player_name": raw, "cases_solved": 2, "cases_played": 3})
		var shown: String = raw.c_escape()
		var title := await _layout_box(load("res://scenes/TitleScreen.tscn").instantiate())
		_check_fits(title, "título com nome '%s'" % shown)
		await _free_box(title)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		GameManager.case = CaseGenerator.generate(rng, {"route_len": 4})
		var case: CaseState = GameManager.case
		case.set_pauta(case.disguise["id"])
		while not case.is_final_stop():
			case.travel(case.route[case.stop_index + 1])
		case.investigate(case.locations_here()[case.hideout_slot])
		GameManager.last_unlocked = []
		var end := await _layout_box(load("res://scenes/EndScreen.tscn").instantiate())
		_check_fits(end, "capa com nome '%s'" % shown)
		var texts: Array = end.find_children("*", "Label", true, false).map(func(l): return l.text)
		var clean_name := GameManager.career.player_name
		_check(texts.any(func(t): return t.contains(clean_name)), "nome '%s' aparece literal na capa" % shown)
		await _free_box(end)
	GameManager.career = Career.from_dict({"player_name": "Teste", "cases_solved": 1, "cases_played": 2})

	# E2: caso salvo estragado nunca trava o título nem oferece CONTINUAR
	var g := RandomNumberGenerator.new()
	g.seed = 8
	var good := CaseGenerator.generate(g, {"route_len": 4})
	good.investigate(good.locations_here()[0])
	var good_json := JSON.stringify(good.to_save())
	var many: Array = []
	for i in 10000:
		many.append(["d", "hat", ""])
	var future: Dictionary = good.to_save()
	future["version"] = 99
	var bad_saves := [good_json.left(good_json.length() / 2), "\u0001\u0002binário\uFFFD", "[]", "null", "\"texto\"", "{}",
		JSON.stringify(future), JSON.stringify({"version": 2, "seed": 1, "config": good.config, "actions": many}),
		"{\"version\": 2, \"seed\": 1e400}", "x".repeat(200000)]
	for bad in bad_saves:
		SaveService._memory_case = bad
		var errors_before := _log.errors.size()
		_check(SaveService.load_case() == null and not GameManager.has_saved_case(), "save estragado recusado: %s" % bad.left(30).c_escape())
		var title: Control = await _mount(load("res://scenes/TitleScreen.tscn").instantiate())
		_check(_find_button(title, "CONTINUAR CASO") == null, "título sem CONTINUAR com save estragado: %s" % bad.left(30).c_escape())
		title.queue_free()
		await _frames()
		# erro de parse do JSON é esperado (o motor reclama); script quebrado não
		var script_errors: Array = Array(_log.errors.slice(errors_before)).filter(func(e): return not e.contains("JSON"))
		_check(script_errors.is_empty(), "save estragado sem erro de script: %s" % "; ".join(script_errors))
		_log.errors.resize(errors_before)
	SaveService._memory_case = good_json
	_check(GameManager.has_saved_case(), "save bom continua aceito")
	SaveService.clear_case()

	# E3: opções no tranco — extremos, mudo 50 vezes, rever dicas e fechar já
	var s := GameManager.settings
	var panel := OptionsPanel.new()
	await _mount(panel)
	panel.open()
	await _frames()
	for slider in panel.find_children("*", "HSlider", true, false):
		for v in [-50, 0, 100, 1e9, 37]:
			slider.value = v
	_check(s.music_volume >= 0.0 and s.music_volume <= 1.0 and s.sfx_volume >= 0.0 and s.sfx_volume <= 1.0, "volumes ficam entre 0 e 100%")
	var muted_before := s.muted
	for i in 50:
		_press(panel, "MUDO" if s.muted else "LIGADO")
	_check(s.muted == muted_before, "mudo 50 vezes volta ao estado inicial")
	_press(panel, OptionsPanel.RESET_TEXT)
	panel.queue_free()
	await _wait(OptionsPanel.RESET_FEEDBACK_SECONDS + 0.3)
	_check(true, "rever dicas e fechar na hora não quebra")

## --- Spec 007 (T70): teclado/controle ------------------------------------------------------

## U6: em cada tela e painel, Tab passa por todo botão visível e o foco nunca
## some; ESC faz o que a tela promete.
func _test_keyboard() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	GameManager.case = CaseGenerator.generate(rng, {"route_len": 4})
	GameManager.settings.text_speed = "instantanea"

	for scene in ["TitleScreen", "BriefingScreen", "CityScreen", "TravelScreen", "CareerScreen", "LeaderboardScreen"]:
		var node: Control = await _mount(load("res://scenes/%s.tscn" % scene).instantiate())
		await _frames(3)
		await _check_tab_cycle(node, scene)
		node.queue_free()
		await _frames()

	var city: Control = await _mount(load("res://scenes/CityScreen.tscn").instantiate())
	await _frames(3)
	for panel in [["Dossiê", "_open_dossier"], ["Anotações", "_open_notes"], ["Investigar", "_open_investigate"]]:
		city.call(panel[1])
		await _frames(3)
		await _check_tab_cycle(city, panel[0])
		_escape()
		await _frames(3)
		_check(not city._dossier.visible and not city._notes.visible and not city._investigate.visible, "ESC fecha %s" % panel[0])
		_check(_focus_visible(), "foco visível depois de fechar %s com ESC" % panel[0])
	_escape()
	await _frames(3)
	_check(city._pause.visible, "ESC na cidade abre a pausa")
	await _check_tab_cycle(city._pause, "Pausa")
	_escape()
	await _frames(3)
	_check(not city._pause.visible and _focus_visible(), "ESC fecha a pausa e devolve o foco")
	city.queue_free()
	await _frames()

	var expected_exit := {"TravelScreen": "city", "CareerScreen": "title", "LeaderboardScreen": "title"}
	for scene in expected_exit:
		var node: Control = await _mount(load("res://scenes/%s.tscn" % scene).instantiate())
		await _frames(3)
		_screens.clear()
		_escape()
		await _frames(2)
		_check(_screens == [expected_exit[scene]], "ESC em %s volta pra %s (%s)" % [scene, expected_exit[scene], _screens])
		node.queue_free()
		await _frames()

func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = keycode
		e.physical_keycode = keycode
		e.pressed = pressed
		get_viewport().push_input(e)

func _focus_visible() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f != null and f.is_visible_in_tree()

## Tab dá a volta: começa com foco num controle visível, passa por todos os
## botões visíveis e habilitados, e nunca cai em controle escondido.
func _check_tab_cycle(root: Control, what: String) -> void:
	var targets: Array = root.find_children("*", "BaseButton", true, false).filter(func(b):
		return b.is_visible_in_tree() and not b.disabled and b.focus_mode != Control.FOCUS_NONE)
	_check(_focus_visible(), "%s abre com foco num controle visível" % what)
	if not _focus_visible():
		targets[0].grab_focus()
	var reached := {}
	var lost := ""
	for i in targets.size() * 2 + 4:
		var f := get_viewport().gui_get_focus_owner()
		if f == null or not f.is_visible_in_tree():
			lost = str(f.get_path()) if f else "nenhum"
			break
		reached[f] = true
		_key(KEY_TAB)
		await _frames()
	_check(lost == "", "%s: Tab não perde o foco (%s)" % [what, lost])
	var missed: Array = targets.filter(func(b): return not reached.has(b)).map(func(b): return b.text if b is Button else b.get_class())
	_check(missed.is_empty(), "%s: Tab alcança todos os botões (faltou %s)" % [what, missed])

## --- Spec 008 (T82): idiomas na interface --------------------------------------------

## RF55: "cabe na tela" e simetria em cada idioma (textos em espanhol e
## inglês costumam ser mais longos).
func _test_layout_all_languages() -> void:
	for lang in Lang.SUPPORTED:
		Lang.apply(lang)
		await _test_layout_fits()
	Lang.apply("pt")

## --- Spec 011 (T102): mapa e cenário sem esticar --------------------------------------

## Perfis do "cabe na tela" + monitor 21:9 (base esticada pelo `expand`).
const ART_PROFILES := LAYOUT_PROFILES + [["21:9 deitado", 0, 720.0, 0, Vector2(1680, 720)]]

func _test_art_proportions() -> void:
	for profile in ART_PROFILES:
		Responsive.forced = profile[1]
		Responsive.forced_short_side = profile[2]
		Responsive.forced_touch = profile[3]
		UiTheme.reset_theme()
		var tag: String = profile[0]
		_extreme_case()
		var travel_box := await _layout_box(load("res://scenes/TravelScreen.tscn").instantiate())
		if profile.size() > 4:
			travel_box.size = profile[4]
			await _frames(4)
		var map: WorldMapView = travel_box.get_child(0)._map
		var ppd := map.pixels_per_degree()
		_check(absf(ppd.x - ppd.y) <= ppd.y * 0.01, "mapa com a mesma escala nos dois eixos (%s: %.2f x %.2f px/grau)" % [tag, ppd.x, ppd.y])
		var frame := Rect2(Vector2.ZERO, map.size).grow(1)
		var shown := [map.origin_id] + map.option_ids
		_check(shown.all(func(id): return frame.has_point(map._city_pos(id))), "origem e destinos dentro do mapa (%s)" % tag)
		if not Responsive.is_portrait():
			var missing: Array = GameData.cities().filter(func(c): return not map._copies(c).any(func(p): return frame.has_point(p)))
			_check(missing.is_empty(), "mundo inteiro visível deitado (%s; fora: %s)" % [tag, missing.map(func(c): return c["id"])])
		await _free_box(travel_box)

		var city_box := await _layout_box(load("res://scenes/CityScreen.tscn").instantiate())
		if profile.size() > 4:
			city_box.size = profile[4]
			await _frames(4)
		var sky: SkylineView = city_box.get_child(0)._skyline
		var k := sky.art_scale()
		var leftover := sky.size - sky.art_size() * k
		_check(k >= 1 and (k == 1 or (sky.art_size().y >= SkylineView.REF_HEIGHT and sky.art_size().x >= SkylineView.REF_WIDTH)) and leftover.x >= 0 and leftover.y >= 0 and leftover.x < k and leftover.y < k,
			"cenário em fator inteiro sem esticar (%s: %dx, arte %s, quadro %s)" % [tag, k, sky.art_size(), sky.size])
		var scene := Rect2(Vector2.ZERO, sky.art_size()).grow(0.01)
		for c in GameData.cities():
			sky.city = c
			_check(scene.encloses(sky.landmark_rect()), "marco de %s inteiro na cena (%s: %s em %s)" % [c["id"], tag, sky.landmark_rect(), sky.art_size()])
		await _free_box(city_box)
	Responsive.forced = -1
	Responsive.forced_short_side = -1.0
	Responsive.forced_touch = -1
	UiTheme.reset_theme()

	# RF75: rota que cruza a borda do mapa vai pelo caminho mais curto
	var map := WorldMapView.new()
	map.size = Vector2(1200, 460)
	map.origin_id = "santiago"
	map.option_ids = ["sydney", "toquio"]
	add_child(map)
	await _frames()
	for id in map.option_ids:
		var degrees := absf(map._city_pos(id).x - map._city_pos("santiago").x) / map.pixels_per_degree().x
		_check(degrees <= 180.0, "Santiago -> %s pelo caminho mais curto (%.0f graus)" % [id, degrees])

	# Spec 012 (RF97–99): avião em 16 direções, da origem ao destino
	_check(PlaneSprite.frames().size() == PlaneSprite.DIRECTIONS, "avião com %d direções" % PlaneSprite.DIRECTIONS)
	var wrong_dirs: Array = range(PlaneSprite.DIRECTIONS).filter(func(i):
		return PlaneSprite.index_for(Vector2.RIGHT.rotated(i * TAU / PlaneSprite.DIRECTIONS + 0.1)) != i)
	_check(wrong_dirs.is_empty(), "rumo escolhe o quadro mais próximo (erradas: %s)" % [wrong_dirs])
	map.fly_to("sydney")
	var start: Vector2 = map.plane_at(0.0)[0]
	var finish: Vector2 = map.plane_at(1.0)[0]
	_check(start.distance_to(map._city_pos("santiago")) < 1.0 and finish.distance_to(map._city_pos("sydney")) < 1.0,
		"avião sai de Santiago e pousa em Sydney (%s -> %s)" % [start, finish])
	_check(Rect2(Vector2.ZERO, map.size).grow(1).has_point(finish), "pouso dentro do mapa mesmo cruzando a borda")
	map.queue_free()
	await _frames()

## Marcas que só o português tem — texto visível com elas, com o jogo em
## inglês ou espanhol, é tradução esquecida. Nomes próprios ficam de fora.
## ("da"/"do" ficam de fora: "da" é verbo em espanhol.)
const PORTUGUESE_MARKS := "(ção|ções|ões|ã|õ|ê|\\bvocê\\b|\\bnão\\b|\\buma\\b|\\bcom\\b|\\bàs\\b|\\bao\\b)"
const PROPER_NAMES := ["são paulo", "joão", "barra da tijuca"]

func _test_no_portuguese_left() -> void:
	var marks := RegEx.create_from_string(PORTUGUESE_MARKS)
	for lang in ["en", "es"]:
		Lang.apply(lang)
		GameManager.settings.tips_enabled = false
		var found: Array = []
		var rng := RandomNumberGenerator.new()
		rng.seed = 17
		GameManager.case = CaseGenerator.generate(rng, {"route_len": 4})
		var case: CaseState = GameManager.case
		Online.mock = func(_m, path, _b):
			if path.begins_with("/leaderboard"):
				return {"ok": true, "status": 200, "data": {"entries": [
					{"position": 1, "nickname": "Repórter Anônimo", "rank_title": "Repórter", "rank": 2, "score": 900, "hours": 80, "city": "paris", "is_you": false},
				]}}
			return {"ok": true, "status": 200, "data": {"online": 7, "interval": 60}}
		await Online.heartbeat()
		Online._timer.stop()

		var title: Control = await _mount(load("res://scenes/TitleScreen.tscn").instantiate())
		_collect_portuguese(title, marks, "título", found)
		title._open_options()
		await _frames(3)
		_collect_portuguese(title, marks, "opções", found)
		title._options_overlay.visible = false
		title._open_name_dialog()
		await _frames(2)
		_collect_portuguese(title, marks, "crachá", found)
		title.queue_free()

		for scene in ["BriefingScreen", "TravelScreen", "CareerScreen", "LeaderboardScreen"]:
			var node: Control = await _mount(load("res://scenes/%s.tscn" % scene).instantiate())
			await _frames(3)
			_collect_portuguese(node, marks, scene, found)
			node.queue_free()

		var city: Control = await _mount(load("res://scenes/CityScreen.tscn").instantiate())
		_collect_portuguese(city, marks, "cidade", found)
		for loc in case.locations_here():
			city._on_location_chosen(loc)
			await _frames(2)
			_collect_portuguese(city, marks, "fala", found)
			city._back_to_actions()
		for panel in ["_open_dossier", "_open_notes", "_open_investigate", "_open_pause"]:
			city.call(panel)
			await _frames(2)
			_collect_portuguese(city, marks, panel, found)
			city._pause.close()
			city._back_to_actions()
		city.queue_free()

		var tips := TipBox.new()
		await _mount(tips)
		GameManager.settings.tips_enabled = true
		GameManager.settings.seen_tips.clear()
		for tip_id in GameData.flavor()["tips"]:
			tips.try_show(tip_id)
			_collect_portuguese(tips, marks, "dica " + tip_id, found)
		GameManager.settings.tips_enabled = false
		tips.queue_free()

		case.set_pauta(case.disguise["id"])
		while not case.is_final_stop():
			case.travel(case.route[case.stop_index + 1])
		case.investigate(case.locations_here()[case.hideout_slot])
		GameManager.last_unlocked = ["primeiro_furo", "sem_errar"]
		GameManager.settings.ranking = "ask"
		GameManager.last_online_result = {"status": "done", "published": false, "score": 500, "outcome": CaseState.Outcome.WIN}
		var end: Control = await _mount(load("res://scenes/EndScreen.tscn").instantiate())
		_collect_portuguese(end, marks, "capa", found)
		end.queue_free()
		GameManager.last_online_result = {}
		Online.mock = Callable()
		await _frames()
		for f in found.slice(0, 8):
			printerr("  [", lang, "] ", f)
		_check(found.is_empty(), "nenhum texto em português com o jogo em %s (%d achados)" % [lang, found.size()])
	Lang.apply("pt")

## Texto mostrado (com a tradução automática do Godot) de cada label/botão
## visível que tenha marca de português.
func _collect_portuguese(root: Node, marks: RegEx, where: String, found: Array) -> void:
	for node in root.find_children("*", "Control", true, false):
		# tradução automática desligada = de propósito (ex.: nomes dos idiomas)
		if not node.is_visible_in_tree() or node.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED:
			continue
		var raw = node.get("text") if (node is Label or node is Button) else node.get("placeholder_text") if node is LineEdit else null
		if raw == null or str(raw) == "":
			continue
		var shown: String = TranslationServer.translate(str(raw))
		var lower := shown.to_lower()
		for name in PROPER_NAMES:
			lower = lower.replace(name, "")
		var m := marks.search(lower)
		if m:
			found.append("%s: \"%s\" (%s)" % [where, shown.replace("\n", " ").left(70), m.get_string()])

## RF42: trocar o idioma pelas Opções remonta a tela no idioma novo e reabre
## as Opções; no meio do caso, o caso continua igual.
func _test_language_switch() -> void:
	GameManager.settings = Settings.new()
	GameManager.settings.tips_enabled = false
	GameManager.settings.text_speed = "instantanea"
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await _wait(0.5)
	main._current._open_options()
	await _frames(3)
	_click(_find_button(main._current, "ESPAÑOL"))
	await _settle(main)
	await _frames(3)
	_check(Lang.current == "es" and GameManager.settings.language == "es", "ESPAÑOL troca o idioma e salva a escolha")
	_check(main._current_name == "title" and main._current._options_overlay.visible, "tela remontada com as Opções reabertas")
	var art: Array = main._current.find_children("*", "TextureRect", true, false).map(func(t): return t.texture.resource_path if t.texture else "")
	_check(art.has(main._current.art_path("es", Responsive.is_portrait())), "título com a arte em espanhol")

	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	GameManager.case = CaseGenerator.generate(rng, {"route_len": 4})
	var case: CaseState = GameManager.case
	case.investigate(case.locations_here()[0])
	var actions := case.actions.size()
	GameManager.go_to_city()
	await _settle(main)
	main._current._open_pause()
	main._current._pause._open_options()
	await _frames(3)
	_click(_find_button(main._current, "ENGLISH"))
	await _settle(main)
	await _frames(3)
	_check(Lang.current == "en" and main._current_name == "city", "trocar no meio do caso fica na cidade")
	_check(GameManager.case == case and case.actions.size() == actions, "trocar o idioma não mexe no caso")
	_check(main._current._pause.visible and main._current._pause._options.visible, "pausa e Opções reabertas depois de trocar")
	main.queue_free()
	await _frames(3)
	Lang.apply("pt")
	get_window().content_scale_size = Responsive.LANDSCAPE_SIZE
	GameManager.settings = Settings.new()
	GameManager.settings.tips_enabled = false

## Álbum da carreira: nome embaixo de cada figura flagrada, "???" nas outras,
## sem depender de tooltip (não aparece no toque).
## Spec 009: caso de parceiro — briefing, cidade e capa falam dele, não do
## Flávio; carreira mostra os parceiros flagrados.
func _test_partner_case() -> void:
	for t in GameData.partners():
		var rng := RandomNumberGenerator.new()
		rng.seed = 51
		GameManager.case = CaseGenerator.generate(rng, {"route_len": 4})
		var case: CaseState = GameManager.case
		case.target_id = t["id"]
		case.scandal_id = t["scandal"]["id"]
		var briefing: Control = await _mount(load("res://scenes/BriefingScreen.tscn").instantiate())
		var texts: Array = briefing.find_children("*", "Label", true, false).map(func(l): return l.text)
		_check(texts.any(func(x): return x.contains(t["name"].to_upper())), "briefing de %s com o nome na manchete" % t["id"])
		_check(not texts.any(func(x): return x.contains("FLÁVIO BOLSONARO SOME")), "briefing de %s sem a manchete do Flávio" % t["id"])
		_check(texts.any(func(x): return x.contains(t["scandal"]["summary"])), "briefing de %s com o box do escândalo dele" % t["id"])
		briefing.queue_free()
		case.set_pauta(case.disguise["id"])
		while not case.is_final_stop():
			case.travel(case.route[case.stop_index + 1])
		var city: Control = await _mount(load("res://scenes/CityScreen.tscn").instantiate())
		city._on_location_chosen(case.locations_here()[case.hideout_slot])
		await _frames(2)
		texts = city.find_children("*", "Label", true, false).map(func(l): return l.text)
		_check(texts.any(func(x): return x.contains(t["name"] + ", ")), "achado de %s fala o nome dele" % t["id"])
		city.queue_free()
		GameManager.last_unlocked = []
		var end: Control = await _mount(load("res://scenes/EndScreen.tscn").instantiate())
		texts = end.find_children("*", "Label", true, false).map(func(l): return l.text)
		_check(texts.any(func(x): return x.contains(t["name"])), "capa de %s com o nome dele" % t["id"])
		_check(not texts.any(func(x): return x.contains("{")), "capa de %s sem marcador cru" % t["id"])
		end.queue_free()
		await _frames()
	GameManager.career = Career.from_dict({"player_name": "Teste", "cases_solved": 2, "cases_played": 3, "targets_caught": ["flavio", "marcal"]})
	var career: Control = await _mount(load("res://scenes/CareerScreen.tscn").instantiate())
	var names: Array = career.find_children("*", "Label", true, false).map(func(l): return l.text)
	_check(names.has("Pablo Marçal") and names.has("PARCEIROS FLAGRADOS"), "carreira mostra os parceiros flagrados")
	career.queue_free()
	await _frames()
	GameManager.career = Career.from_dict({"player_name": "Teste", "cases_solved": 1, "cases_played": 2})

func _test_career_album() -> void:
	GameManager.career = Career.from_dict({"player_name": "Teste", "cases_solved": 2, "cases_played": 3, "disguises_caught": ["turista", "diva"]})
	var career: Control = await _mount(load("res://scenes/CareerScreen.tscn").instantiate())
	var texts: Array = career.find_children("*", "Label", true, false).map(func(l): return l.text)
	_check(texts.has(GameData.disguise("turista")["name"]) and texts.has(GameData.disguise("diva")["name"]), "álbum mostra o nome dos disfarces flagrados")
	# álbum (2 flagrados) + galeria de parceiros (nenhum flagrado)
	_check(texts.count("???") == GameData.disguises().size() - 2 + GameData.partners().size(), "álbum mostra ??? nos que faltam")
	var tips: Array = career.find_children("*", "TextureRect", true, false).filter(func(t): return t.tooltip_text != "")
	_check(tips.is_empty(), "álbum sem tooltip")
	career.queue_free()
	await _frames()
	GameManager.career = Career.from_dict({"player_name": "Teste", "cases_solved": 1, "cases_played": 2})

## --- Spec 007 (T68): reentrada e macaco -------------------------------------------------

## Clique de mouse de verdade no centro do controle (passa pelos overlays e
## pelo mouse_filter como um toque real). Fica dentro do Godot — não manda
## tecla nem clique pra janela nenhuma do sistema.
func _click(c: Control) -> void:
	var pos := c.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	get_viewport().push_input(motion, true)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = pos
		e.pressed = pressed
		get_viewport().push_input(e, true)

func _escape() -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_ESCAPE
		e.physical_keycode = KEY_ESCAPE
		e.pressed = pressed
		get_viewport().push_input(e)

func _button_starting(root: Node, prefix: String) -> Button:
	for b in root.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and b.text.begins_with(prefix):
			return b
	return null

## U3: toque duplo e pedidos repetidos não duplicam ação.
func _test_reentrancy() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	GameManager.case = CaseGenerator.generate(rng, {"route_len": 4})
	var case: CaseState = GameManager.case

	# viagem: dois toques no destino durante a decolagem = um voo só
	var travel: Control = await _mount(load("res://scenes/TravelScreen.tscn").instantiate())
	var dest: String = case.travel_options()[0]
	var b := _button_starting(travel, GameData.city(dest)["name"].to_upper())
	_check(b != null, "botão do destino na viagem")
	if b:
		var before := case.actions.size()
		_click(b)
		await _frames()
		_click(b)
		await _wait(WorldMapView.FLIGHT_SECONDS + 0.5)
		_check(case.actions.size() == before + 1, "toque duplo na viagem = uma ação (%d)" % (case.actions.size() - before))
	travel.queue_free()
	await _frames()

	# fala: CONTINUAR apertado várias vezes durante a digitação
	GameManager.settings.text_speed = "lenta"
	var city: Control = await _mount(load("res://scenes/CityScreen.tscn").instantiate())
	city._on_location_chosen(case.locations_here()[0])
	var acted := case.actions.size()
	for i in 4:
		var cont := _find_button(city, "CONTINUAR >")
		if cont:
			_click(cont)
		await _frames()
	_check(case.actions.size() == acted, "CONTINUAR repetido não gera ação")
	GameManager.settings.text_speed = "instantanea"
	city.queue_free()
	await _frames()

	# NOVO CASO duas vezes com o servidor lento = um caso só
	var starts := [0]
	Online.mock = func(_m, path, _body):
		await get_tree().create_timer(0.3).timeout
		if path == "/runs/start":
			starts[0] += 1
		return {"ok": false, "status": 503, "data": null}
	_screens.clear()
	GameManager.start_new_case()
	GameManager.start_new_case()
	await _wait(0.8)
	_check(starts[0] == 1 and _screens.count("briefing") == 1, "NOVO CASO repetido abre um caso só (%d pedidos, %d telas)" % [starts[0], _screens.count("briefing")])
	Online.mock = Callable()

## U2: cliques aleatórios em botões reais da árvore inteira (Main troca as
## telas), nas 3 orientações. A cada passo: sem erro do motor, tela atual
## válida, no máximo um overlay aberto, foco nunca num controle escondido.
const MONKEY_STEPS := 400
const MONKEY_SKIP := ["SAIR", "SIM (F11)", "NÃO (F11)"]
## Saídas do caso: evitadas na maioria das vezes, senão o macaco quase nunca
## chega ao fim de um caso.
const MONKEY_EXITS := ["ABANDONAR CASO", "SALVAR E SAIR", "DESISTIR"]

func _test_monkey() -> void:
	for run in [[101, 0], [202, 1], [303, -1]]:
		Responsive.forced = run[1]
		SaveService.clear_case()
		GameManager.settings = Settings.new()
		GameManager.settings.text_speed = "instantanea"
		GameManager.settings.language = {101: "pt", 202: "en", 303: "es"}[run[0]]
		Lang.apply(GameManager.settings.language)
		GameManager.career = Career.from_dict({"player_name": "Macaco", "cases_solved": run[0] % 7, "cases_played": 9})
		var main: Control = load("res://scenes/Main.tscn").instantiate()
		add_child(main)
		await _wait(0.5)
		var r := RandomNumberGenerator.new()
		r.seed = run[0]
		var trail: Array = []
		var problem := ""
		var step := 0
		var visited := {}
		while step < MONKEY_STEPS and problem == "":
			var errors_before := _log.errors.size()
			trail.append(await _monkey_step(main, r))
			if trail.size() > 6:
				trail.pop_front()
			await _settle(main)
			problem = _monkey_problem(main)
			visited[main._current_name] = true
			if _log.errors.size() > errors_before:
				problem = "erro do motor: " + _log.errors[errors_before]
			step += 1
		print("macaco %d: %d passos, telas %s" % [run[0], step, visited.keys()])
		_check(visited.has("city") and visited.has("travel"), "macaco %d chegou na cidade e na viagem" % run[0])
		_check(problem == "", "macaco (semente %d, orientação %d) passo %d: %s — últimos: %s" % [run[0], run[1], step - 1, problem, " > ".join(trail)])
		main.queue_free()
		await _frames(3)
	Responsive.forced = -1
	get_window().content_scale_size = Responsive.LANDSCAPE_SIZE
	GameManager.career = Career.from_dict({"player_name": "Teste", "cases_solved": 1, "cases_played": 2})
	GameManager.settings = Settings.new()
	GameManager.settings.tips_enabled = false

func _monkey_step(main: Control, r: RandomNumberGenerator) -> String:
	if r.randi_range(0, 9) == 0:
		_escape()
		return "ESC@" + main._current_name
	var candidates: Array = main.find_children("*", "BaseButton", true, false).filter(func(b):
		return b.is_visible_in_tree() and not b.disabled and not MONKEY_SKIP.has(b.text))
	if r.randi_range(0, 9) > 0:
		candidates = candidates.filter(func(b): return not MONKEY_EXITS.has(b.text))
	if candidates.is_empty():
		await _wait(0.3)
		return "(esperou)"
	var b: BaseButton = candidates[r.randi_range(0, candidates.size() - 1)]
	var label: String = b.text.replace("\n", " ") if b is Button else b.get_class()
	_click(b)
	return "%s@%s" % [label, main._current_name]

## Espera a troca de tela (fade) e o voo terminarem.
func _settle(main: Control) -> void:
	await _frames(3)
	var waited := 0.0
	while (main._switching or _flying(main)) and waited < 4.0:
		await _wait(0.1)
		waited += 0.1

func _flying(main: Control) -> bool:
	return is_instance_valid(main._current) and main._current_name == "travel" and main._current._target != ""

func _monkey_problem(main: Control) -> String:
	if not is_instance_valid(main._current) or not main._current.is_inside_tree():
		return "sem tela atual"
	var overlays: Array = main.find_children("*", "Overlay", true, false).filter(func(o): return o.is_visible_in_tree())
	if overlays.size() > 1:
		return "%d overlays abertos" % overlays.size()
	var focus := get_viewport().gui_get_focus_owner()
	if focus and not focus.is_visible_in_tree():
		return "foco em controle escondido: %s" % focus.get_path()
	if main._current_name in ["city", "travel", "briefing"]:
		# caso encerrado na cidade só enquanto a última fala está na tela
		var speaking: bool = main._current_name == "city" and main._current._witness.visible
		if GameManager.case == null or (GameManager.case.is_over() and not speaking):
			return "tela %s sem caso em andamento" % main._current_name
	return ""

## --- Online (respostas do servidor simuladas) ------------------------------------------

func _test_online() -> void:
	var calls: Array = []
	var server := {"seed": 4242, "outcome": CaseState.Outcome.WIN, "fail": false}
	Online.mock = func(method: int, path: String, body: Dictionary) -> Dictionary:
		calls.append(path)
		if server["fail"]:
			return {"ok": false, "status": 0, "data": null}
		if path == "/runs/start":
			return {"ok": true, "status": 200, "data": {"run_id": "e".repeat(32), "seed": server["seed"], "config": CaseGenerator.config_for_rank(GameData.flavor()["ranks"][body["rank"]])}}
		if path == "/runs/finish":
			return {"ok": true, "status": 200, "data": {"outcome": server["outcome"], "score": 777, "published": body["publish"], "position": 3 if body["publish"] else null}}
		if path == "/runs/publish":
			return {"ok": true, "status": 200, "data": {"published": true, "position": 5}}
		if path.begins_with("/leaderboard"):
			return {"ok": true, "status": 200, "data": {"period": "week", "entries": [
				{"position": 1, "nickname": "Bia", "rank_title": "Repórter", "score": 900, "hours": 80, "city": "paris", "is_you": false},
				{"position": 2, "nickname": "Teste", "rank_title": "Estagiário(a)", "score": 777, "hours": 90, "city": "rio", "is_you": true},
			]}}
		return {"ok": false, "status": 404, "data": null}

	# caso novo usa a semente do servidor
	GameManager.settings.ranking = "ask"
	await GameManager.start_new_case()
	_check(GameManager.case.case_seed == 4242 and GameManager.case.run_id == "e".repeat(32), "caso novo usa semente e run do servidor")
	# sem servidor: caso local, fora do ranking
	server["fail"] = true
	await GameManager.start_new_case()
	_check(GameManager.case.run_id == "" and GameManager.case.case_seed != 4242, "sem servidor o caso é local")
	server["fail"] = false
	# ranking "no": nem pede semente
	GameManager.settings.ranking = "no"
	calls.clear()
	await GameManager.start_new_case()
	_check(not calls.has("/runs/start") and GameManager.case.run_id == "", "ranking desligado não fala com o servidor")

	# vitória com "ask": registra sem publicar, pergunta, publica ao aceitar
	GameManager.settings.ranking = "ask"
	await GameManager.start_new_case()
	var case: CaseState = GameManager.case
	case.set_pauta(case.disguise["id"])
	while not case.is_final_stop():
		case.travel(case.route[case.stop_index + 1])
	case.investigate(case.locations_here()[case.hideout_slot])
	GameManager.finish_case()
	await _frames(3)
	_check(GameManager.last_online_result.get("status") == "done" and GameManager.last_online_result.get("published") == false, "com 'ask' o caso é conferido mas não publicado")
	var end: Control = load("res://scenes/EndScreen.tscn").instantiate()
	await _mount(end)
	_check(_find_button(end, "SIM, QUERO") != null, "primeira vitória pergunta sobre o ranking")
	_press(end, "SIM, QUERO")
	await _frames(3)
	_check(GameManager.settings.ranking == "yes", "aceitar liga o ranking")
	_check(calls.has("/runs/publish") and GameManager.last_online_result.get("position") == 5, "aceitar publica o caso")
	var texts: Array = end.find_children("*", "Label", true, false).map(func(l): return l.text)
	_check(texts.any(func(t): return t.begins_with("RANKING: 777 pontos")), "capa mostra pontos e posição")
	end.queue_free()
	await _frames()

	# servidor discorda do desfecho -> aviso de divergência, sem quebrar
	server["outcome"] = CaseState.Outcome.TIMEOUT
	await GameManager.start_new_case()
	case = GameManager.case
	case.set_pauta(case.disguise["id"])
	while not case.is_final_stop():
		case.travel(case.route[case.stop_index + 1])
	case.investigate(case.locations_here()[case.hideout_slot])
	GameManager.finish_case()
	await _frames(3)
	_check(GameManager.last_online_result.get("status") == "mismatch", "divergência de desfecho é sinalizada")
	server["outcome"] = CaseState.Outcome.WIN

	# tela de ranking
	var board: Control = load("res://scenes/LeaderboardScreen.tscn").instantiate()
	await _mount(board)
	await _frames(3)
	texts = board.find_children("*", "Label", true, false).map(func(l): return l.text)
	_check(texts.has("Bia") and texts.has("Teste (você)"), "ranking lista as entradas e marca você")
	var board_path: String = calls.filter(func(p): return p.begins_with("/leaderboard")).back()
	_check(board_path.contains("you=" + Online.device_hash()) and not board_path.contains(Online.device_id), "ranking manda só o hash do aparelho na URL (spec 010)")
	board.queue_free()
	server["fail"] = true
	board = load("res://scenes/LeaderboardScreen.tscn").instantiate()
	await _mount(board)
	await _frames(3)
	texts = board.find_children("*", "Label", true, false).map(func(l): return l.text)
	_check(texts.any(func(t): return t.begins_with("Ranking indisponível")), "ranking fora do ar mostra aviso")
	board.queue_free()

	# contador + freio do plano grátis (intervalo do servidor, recuo em falha)
	server["fail"] = false
	Online.mock = func(m, p, b): return {"ok": true, "status": 200, "data": {"online": 12, "interval": 300}}
	await Online.heartbeat()
	_check(Online.online_count == 12 and OnlineBadge.text_for(12).contains("12 repórteres"), "contador de online atualiza")
	_check(is_equal_approx(Online._timer.wait_time, 300.0), "próximo sinal no intervalo pedido pelo servidor")
	Online.mock = func(m, p, b): return {"ok": false, "status": 503, "data": null}
	await Online.heartbeat()
	_check(is_equal_approx(Online._timer.wait_time, Online.BACKOFF_START) and Online.online_count == -1, "API fora: recua e esconde o contador")
	await Online.heartbeat()
	_check(is_equal_approx(Online._timer.wait_time, Online.BACKOFF_START * 2), "falhas seguidas espaçam mais")
	Online.mock = func(m, p, b): return {"ok": true, "status": 200, "data": {"online": 3, "interval": 999999}}
	await Online.heartbeat()
	_check(Online._timer.wait_time <= Online.MAX_INTERVAL, "intervalo absurdo do servidor é limitado")
	Online._timer.stop()
	Online.mock = Callable()
	GameManager.settings.ranking = "ask"
