class_name SkylineView
extends Control
## Paisagem da cidade atual: céu pela hora do relógio, sol/lua, duas camadas
## de prédios com semente fixa por cidade (a mesma cidade sempre tem o mesmo
## perfil) e o marco da cidade no meio (SkylineLandmarks).

const PIXEL := 4.0

var city: Dictionary = {}:
	set(value):
		city = value
		queue_redraw()
var hour := 12:
	set(value):
		hour = value
		queue_redraw()

func _ready() -> void:
	clip_contents = true
	resized.connect(queue_redraw)

func _draw() -> void:
	if city.is_empty():
		return
	var w := size.x
	var h := size.y
	var ground := h - 28.0
	var night := hour >= 19 or hour < 6
	var palette: Array = city.get("palette", ["#88AACC", "#CCCCCC", "#C8102E"])
	var building := Color(palette[1])
	var accent := Color(palette[2])

	_draw_sky(w, h, Color(palette[0]))
	_draw_celestial(w, ground, night)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(city["id"])
	var far := building.darkened(0.45 if night else 0.25).lerp(_sky_colors()[0], 0.35)
	_draw_buildings(rng, w, ground, far, 0.55, false)
	SkylineLandmarks.draw(self, city["landmark"], w * 0.5, ground, h / 150.0, building.darkened(0.55 if night else 0.15), accent)
	_draw_buildings(rng, w, ground, building.darkened(0.6 if night else 0.3), 0.32, night)

	draw_rect(Rect2(0, ground, w, h - ground), accent.darkened(0.55))
	draw_rect(Rect2(0, ground, w, 4), accent)

## Topo/base do gradiente do céu por faixa de horário.
func _sky_colors() -> Array:
	var day: Color = Color(city.get("palette", ["#88AACC"])[0])
	if hour >= 20 or hour < 5:
		return [Color("#0B1026"), Color("#2B2F5A")]
	if hour < 8:
		return [Color("#5B6EAE"), Color("#F4A261")]
	if hour >= 17:
		return [Color("#6A4C93"), Color("#FF7E5F")]
	return [day.darkened(0.15), day.lightened(0.45)]

func _draw_sky(w: float, h: float, _day: Color) -> void:
	var colors := _sky_colors()
	var bands := 12
	for i in bands:
		var t := float(i) / float(bands - 1)
		var y := floorf(h * i / bands / PIXEL) * PIXEL
		draw_rect(Rect2(0, y, w, h / bands + PIXEL), colors[0].lerp(colors[1], t))

## Sol (dia) ou lua (noite) fazendo um arco conforme a hora.
func _draw_celestial(w: float, ground: float, night: bool) -> void:
	var t: float
	if night:
		t = fposmod(hour - 19, 24) / 11.0
	else:
		t = (hour - 6) / 13.0
	var x := w * (0.1 + 0.8 * t)
	var y := ground - sin(t * PI) * ground * 0.75 - 20
	if night:
		draw_circle(Vector2(x, y), 18, Color("#F5F3CE"))
		draw_circle(Vector2(x + 8, y - 5), 15, _sky_colors()[0].lerp(_sky_colors()[1], y / ground))
		var star_rng := RandomNumberGenerator.new()
		star_rng.seed = 7
		for i in 40:
			draw_rect(Rect2(star_rng.randf() * w, star_rng.randf() * ground * 0.6, 2, 2), Color(1, 1, 1, 0.7))
	else:
		draw_circle(Vector2(x, y), 22, Color("#FFE66D"))

func _draw_buildings(rng: RandomNumberGenerator, w: float, ground: float, col: Color, max_ratio: float, lit: bool) -> void:
	var x := -10.0
	var gap_center := w * 0.5
	while x < w:
		var bw := snappedf(rng.randf_range(40, 110), PIXEL)
		var bh := snappedf(rng.randf_range(0.12, max_ratio) * ground, PIXEL)
		# Abre espaço no meio pro marco não ficar escondido atrás de prédio.
		if absf(x + bw / 2 - gap_center) < w * 0.13:
			bh *= 0.35
		draw_rect(Rect2(x, ground - bh, bw, bh), col)
		_draw_windows(rng, Rect2(x, ground - bh, bw, bh), col, lit)
		x += bw + snappedf(rng.randf_range(0, 12), PIXEL)

func _draw_windows(rng: RandomNumberGenerator, r: Rect2, col: Color, lit: bool) -> void:
	var on := Color("#FFD166")
	var off := col.lightened(0.12)
	var y := r.position.y + 8
	while y < r.end.y - 10:
		var x := r.position.x + 8
		while x < r.end.x - 10:
			# Sorteia sempre (mesmo de dia) pra não mudar a sequência do rng —
			# senão o perfil dos prédios seguintes mudaria entre dia e noite.
			var c := on if rng.randf() < 0.45 and lit else off
			draw_rect(Rect2(x, y, PIXEL * 2, PIXEL * 2), c)
			x += 16
		y += 18
