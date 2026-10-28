class_name Responsive
extends RefCounted
## Orientação da tela (RF36): o jogo tem dois tamanhos-base — 1280x720
## deitado e 720x1280 em pé — e cada tela monta o arranjo da orientação
## atual. Main troca o tamanho-base e remonta a tela quando o aparelho gira.

const LANDSCAPE_SIZE := Vector2i(1280, 720)
const PORTRAIT_SIZE := Vector2i(720, 1280)

## Testes e prévias forçam uma orientação: -1 automático, 0 deitado, 1 em pé.
static var forced := -1

static func is_portrait() -> bool:
	if forced != -1:
		return forced == 1
	var window := DisplayServer.window_get_size()
	return window.y > window.x

static func base_size() -> Vector2i:
	return PORTRAIT_SIZE if is_portrait() else LANDSCAPE_SIZE

## --- Tamanho real na tela (RF37) ---------------------------------------------------
## O lado curto do tamanho-base é sempre 720, então quanto 1 px do jogo vale
## na tela depende só do lado curto da janela, em px de CSS (no navegador a
## janela vem em px físicos: divide pela densidade da tela).

const BASE_SHORT_SIDE := 720.0
## Alvo de toque mínimo recomendado (px de CSS / pontos).
const TOUCH_TARGET_CSS := 48.0
## Botão nunca passa disso em px do jogo, por menor que seja a tela.
const MAX_TOUCH_TARGET := 100.0
## Abaixo disso (px de tela por px do jogo) o texto cresce, até TEXT_SCALE_MAX.
const COMFORT_SCALE := 0.65
const TEXT_SCALE_MAX := 1.3

## Testes e prévias simulam um aparelho: lado curto em px de CSS (-1 = real)
## e tela de toque (-1 real, 0 não, 1 sim).
static var forced_short_side := -1.0
static var forced_touch := -1

static func short_side_css() -> float:
	if forced_short_side > 0.0:
		return forced_short_side
	var window := DisplayServer.window_get_size()
	return mini(window.x, window.y) / maxf(DisplayServer.screen_get_scale(), 1.0)

## Px de tela (CSS) por px do jogo.
static func screen_per_base() -> float:
	return short_side_css() / BASE_SHORT_SIDE

static func is_touch() -> bool:
	if forced_touch != -1:
		return forced_touch == 1
	return DisplayServer.is_touchscreen_available()

## Altura mínima de botão, em px do jogo, pra dar 48 px reais no toque.
static func touch_target() -> float:
	if not is_touch():
		return 0.0
	return clampf(TOUCH_TARGET_CSS / screen_per_base(), 0.0, MAX_TOUCH_TARGET)

## Multiplicador de fonte: 1 em tela grande, até 1,3 em celular.
static func text_scale() -> float:
	return clampf(COMFORT_SCALE / screen_per_base(), 1.0, TEXT_SCALE_MAX)

## Caixa horizontal deitado, vertical em pé — pra arranjos lado a lado que
## viram empilhados.
static func flow_box() -> BoxContainer:
	return VBoxContainer.new() if is_portrait() else HBoxContainer.new()
