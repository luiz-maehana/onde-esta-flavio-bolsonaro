extends Control
## Desfecho do caso (US9) como capa do jornal de domingo: manchete por tipo
## de final, resumo do caso, promoção de cargo e carimbo.

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
		page.add_paragraph(p, 28)

	if won and Career.rank_for(career.cases_solved - 1)["title"] != career.rank()["title"]:
		var promo := page.add_paragraph("PROMOÇÃO! A redação te nomeou %s." % career.rank()["title"].to_upper(), 30)
		promo.add_theme_color_override("font_color", Palette.GREEN)

	if case.outcome == CaseState.Outcome.TIMEOUT:
		page.add_photo(PixelPortrait.flavio_official(), "Flávio Bolsonaro — paradeiro desconhecido")
	else:
		page.add_photo_pair(
			PixelPortrait.flavio_disguised(case.disguise["id"]), "FLAGRANTE: " + case.disguise["name"],
			PixelPortrait.flavio_official(), "FOTO OFICIAL: o senador")
	page.photo_column.add_child(UiTheme.stamp("FURO!" if won else "ESCAPOU", 26, Palette.GREEN if won else Palette.RED))

	var title := UiTheme.button("VOLTAR À REDAÇÃO", Vector2(0, 60))
	title.pressed.connect(GameManager.go_to_title)
	var again := UiTheme.button("NOVO CASO", Vector2(220, 60))
	again.pressed.connect(GameManager.start_new_case)
	page.actions.add_child(title)
	page.actions.add_child(again)
	again.call_deferred("grab_focus")

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
