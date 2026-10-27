extends Control
## Desfecho do caso (US9) como capa do jornal de domingo: manchete por tipo
## de final, resumo do caso, promoção de cargo e carimbo.

var _online_label: Label
var _actions: Array = []

const HEADLINE_KEYS := {
	CaseState.Outcome.WIN: "win",
	CaseState.Outcome.NO_PAUTA: "no_pauta",
	CaseState.Outcome.WRONG_PAUTA: "wrong_pauta",
	CaseState.Outcome.TIMEOUT: "timeout",
}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	AudioManager.stop_music()
	var case := GameManager.case
	var career := GameManager.career
	var won := case.outcome == CaseState.Outcome.WIN
	AudioManager.play_sfx("win" if won else "lose", -2.0)

	var city: Dictionary = case.current_city_data()
	var options: Array = GameData.flavor()["headlines"][HEADLINE_KEYS[case.outcome]].duplicate()
	if won:
		options.append_array(case.scandal["headlines_win"])
	# Nome do jogador entra por último e como texto literal: um nome como
	# "{city}" não pode ser interpretado como marcador do modelo.
	var headline: String = options[randi() % options.size()].format({
		"city": city["name"], "spot": case.found_spot,
	}).replace("{player}", career.player_name)

	var page := NewspaperPage.new()
	add_child(page)
	page.set_texts("EDIÇÃO ESPECIAL · %s" % case.clock.time_text(), headline.to_upper())
	for p in _story(case, career, city):
		page.add_paragraph(p, 25)

	if won and Career.rank_for(career.cases_solved - 1)["title"] != career.rank()["title"]:
		var promo := page.add_paragraph("PROMOÇÃO! A redação te nomeou %s." % career.rank()["title"].to_upper(), 30)
		promo.add_theme_color_override("font_color", Palette.GREEN)
	for id in GameManager.last_unlocked:
		var info := Achievements.info(id)
		var badge := page.add_paragraph("CONQUISTA: %s — %s" % [info.get("title", id).to_upper(), info.get("description", "")], 23)
		badge.add_theme_color_override("font_color", Palette.RED_DARK)

	if case.outcome == CaseState.Outcome.TIMEOUT:
		page.add_photo(PixelPortrait.flavio_official(), "Flávio Bolsonaro — paradeiro desconhecido")
	else:
		page.add_photo_pair(
			PixelPortrait.flavio_disguised(case.disguise["id"]), "FLAGRANTE: " + case.disguise["name"],
			PixelPortrait.flavio_official(), "FOTO OFICIAL: o senador")
	page.photo_column.add_child(UiTheme.stamp("FURO!" if won else "ESCAPOU", 26, Palette.GREEN if won else Palette.RED))
	_online_label = UiTheme.body("", 22, Palette.RED_DARK)
	_online_label.custom_minimum_size.x = 320
	page.photo_column.add_child(_online_label)
	GameManager.online_result_ready.connect(_show_online)
	_show_online(GameManager.last_online_result)

	var title := UiTheme.button("VOLTAR À REDAÇÃO", Vector2(0, 60))
	title.pressed.connect(GameManager.go_to_title)
	var again := UiTheme.button("NOVO CASO", Vector2(220, 60))
	again.pressed.connect(GameManager.start_new_case)
	var career_btn := UiTheme.button("CARREIRA", Vector2(180, 60))
	career_btn.pressed.connect(GameManager.open_career)
	page.actions.add_child(career_btn)
	page.actions.add_child(title)
	page.actions.add_child(again)
	again.call_deferred("grab_focus")
	_actions = [career_btn, title, again]
	GameManager.case_starting.connect(func():
		for b in _actions:
			b.disabled = true
		again.text = "CONECTANDO...")

	if won and GameManager.settings.ranking == "ask" and not GameManager.last_online_result.is_empty():
		_ask_ranking(again)

