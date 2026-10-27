class_name SkylineLandmarks
extends RefCounted
## Desenhos dos marcos de cada cidade (campo "landmark" de cities.json),
## feitos com primitivas num CanvasItem. Coordenadas em "unidades": x
## relativo ao centro, y crescendo pra cima a partir do chão; `u` converte
## unidade -> pixel. Um marco novo = uma função _draw_<tipo> + entrada em
## KINDS + um ramo no match de draw().

const KINDS := [
	"tower", "dome", "golden_dome", "pyramid", "pyramid_step", "statue_arms",
	"statue_torch", "wheel", "spire", "palms", "castle", "obelisk", "bridge",
	"arch", "clock", "colosseum", "burj", "pagoda", "sails", "onion", "mesa", "twin",
	"needle", "mosque", "temple", "canal",
]

static func has(kind: String) -> bool:
	return KINDS.has(kind)

static func draw(ci: CanvasItem, kind: String, center_x: float, ground_y: float, u: float, col: Color, accent: Color) -> void:
	var p := _Pen.new(ci, center_x, ground_y, u)
	match kind:
		"tower": _draw_tower(p, col, accent)
		"dome": _draw_dome(p, col, accent)
		"golden_dome": _draw_golden_dome(p, col, accent)
		"pyramid": _draw_pyramid(p, col, accent)
		"pyramid_step": _draw_pyramid_step(p, col, accent)
		"statue_arms": _draw_statue_arms(p, col, accent)
		"statue_torch": _draw_statue_torch(p, col, accent)
		"wheel": _draw_wheel(p, col, accent)
		"spire": _draw_spire(p, col, accent)
		"palms": _draw_palms(p, col, accent)
		"castle": _draw_castle(p, col, accent)
		"obelisk": _draw_obelisk(p, col, accent)
		"bridge": _draw_bridge(p, col, accent)
		"arch": _draw_arch(p, col, accent)
		"clock": _draw_clock(p, col, accent)
		"colosseum": _draw_colosseum(p, col, accent)
		"burj": _draw_burj(p, col, accent)
		"pagoda": _draw_pagoda(p, col, accent)
		"sails": _draw_sails(p, col, accent)
		"onion": _draw_onion(p, col, accent)
		"mesa": _draw_mesa(p, col, accent)
		"twin": _draw_twin(p, col, accent)
		"needle": _draw_needle(p, col, accent)
		"mosque": _draw_mosque(p, col, accent)
		"temple": _draw_temple(p, col, accent)
		"canal": _draw_canal(p, col, accent)

## Caneta com a conversão unidade -> pixel, pra cada marco escrever só as
## formas em unidades.
class _Pen:
	var ci: CanvasItem
	var cx: float
	var gy: float
	var u: float

	func _init(canvas: CanvasItem, center_x: float, ground_y: float, unit: float) -> void:
		ci = canvas
		cx = center_x
		gy = ground_y
		u = unit

	func pt(x: float, y: float) -> Vector2:
		return Vector2(cx + x * u, gy - y * u)

	func rect(x: float, y: float, w: float, h: float, c: Color) -> void:
		ci.draw_rect(Rect2(cx + x * u, gy - (y + h) * u, w * u, h * u), c)

	func poly(points: Array, c: Color) -> void:
		var pts := PackedVector2Array()
		for p in points:
			pts.append(pt(p[0], p[1]))
		ci.draw_colored_polygon(pts, c)

	func circle(x: float, y: float, r: float, c: Color) -> void:
		ci.draw_circle(pt(x, y), r * u, c)

	func line(x1: float, y1: float, x2: float, y2: float, c: Color, w: float = 1.0) -> void:
		ci.draw_line(pt(x1, y1), pt(x2, y2), c, maxf(1.0, w * u))

	func arc(x: float, y: float, r: float, from: float, to: float, c: Color, w: float = 1.0) -> void:
		ci.draw_arc(pt(x, y), r * u, from, to, 32, c, maxf(1.0, w * u))

