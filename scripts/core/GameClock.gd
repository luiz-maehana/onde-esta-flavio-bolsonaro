class_name GameClock
extends RefCounted
## Relógio do caso (RF02): horas inteiras contadas desde segunda 00:00.
## Começa segunda 09:00, prazo domingo 17:00. Ação que termina depois das
## 23:00 (ou de madrugada) empurra o relógio pras 07:00 — o repórter dormiu.

const START_HOUR := 9
const DEADLINE := 6 * 24 + 17
const SLEEP_HOUR := 23
const WAKE_HOUR := 7
const DAY_NAMES := ["Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado", "Domingo"]

var hours := START_HOUR

## Avança `amount` horas. Retorna true se o repórter teve que dormir.
func advance(amount: int) -> bool:
	hours += amount
	var hour_of_day := hours % 24
	if hour_of_day >= SLEEP_HOUR:
		hours = (hours / 24 + 1) * 24 + WAKE_HOUR
		return true
	if hour_of_day < WAKE_HOUR:
		hours = (hours / 24) * 24 + WAKE_HOUR
		return true
	return false

func is_expired() -> bool:
	return hours > DEADLINE

func hours_left() -> int:
	return maxi(0, DEADLINE - hours)

func hour_of_day() -> int:
	return hours % 24

func day_name() -> String:
	return DAY_NAMES[clampi(hours / 24, 0, DAY_NAMES.size() - 1)]

func time_text() -> String:
	return "%s %02d:00" % [day_name(), hour_of_day()]

## 0..1 do quanto do prazo já foi consumido (barra do HUD).
func progress() -> float:
	return clampf(float(hours - START_HOUR) / float(DEADLINE - START_HOUR), 0.0, 1.0)
