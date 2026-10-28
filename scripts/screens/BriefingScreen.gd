extends Control
## Briefing do caso (US3) em forma de edição extra do jornal.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	AudioManager.play_music("tension")
	var case := GameManager.case
	var career := GameManager.career
	var start := case.start_city()

	var page := NewspaperPage.new()
	add_child(page)
	page.set_texts(
		Lang.t("EDIÇÃO EXTRA · %s · Caso nº %03d") % [case.clock.time_text(), career.cases_played + 1],
		Lang.t("URGENTE: %s SOME DO MAPA") % case.target["name"].to_upper())

	page.add_paragraph(Lang.t("%s, %s — %s %s. Ele foi visto pela última vez em %s.") % [
		start["name"].to_upper(), start["country"], case.target["intro"], case.reason, start["name"]])
	var scandal := case.scandal
	page.add_fact_box(Lang.t("ENTENDA O CASO: %s") % scandal["title"].to_upper(), scandal["summary"], scandal["status"], scandal["outlet"])
	var mission := page.add_paragraph(Lang.t("SUA PAUTA, %s %s: siga a trilha, descubra o disfarce (cabeça, transporte, passatempo, lanche), emita a PAUTA no Dossiê e encontre-o até %s, para fazer só uma perguntinha sobre %s.") % [
		career.rank()["title"].to_upper(), career.player_name.to_upper(), case.clock.deadline_text().to_upper(), Lang.lower_first(scandal["title"])], 26)
	mission.add_theme_color_override("font_color", Palette.RED)

	page.add_photo(PixelPortrait.target(case.target_id), "PROCURADO PARA ENTREVISTA")
	var stamp := UiTheme.stamp("URGENTE", 22)
	page.photo_column.add_child(stamp)

	var back := UiTheme.button("DESISTIR", Vector2(180, 60))
	back.pressed.connect(func(): GameManager.go_to_title(true))
	var go := UiTheme.button(Lang.t("EMBARCAR PARA %s") % start["name"].to_upper(), Vector2(0, 60))
	go.pressed.connect(func():
		GameManager.arrival_messages = [Lang.t("Você desembarca em %s. Hora de trabalhar.") % start["name"]]
		GameManager.go_to_city())
	page.actions.add_child(back)
	page.actions.add_child(go)
	go.call_deferred("grab_focus")

	var tips := TipBox.new()
	tips.closed.connect(func(): go.grab_focus())
	add_child(tips)
	tips.try_show("briefing")