static func _draw_tower(p: _Pen, c: Color, a: Color) -> void:
	p.poly([[-30, 0], [-21, 0], [-5, 62], [-9, 62]], c)
	p.poly([[30, 0], [21, 0], [5, 62], [9, 62]], c)
	p.poly([[-9, 60], [9, 60], [2, 100], [-2, 100]], c)
	p.rect(-24, 22, 48, 4, c)
	p.rect(-11, 58, 22, 3, c)
	p.arc(0, 0, 14, PI, TAU, c, 2)
	p.line(0, 100, 0, 110, c, 1)

static func _draw_dome(p: _Pen, c: Color, a: Color) -> void:
	p.rect(-45, 0, 90, 24, c)
	p.rect(-18, 24, 36, 12, c)
	p.circle(0, 36, 17, c)
	p.rect(-2, 52, 4, 12, c)
	for i in 9:
		p.rect(-40 + i * 10, 3, 3, 16, a.darkened(0.2))

static func _draw_golden_dome(p: _Pen, c: Color, a: Color) -> void:
	p.rect(-40, 0, 80, 10, c)
	p.rect(-28, 10, 56, 20, Color("#2F6DB5"))
	p.rect(-16, 30, 32, 8, c)
	p.circle(0, 40, 16, a)
	p.rect(-1, 55, 2, 8, a)

static func _draw_pyramid(p: _Pen, c: Color, a: Color) -> void:
	p.poly([[-75, 0], [-35, 0], [-55, 22]], c.darkened(0.15))
	p.poly([[-45, 0], [45, 0], [0, 60]], c)
	p.poly([[0, 60], [45, 0], [10, 0]], c.darkened(0.2))
	p.poly([[40, 0], [80, 0], [60, 26]], c.darkened(0.1))

static func _draw_pyramid_step(p: _Pen, c: Color, a: Color) -> void:
	for i in 5:
		var w := 90.0 - i * 16.0
		p.rect(-w / 2, i * 10, w, 10, c.darkened(i * 0.04))
	p.rect(-8, 50, 16, 8, a)

static func _draw_statue_arms(p: _Pen, c: Color, a: Color) -> void:
	p.poly([[-70, 0], [-30, 30], [-8, 44], [8, 44], [35, 25], [70, 0]], a.darkened(0.3))
	p.rect(-4, 44, 8, 26, c.lightened(0.6))
	p.rect(-20, 64, 40, 4, c.lightened(0.6))
	p.circle(0, 74, 4, c.lightened(0.6))

static func _draw_statue_torch(p: _Pen, c: Color, a: Color) -> void:
	p.rect(-14, 0, 28, 10, c)
	p.rect(-9, 10, 18, 26, c)
	p.poly([[-7, 36], [7, 36], [5, 70], [-5, 70]], a)
	p.circle(0, 74, 5, a)
	p.rect(4, 66, 3, 20, a)
	p.circle(5, 88, 3, Color("#FFB000"))
	for i in 5:
		p.line(0, 76, -6 + i * 3, 82, a, 1)

static func _draw_wheel(p: _Pen, c: Color, a: Color) -> void:
	p.arc(0, 45, 35, 0, TAU, c, 2)
	for i in 8:
		var ang := i * TAU / 8
		p.line(0, 45, cos(ang) * 35, 45 + sin(ang) * 35, c, 1)
		p.rect(cos(ang) * 35 - 3, 45 + sin(ang) * 35 - 3, 6, 6, a)
	p.line(0, 45, -18, 0, c, 2)
	p.line(0, 45, 18, 0, c, 2)

static func _draw_spire(p: _Pen, c: Color, a: Color) -> void:
	p.rect(-50, 0, 18, 70, c.darkened(0.1))
	p.line(-41, 70, -41, 95, c, 1)
	p.rect(-30, 0, 5, 22, c)
	p.rect(25, 0, 5, 22, c)
	p.rect(-34, 22, 68, 18, a)
	for i in 6:
		p.rect(-30 + i * 11, 26, 6, 10, a.darkened(0.35))

static func _draw_palms(p: _Pen, c: Color, a: Color) -> void:
	p.rect(-30, 0, 60, 40, c)
	p.rect(-30, 40, 60, 6, a)
	p.rect(-6, 46, 12, 10, c)
	for x in [-50, 48]:
		p.poly([[x - 2, 0], [x + 2, 0], [x + 4, 50], [x, 50]], Color("#6B4A2B"))
		p.poly([[x + 2, 50], [x - 18, 42], [x - 6, 54]], Color("#2E8B57"))
		p.poly([[x + 2, 50], [x + 22, 42], [x + 10, 55]], Color("#2E8B57"))
		p.poly([[x + 2, 50], [x - 4, 64], [x + 10, 62]], Color("#2E8B57"))

