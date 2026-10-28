class_name Lang
extends RefCounted
## Idioma do jogo (spec 008): português, inglês e espanhol.
##
## Interface: o texto em português é a chave do catálogo
## `data/i18n/ui.csv` (TranslationServer). Botão/label com texto fixo é
## traduzido sozinho pelo Godot; texto montado com % passa por `t()` antes
## de formatar. Dados (cidades, falas...): GameData junta o português de
## `data/*.json` com `data/i18n/<idioma>/*.json`.

const SUPPORTED := ["pt", "en", "es"]
## Nome de cada idioma escrito nele mesmo (botões das Opções).
const NAMES := {"pt": "PORTUGUÊS", "en": "ENGLISH", "es": "ESPAÑOL"}
const LOCALES := {"pt": "pt_BR", "en": "en", "es": "es"}

const GAME_TITLE := "Onde Está Flávio Bolsonaro?"

static var current := "pt"

## Idioma da primeira vez, pelo sistema/navegador: pt e es diretos, o resto
## em inglês (decisão 1 da spec 008).
static func detect(locale: String) -> String:
	var code := locale.to_lower().left(2)
	return code if code in ["pt", "es"] else "en"

static func sanitize(value: Variant) -> String:
	return value if typeof(value) == TYPE_STRING and SUPPORTED.has(value) else ""

## Troca o idioma: catálogo da interface e dados do jogo.
static func apply(lang: String) -> void:
	current = lang if SUPPORTED.has(lang) else "pt"
	TranslationServer.set_locale(LOCALES[current])
	GameData.reload()
	Achievements.reload()
	# título da janela / aba do navegador (RF52)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title(t(GAME_TITLE))

## Texto da interface no idioma atual (pra quem formata com %).
static func t(key: String) -> String:
	return TranslationServer.translate(key)

## Título no meio da frase: só a primeira letra minúscula ("A mansão do Lago
## Sul" -> "a mansão do Lago Sul"), sem estragar nome próprio.
static func lower_first(text: String) -> String:
	return text.left(1).to_lower() + text.substr(1)

## Primeira letra maiúscula ("o coach" -> "O coach").
static func upper_first(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)