## Linha do ranking online sob o carimbo (atualiza quando o servidor responde).
func _show_online(r: Dictionary) -> void:
	var won := int(r.get("outcome", 0)) == CaseState.Outcome.WIN
	match r.get("status", ""):
		"pending":
			_online_label.text = "Ranking: conferindo o caso no servidor..."
		"error":
			_online_label.text = "Ranking indisponível agora."
		"mismatch":
			_online_label.text = "Ranking: o resultado não conferiu no servidor."
		"done":
			if r.get("published", false) and r.get("position") != null:
				_online_label.text = "RANKING: %d pontos · %dº lugar na semana" % [int(r.get("score", 0)), int(r["position"])]
			elif won:
				_online_label.text = "Pontuação: %d (fora do ranking)" % int(r.get("score", 0))
			else:
				_online_label.text = ""
		_:
			_online_label.text = ""

## Primeiro caso vencido com o ranking ainda em "ask": pergunta uma vez.
func _ask_ranking(focus_after: Button) -> void:
	var overlay := Overlay.new()
	add_child(overlay)
	var card := UiTheme.panel()
	card.custom_minimum_size = Vector2(640, 0)
	overlay.center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)
	col.add_child(UiTheme.headline("ENTRAR NO RANKING?", 20, Palette.RED))
	col.add_child(UiTheme.body("Seus casos vencidos podem aparecer no ranking online como \"%s\". Dá pra mudar depois em Opções." % GameManager.career.player_name))
	col.add_child(UiTheme.body(OptionsPanel.RANKING_NOTE, 22, Palette.GREY))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var no := UiTheme.button("AGORA NÃO", Vector2(200, 56))
	var yes := UiTheme.button("SIM, QUERO", Vector2(200, 56))
	for pair in [[no, false], [yes, true]]:
		var b: Button = pair[0]
		var accept: bool = pair[1]
		b.pressed.connect(func():
			overlay.queue_free()
			focus_after.grab_focus()
			GameManager.answer_ranking(accept))
		row.add_child(b)
	overlay.visible = true
	yes.call_deferred("grab_focus")

func _story(case: CaseState, career: Career, city: Dictionary) -> Array:
	var lines: Array = []
	var pauta_name: String = GameData.disguise(case.pauta).get("name", "nenhuma")
	match case.outcome:
		CaseState.Outcome.WIN:
			lines.append("%s, %s — Após uma semana de perseguição, %s encontrou o senador %s, disfarçado de %s. Questionado, ele respondeu: \"Sem comentários.\" Mas a foto já estava tirada." % [
				city["name"].to_upper(), city["country"], career.player_name, case.found_spot, case.disguise["name"]])
		CaseState.Outcome.NO_PAUTA:
			lines.append("%s — O senador foi encontrado %s, mas sem pauta aprovada a redação não liberou a entrevista. Enquanto o editor ligava de volta, ele escapuliu — %s." % [
				city["name"].to_upper(), case.found_spot, case.disguise["reveal"]])
		CaseState.Outcome.WRONG_PAUTA:
			lines.append("%s — A pauta dizia \"%s\", mas o senador estava disfarçado de %s. A matéria caiu e ele aproveitou a confusão para sumir de novo." % [
				city["name"].to_upper(), pauta_name, case.disguise["name"]])
		CaseState.Outcome.TIMEOUT:
			lines.append("A edição de domingo fechou às 17h sem o furo. O último paradeiro conhecido do senador era %s. Fontes dizem que ele usava um disfarce de %s." % [
				GameData.city(case.route[case.stop_index])["name"], case.disguise["name"]])
	var visited := case.visited.size()
	lines.append("Ficha do caso: %d cidade(s) investigada(s) de %d na rota · %d anotações · pauta: %s." % [
		visited, case.route.size(), case.notes.size(), pauta_name])
	lines.append("Sobre %s, na vida real: %s" % [case.scandal["title"].to_lower(), case.scandal["status"]])
	lines.append("%s %s — %d caso(s) resolvido(s) em %d." % [
		career.rank()["title"], career.player_name, career.cases_solved, career.cases_played])
	return lines