static func _draw_castle(p: _Pen, c: Color, a: Color) -> void:
	p.rect(-40, 0, 80, 30, c)
	p.rect(-12, 30, 24, 30, c)
	for x in [-40, -24, 16, 32]:
		p.rect(x, 30, 8, 18, c)
		p.poly([[x - 2, 48], [x + 10, 48], [x + 4, 62]], a)
	p.poly([[-14, 60], [14, 60], [0, 92]], a)
	p.rect(-6, 0, 12, 16, c.darkened(0.4))

static func _draw_obelisk(p: _Pen, c: Color, a: Color) -> void:
	p.poly([[-7, 0], [7, 0], [5, 92], [0, 100], [-5, 92]], c.lightened(0.5))
	p.rect(-1, 70, 2, 4, c.darkened(0.3))

static func _draw_bridge(p: _Pen, c: Color, a: Color) -> void:
	for x in [-50, 44]:
		p.rect(x, 0, 6, 75, a)
		p.rect(x - 1, 50, 8, 3, a.darkened(0.2))
	p.rect(-95, 20, 190, 5, a.darkened(0.15))
	p.arc(0, 104, 60, PI * 0.2, PI * 0.8, a, 1)
	p.line(-47, 75, -95, 25, a, 1)
	p.line(47, 75, 95, 25, a, 1)

static func _draw_arch(p: _Pen, c: Color, a: Color) -> void:
	p.rect(-38, 0, 24, 46, c)
	p.rect(14, 0, 24, 46, c)
	p.rect(-38, 32, 76, 14, c)
	p.arc(0, 32, 14, PI, TAU, c, 2)
	p.rect(-24, 46, 48, 10, c.darkened(0.1))
	p.rect(-10, 56, 20, 8, a)

static func _draw_clock(p: _Pen, c: Color, a: Color) -> void:
	p.rect(-60, 0, 100, 22, c)
	p.rect(14, 0, 18, 78, c)
	p.circle(23, 64, 7, Palette.PAPER)
	p.line(23, 64, 23, 69, Palette.INK, 0.6)
	p.line(23, 64, 26, 64, Palette.INK, 0.6)
	p.poly([[12, 78], [34, 78], [23, 102]], c.darkened(0.2))
	for i in 9:
		p.rect(-56 + i * 8, 22, 3, 6, c)

static func _draw_colosseum(p: _Pen, c: Color, a: Color) -> void:
	p.poly([[-55, 0], [55, 0], [55, 38], [20, 44], [-55, 48]], c)
	for row in 3:
		for i in 10:
			p.rect(-50 + i * 10, 4 + row * 13, 5, 8, c.darkened(0.35))

static func _draw_burj(p: _Pen, c: Color, a: Color) -> void:
	var widths := [26, 22, 18, 14, 10, 7, 4]
	for i in widths.size():
		var w: float = widths[i]
		p.rect(-w / 2, i * 16, w, 16, c.lightened(i * 0.03))
	p.line(0, 112, 0, 135, c, 1)

static func _draw_pagoda(p: _Pen, c: Color, a: Color) -> void:
	for i in 5:
		var w := 34.0 - i * 5.0
		var y := i * 16.0
		p.rect(-w / 2, y, w, 10, c)
		p.poly([[-w / 2 - 10, y + 10], [w / 2 + 10, y + 10], [w / 2, y + 16], [-w / 2, y + 16]], a)
	p.line(0, 80, 0, 98, a, 1.5)

static func _draw_sails(p: _Pen, c: Color, a: Color) -> void:
	p.rect(-70, 0, 140, 10, c.darkened(0.2))
	var white := Color("#F7F7F7")
	p.poly([[-55, 10], [-15, 10], [-38, 48]], white)
	p.poly([[-30, 10], [10, 10], [-10, 56]], white.darkened(0.06))
	p.poly([[0, 10], [40, 10], [18, 44]], white)
	p.poly([[25, 10], [60, 10], [42, 34]], white.darkened(0.06))

