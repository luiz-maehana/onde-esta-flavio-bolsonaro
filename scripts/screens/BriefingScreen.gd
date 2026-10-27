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
		"EDIÇÃO EXTRA · %s · Caso nº %03d" % [case.clock.time_text(), career.cases_played + 1],
		"URGENTE: FLÁVIO BOLSONARO SOME DO MAPA")

	page.add_paragraph("%s, %s — O senador Flávio \"Zero Um\" Bolsonaro %s. Ele foi visto pela última vez em %s." % [
		start["name"].to_upper(), start["country"], case.reason, start["name"]])
	var scandal := case.scandal
	page.add_fact_box("ENTENDA O CASO: " + scandal["title"].to_upper(), scandal["summary"], scandal["status"], scandal["outlet"])
	var mission := page.add_paragraph("SUA PAUTA, %s %s: siga a trilha, descubra o disfarce (cabeça, transporte, passatempo, lanche), emita a PAUTA no Dossiê e encontre-o até DOMINGO, 17h, para fazer só uma perguntinha sobre %s." % [
		career.rank()["title"].to_upper(), career.player_name.to_upper(), scandal["title"].to_lower()], 26)
	mission.add_theme_color_override("font_color", Palette.RED)

	page.add_photo(PixelPortrait.flavio(), "PROCURADO PARA ENTREVISTA")
	var stamp := UiTheme.stamp("URGENTE", 22)
	page.photo_column.add_child(stamp)

	var back := UiTheme.button("DESISTIR", Vector2(180, 60))
	back.pressed.connect(GameManager.go_to_title)
	var go := UiTheme.button("EMBARCAR PARA %s" % start["name"].to_upper(), Vector2(0, 60))
	go.pressed.connect(func():
		GameManager.arrival_messages = ["Você desembarca em %s. Hora de trabalhar." % start["name"]]
		GameManager.go_to_city())
	page.actions.add_child(back)
	page.actions.add_child(go)
	go.call_deferred("grab_focus")