static func _draw_onion(p: _Pen, c: Color, a: Color) -> void:
	var colors := [a, Color("#1F7A4D"), Color("#2F6DB5"), Color("#E0A100"), a]
	var xs := [-40, -20, 0, 20, 40]
	var hs := [30, 42, 56, 40, 28]
	for i in 5:
		p.rect(xs[i] - 6, 0, 12, hs[i], c)
		p.circle(xs[i], hs[i] + 6, 9, colors[i])
		p.poly([[xs[i] - 4, hs[i] + 12], [xs[i] + 4, hs[i] + 12], [xs[i], hs[i] + 22]], colors[i])

static func _draw_mesa(p: _Pen, c: Color, a: Color) -> void:
	p.poly([[-110, 0], [-70, 50], [70, 50], [110, 0]], a.darkened(0.35))
	p.rect(-72, 50, 144, 6, Color(1, 1, 1, 0.85))

static func _draw_twin(p: _Pen, c: Color, a: Color) -> void:
	p.rect(-70, 0, 140, 12, c)
	p.rect(-9, 12, 8, 78, c.lightened(0.1))
	p.rect(1, 12, 8, 78, c.lightened(0.1))
	p.rect(-9, 54, 18, 4, c)
	p.arc(-45, 30, 18, 0, PI, c.lightened(0.2), 2)
	p.poly([[-63, 30], [-27, 30], [-45, 12]], c.lightened(0.2))
	p.circle(45, 14, 12, c.lightened(0.2))
	p.rect(-90, 0, 180, 3, a)

static func _draw_needle(p: _Pen, c: Color, a: Color) -> void:
	p.poly([[-6, 0], [6, 0], [2.5, 75], [-2.5, 75]], c.lightened(0.15))
	p.rect(-9, 72, 18, 7, c)
	p.rect(-6, 79, 12, 4, a)
	p.rect(-1.2, 83, 2.4, 40, c.lightened(0.1))
	p.rect(-30, 0, 14, 22, c.darkened(0.15))
	p.rect(18, 0, 16, 30, c.darkened(0.1))

static func _draw_mosque(p: _Pen, c: Color, a: Color) -> void:
	p.rect(-40, 0, 80, 18, c)
	p.circle(0, 24, 20, a.darkened(0.1))
	p.rect(-22, 18, 44, 6, c)
	p.circle(-24, 20, 8, a)
	p.circle(24, 20, 8, a)
	p.line(0, 44, 0, 52, c, 1)
	for x in [-48, 48, -36, 36]:
		p.rect(x - 2, 0, 4, 60 if absi(x) == 48 else 48, c.lightened(0.15))
		p.poly([[x - 2, 60 if absi(x) == 48 else 48], [x + 2, 60 if absi(x) == 48 else 48], [x, 70 if absi(x) == 48 else 56]], a)

static func _draw_temple(p: _Pen, c: Color, a: Color) -> void:
	p.poly([[-70, 0], [-30, 22], [30, 22], [70, 0]], c.darkened(0.35))
	p.rect(-42, 22, 84, 4, c.lightened(0.3))
	for i in 8:
		p.rect(-39 + i * 11, 26, 4, 22, c.lightened(0.35))
	p.rect(-44, 48, 88, 5, c.lightened(0.3))
	p.poly([[-44, 53], [44, 53], [0, 64]], c.lightened(0.25))

static func _draw_canal(p: _Pen, c: Color, a: Color) -> void:
	var colors := [Color("#8B4513"), Color("#A0522D"), Color("#5C3A21"), Color("#B5651D"), Color("#7A4A2A")]
	for i in 5:
		var x := -55.0 + i * 22.0
		var h := 40.0 + (i % 3) * 6.0
		p.rect(x, 8, 20, h, colors[i])
		p.poly([[x, 8 + h], [x + 20, 8 + h], [x + 10, 18 + h]], colors[i].darkened(0.2))
		for wy in [16, 28]:
			p.rect(x + 4, wy, 4, 6, Color("#F4F1EA"))
			p.rect(x + 12, wy, 4, 6, Color("#F4F1EA"))
	p.rect(-80, 0, 160, 8, Color("#2F6DB5"))
	p.rect(-30, 3, 18, 3, a)
