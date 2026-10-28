class_name SkylineLandmarks
extends RefCounted
## Marcos de cada cidade (campo "landmark" de cities.json), em pixel art
## (spec 011, RF82): um por cidade, com luz pela esquerda (tons claro, base e
## escuro), contorno automático e janelas/luzes que acendem à noite.
## Coordenadas em pixels de arte: x relativo ao centro, y crescendo pra cima
## a partir do chão; `u` reduz o desenho só quando ele não cabe na cena.
## Cada marco cabe em 126 x 84. Um marco novo = uma função _draw_<tipo> +
## entrada em KINDS + um ramo no match de _paint().

const KINDS := [
	"congress", "redeemer", "masp", "deco", "castle", "liberty", "capitol",
	"pyramid_step", "obelisk", "bridge", "alcala", "eiffel", "bigben", "colosseum",
	"parliament", "golden_dome", "burj", "pyramid", "tokyo_tower", "opera", "onion",
	"mesa", "temple_heaven", "costanera", "india_gate", "needle", "mosque", "temple",
	"brandenburg", "canal",
]

const OUTLINE := Color("#231F2B")
const LAMP := Color("#FFD166")
const WHITE := Color("#EEEBE3")
const CONCRETE := Color("#C9C3B5")
const STONE := Color("#D8CBA8")
const SANDSTONE := Color("#CDB98A")
const SAND := Color("#D9B26F")
const BRONZE := Color("#7E604A")
const VERDIGRIS := Color("#6FAE9C")
const GOLD := Color("#E2B53E")
const BRICK := Color("#A9483A")
const ROOF_RED := Color("#B04A36")
const LEAD := Color("#7F8EA0")
const GLASS := Color("#5F86AD")
const GREEN := Color("#4E7F45")
const ROCK := Color("#8C8B7A")
const RED := Color("#C23B2E")
const DARK := Color("#3A332E")

static func has(kind: String) -> bool:
	return KINDS.has(kind)

## Desenha o marco com `tone` (cor -> cor pela hora/atmosfera) e as luzes
## acesas se `night`: primeiro o contorno de tudo, depois as formas.
static func draw(ci: CanvasItem, kind: String, center_x: float, ground_y: float, u: float, tone: Callable, night: bool) -> void:
	for outline in [true, false]:
		var p := _Pen.new(ci, center_x, ground_y, u)
		p.tone = tone
		p.night = night
		p.outline = outline
		_paint(p, kind)

## Caixa do marco em unidades (x a partir do centro, y pra cima do chão):
## o mesmo desenho, com uma caneta que só mede.
static func bounds(kind: String) -> Rect2:
	var p := _Pen.new(null, 0, 0, 1)
	_paint(p, kind)
	return p.box

static func _paint(p: _Pen, kind: String) -> void:
	match kind:
		"congress": _draw_congress(p)
		"redeemer": _draw_redeemer(p)
		"masp": _draw_masp(p)
		"deco": _draw_deco(p)
		"castle": _draw_castle(p)
		"liberty": _draw_liberty(p)
		"capitol": _draw_capitol(p)
		"pyramid_step": _draw_pyramid_step(p)
		"obelisk": _draw_obelisk(p)
		"bridge": _draw_bridge(p)
		"alcala": _draw_alcala(p)
		"eiffel": _draw_eiffel(p)
		"bigben": _draw_bigben(p)
		"colosseum": _draw_colosseum(p)
		"parliament": _draw_parliament(p)
		"golden_dome": _draw_golden_dome(p)
		"burj": _draw_burj(p)
		"pyramid": _draw_pyramid(p)
		"tokyo_tower": _draw_tokyo_tower(p)
		"opera": _draw_opera(p)
		"onion": _draw_onion(p)
		"mesa": _draw_mesa(p)
		"temple_heaven": _draw_temple_heaven(p)
		"costanera": _draw_costanera(p)
		"india_gate": _draw_india_gate(p)
		"needle": _draw_needle(p)
		"mosque": _draw_mosque(p)
		"temple": _draw_temple(p)
		"brandenburg": _draw_brandenburg(p)
		"canal": _draw_canal(p)

static func _lt(c: Color) -> Color:
	return c.lightened(0.2)

static func _dk(c: Color) -> Color:
	return c.darkened(0.25)

## Caneta com a conversão unidade -> pixel. Na passada do contorno, cada
## forma sai 1 px maior na cor do contorno (detalhes finos não contam); na
## seguinte, as formas cobrem o miolo e só a silhueta fica contornada. Sem
## CanvasItem, só mede: `box` junta tudo o que seria desenhado.
class _Pen:
	var ci: CanvasItem
	var cx: float
	var gy: float
	var u: float
	var tone: Callable = func(c: Color) -> Color: return c
	var night := false
	var outline := false
	var box := Rect2()
	var _measured := false

	func _init(canvas: CanvasItem, center_x: float, ground_y: float, unit: float) -> void:
		ci = canvas
		cx = center_x
		gy = ground_y
		u = unit

	func pt(x: float, y: float) -> Vector2:
		return Vector2(cx + x * u, gy - y * u)

	func _grow(x: float, y: float) -> void:
		box = box.expand(Vector2(x, y)) if _measured else Rect2(x, y, 0, 0)
		_measured = true

	func _color(c: Color) -> Color:
		return tone.call(OUTLINE if outline else c)

	func rect(x: float, y: float, w: float, h: float, c: Color) -> void:
		if ci == null:
			_grow(x, y)
			_grow(x + w, y + h)
			return
		var r := Rect2(cx + x * u, gy - (y + h) * u, w * u, h * u)
		if outline:
			if minf(r.size.x, r.size.y) < 3.0:
				return
			r = r.grow(1)
		ci.draw_rect(r, _color(c))

	## Retângulo sem contorno (fiapos, reflexos, pingos).
	func flat(x: float, y: float, w: float, h: float, c: Color) -> void:
		if ci == null:
			rect(x, y, w, h, c)
		elif not outline:
			ci.draw_rect(Rect2(cx + x * u, gy - (y + h) * u, w * u, h * u), _color(c))

	func poly(points: Array, c: Color) -> void:
		if ci == null:
			for p in points:
				_grow(p[0], p[1])
			return
		var pts := PackedVector2Array()
		for p in points:
			pts.append(pt(p[0], p[1]))
		if not outline:
			ci.draw_colored_polygon(pts, _color(c))
			return
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var moved := PackedVector2Array()
			for v in pts:
				moved.append(v + d)
			ci.draw_colored_polygon(moved, _color(c))

	func circle(x: float, y: float, r: float, c: Color) -> void:
		if ci == null:
			_grow(x - r, y - r)
			_grow(x + r, y + r)
			return
		ci.draw_circle(pt(x, y), r * u + (1.0 if outline else 0.0), _color(c))

	func line(x1: float, y1: float, x2: float, y2: float, c: Color) -> void:
		if ci == null:
			_grow(x1, y1)
			_grow(x2, y2)
		elif not outline:
			ci.draw_line(pt(x1, y1), pt(x2, y2), _color(c), 1.0)

	## Linha passando pelos pontos [[x, y], ...] (cabos, curvas).
	func path(points: Array, c: Color) -> void:
		for i in range(1, points.size()):
			line(points[i - 1][0], points[i - 1][1], points[i][0], points[i][1], c)

	func arc(x: float, y: float, r: float, from: float, to: float, c: Color, w: float = 1.0) -> void:
		if ci == null:
			# ângulos de tela (y pra baixo): o ponto sobe com -sin
			for i in 9:
				var ang := lerpf(from, to, i / 8.0)
				_grow(x + cos(ang) * r, y - sin(ang) * r)
			return
		if outline and w * u <= 1.0:
			return
		ci.draw_arc(pt(x, y), r * u, from, to, 24, _color(c), maxf(1.0, w * u) + (2.0 if outline else 0.0))

	## Janela/luz: de dia na cor dada; à noite, uma parte (fixa) acende.
	func lamp(x: float, y: float, w: float, h: float, c: Color) -> void:
		if night and not outline and ci != null and posmod(int(x * 7 + y * 13), 10) < 6:
			ci.draw_rect(Rect2(cx + x * u, gy - (y + h) * u, w * u, h * u), LAMP)
		else:
			flat(x, y, w, h, c)

	func lamp_circle(x: float, y: float, r: float, c: Color) -> void:
		if night and not outline and ci != null:
			ci.draw_circle(pt(x, y), r * u, LAMP)
		else:
			circle(x, y, r, c)

## Brasília: Senado (cúpula), Câmara (cuia) e as torres gêmeas sobre a laje.
static func _draw_congress(p: _Pen) -> void:
	p.circle(30, 6, 9, _dk(WHITE))
	p.circle(29, 7, 8, WHITE)
	p.poly([[-44, 6], [-28, 6], [-19, 15], [-53, 15]], WHITE)
	p.poly([[-36, 6], [-28, 6], [-19, 15], [-29, 15]], _dk(WHITE))
	p.flat(-53, 14, 34, 1, _lt(WHITE))
	p.rect(-60, 0, 120, 6, CONCRETE)
	p.flat(-60, 5, 120, 1, _lt(CONCRETE))
	p.flat(-60, 0, 120, 2, _dk(CONCRETE))
	p.rect(-6, 6, 5, 52, WHITE)
	p.rect(1, 6, 5, 52, _dk(WHITE))
	p.flat(-6, 33, 12, 2, CONCRETE)
	for y in range(9, 57, 3):
		p.lamp(-5, y, 3, 1, _dk(WHITE))
		p.lamp(2, y, 3, 1, _dk(_dk(WHITE)))

## Rio: Cristo Redentor no alto do Corcovado.
static func _draw_redeemer(p: _Pen) -> void:
	p.poly([[-62, 0], [-40, 14], [-22, 30], [-10, 40], [-4, 44], [4, 44], [12, 38], [26, 24], [44, 10], [62, 0]], GREEN)
	p.poly([[4, 44], [12, 38], [26, 24], [44, 10], [62, 0], [14, 0]], _dk(GREEN))
	p.poly([[-40, 14], [-22, 30], [-10, 40], [-14, 32], [-30, 18]], _lt(GREEN))
	for r in [[-14, 30, 3, 4], [8, 32, 4, 3], [-30, 16, 3, 3], [22, 18, 3, 2]]:
		p.flat(r[0], r[1], r[2], r[3], ROCK)
	p.rect(-2, 44, 4, 4, CONCRETE)
	p.poly([[-2, 48], [2, 48], [1.5, 63], [-1.5, 63]], WHITE)
	p.poly([[0, 48], [2, 48], [1.5, 63], [0, 63]], _dk(WHITE))
	p.flat(-11, 59, 22, 2, WHITE)
	p.flat(-1, 63, 2, 3, WHITE)

## São Paulo: o MASP vermelho suspenso, o Banespa e uma torre de vidro.
static func _draw_masp(p: _Pen) -> void:
	p.rect(-40, 0, 16, 46, STONE)
	p.rect(-28, 0, 4, 46, _dk(STONE))
	p.rect(-37, 46, 10, 10, STONE)
	p.rect(-34, 56, 4, 8, STONE)
	p.line(-32, 64, -32, 74, STONE)
	for y in range(4, 44, 4):
		for x in [-38, -35, -32]:
			p.lamp(x, y, 1, 2, _dk(_dk(STONE)))
	p.rect(36, 0, 14, 54, GLASS)
	p.rect(46, 0, 4, 54, _dk(GLASS))
	for y in range(3, 52, 3):
		p.lamp(38, y, 7, 1, _lt(GLASS))
	p.rect(-6, 9, 36, 10, Color("#3D4650"))
	for x in range(-4, 30, 3):
		p.lamp(x, 11, 1, 6, Color("#5D6A78"))
	p.rect(-9, 0, 3, 22, RED)
	p.rect(30, 0, 3, 22, RED)
	p.rect(-9, 19, 42, 3, RED)
	p.flat(-9, 21, 42, 1, _lt(RED))

## Miami: hotel art déco de Ocean Drive, com neon.
static func _draw_deco(p: _Pen) -> void:
	var pink := Color("#F2B5C8")
	var teal := Color("#3FB8AF")
	var mint := Color("#A8E6CF")
	p.rect(-30, 0, 60, 27, pink)
	p.rect(25, 0, 5, 27, _dk(pink))
	for y in [8, 17, 26]:
		p.flat(-31, y, 62, 1, teal)
	for y in [2, 11, 20]:
		for x in range(-27, 25, 6):
			p.lamp(x, y, 3, 4, Color("#7FB6C9"))
	p.rect(-6, 27, 12, 9, pink)
	p.rect(-2, 36, 4, 12, WHITE)
	p.lamp(-1, 28, 2, 18, teal)
	p.circle(0, 49, 2, teal)
	p.rect(34, 0, 24, 18, mint)
	p.rect(54, 0, 4, 18, _dk(mint))
	p.flat(33, 18, 26, 1, teal)
	for x in [38, 44, 50]:
		p.lamp_circle(x, 10, 1.5, WHITE)

## Orlando: o castelo de conto de fadas.
static func _draw_castle(p: _Pen) -> void:
	var wall := Color("#F1E4EC")
	var roof := Color("#3D6BC2")
	p.rect(-42, 0, 84, 16, wall)
	p.rect(36, 0, 6, 16, _dk(wall))
	for x in range(-42, 42, 4):
		p.flat(x, 16, 2, 2, wall)
	for t in [[-36, 30, 8], [28, 30, 8], [-20, 38, 6], [14, 38, 6]]:
		p.rect(t[0], 0, t[2], t[1], wall)
		p.flat(t[0] + t[2] - 2, 0, 2, t[1], _dk(wall))
		p.poly([[t[0] - 1, t[1]], [t[0] + t[2] + 1, t[1]], [t[0] + t[2] / 2.0, t[1] + 14]], roof)
		p.lamp(t[0] + t[2] / 2.0 - 1, t[1] - 8, 2, 3, DARK)
	p.rect(-8, 0, 16, 44, wall)
	p.rect(4, 0, 4, 44, _dk(wall))
	p.poly([[-10, 44], [10, 44], [0, 68]], roof)
	p.poly([[0, 68], [10, 44], [3, 44]], _dk(roof))
	p.line(0, 68, 0, 73, GOLD)
	p.rect(-3, 0, 6, 7, DARK)
	p.circle(0, 7, 3, DARK)
	p.lamp(-2, 30, 4, 5, DARK)

## Nova York: a Estátua da Liberdade no pedestal.
static func _draw_liberty(p: _Pen) -> void:
	p.rect(-24, 0, 48, 4, _dk(STONE))
	p.rect(-10, 4, 20, 18, STONE)
	p.rect(5, 4, 5, 18, _dk(STONE))
	p.flat(-11, 20, 22, 2, _lt(STONE))
	for y in [8, 14]:
		for x in [-6, -1, 4]:
			p.lamp(x, y, 2, 3, DARK)
	p.poly([[-5, 22], [5, 22], [3, 42], [-3, 42]], VERDIGRIS)
	p.poly([[1, 22], [5, 22], [3, 42], [1, 42]], _dk(VERDIGRIS))
	p.rect(-2, 42, 4, 4, VERDIGRIS)
	for dx in [-4, -2, 0, 2, 4]:
		p.line(0, 46, dx, 50 - absf(dx) / 2.0, VERDIGRIS)
	p.flat(-6, 36, 2, 16, VERDIGRIS)
	p.flat(-7, 52, 4, 2, GOLD)
	p.lamp(-6, 54, 2, 3, Color("#F2A33A"))
	p.flat(4, 29, 3, 6, _lt(VERDIGRIS))

## Washington: o Capitólio.
static func _draw_capitol(p: _Pen) -> void:
	p.circle(0, 22, 13, _dk(WHITE))
	p.circle(-2, 23, 12, WHITE)
	for x in [-8, -4, 0, 4, 8]:
		p.line(x, 22, x * 0.6, 33, _dk(WHITE))
	p.rect(-2, 35, 4, 5, WHITE)
	p.line(0, 40, 0, 43, BRONZE)
	p.rect(-15, 13, 30, 9, WHITE)
	for x in range(-13, 14, 3):
		p.flat(x, 14, 1, 7, _dk(WHITE))
	p.flat(-16, 21, 32, 1, _lt(WHITE))
	p.rect(-56, 0, 112, 13, WHITE)
	p.rect(48, 0, 8, 13, _dk(WHITE))
	for x in range(-53, 54, 4):
		p.lamp(x, 2, 1, 9, _dk(WHITE))
	p.flat(-57, 12, 114, 1, _lt(WHITE))
	p.poly([[-13, 13], [13, 13], [0, 19]], WHITE)
	p.flat(-58, 0, 116, 2, _dk(CONCRETE))

## Cidade do México: pirâmide em degraus com o templo no alto.
static func _draw_pyramid_step(p: _Pen) -> void:
	var stone := Color("#A8987E")
	for i in 5:
		var w := 100.0 - i * 18.0
		var y := i * 9.0
		p.rect(-w / 2, y, w, 9, stone)
		p.flat(w / 2 - 5, y, 5, 9, _dk(stone))
		p.flat(-w / 2, y + 8, w, 1, _lt(stone))
	p.flat(-6, 0, 12, 45, _lt(stone))
	for y in range(1, 45, 2):
		p.flat(-6, y, 12, 1, stone)
	p.rect(-11, 45, 22, 8, stone)
	p.lamp(-3, 45, 6, 5, DARK)
	p.rect(-12, 53, 24, 2, _dk(stone))

## Buenos Aires: o Obelisco.
static func _draw_obelisk(p: _Pen) -> void:
	p.rect(-16, 0, 32, 3, CONCRETE)
	p.flat(-16, 2, 32, 1, _lt(CONCRETE))
	p.poly([[-5, 3], [5, 3], [3.5, 72], [-3.5, 72]], WHITE)
	p.poly([[1, 3], [5, 3], [3.5, 72], [1, 72]], _dk(WHITE))
	p.poly([[-3.5, 72], [3.5, 72], [0, 79]], WHITE)
	p.lamp(-1, 64, 2, 2, DARK)

## Lisboa: a Ponte 25 de Abril.
static func _draw_bridge(p: _Pen) -> void:
	var span := 63.0
	var cable := _dk(RED)
	var curve: Array = []
	for i in 41:
		var x := -40.0 + i * 2.0
		curve.append([x, 24.0 + 34.0 * pow(x / 40.0, 2)])
	p.path(curve, cable)
	p.path([[-40, 58], [-span, 24]], cable)
	p.path([[40, 58], [span, 24]], cable)
	for x in range(-36, 37, 6):
		p.line(x, 23, x, 24.0 + 34.0 * pow(x / 40.0, 2), _dk(cable))
	p.rect(-span, 18, span * 2, 5, RED)
	p.flat(-span, 22, span * 2, 1, _lt(RED))
	for x in range(-62, 62, 4):
		p.line(x, 18, x + 2, 21, _dk(RED))
	for x in [-42, 37]:
		p.rect(x - 1, 0, 7, 6, CONCRETE)
		p.rect(x, 6, 5, 54, RED)
		p.flat(x + 3, 6, 2, 54, _dk(RED))
		for y in [32, 52]:
			p.flat(x - 1, y, 7, 2, _dk(RED))

## Madri: a Puerta de Alcalá.
static func _draw_alcala(p: _Pen) -> void:
	var granite := Color("#CFC4AE")
	p.rect(-46, 0, 92, 28, granite)
	p.rect(41, 0, 5, 28, _dk(granite))
	for x in [-26, -10, 9, 25]:
		p.flat(x, 0, 2, 27, _lt(granite))
	for x in [-18, 0, 18]:
		p.rect(x - 4, 0, 8, 14, DARK)
		p.circle(x, 14, 4, DARK)
	p.rect(-38, 0, 6, 12, DARK)
	p.rect(32, 0, 6, 12, DARK)
	p.flat(-47, 27, 94, 2, _lt(granite))
	p.rect(-20, 29, 40, 7, granite)
	p.rect(14, 29, 6, 7, _dk(granite))
	p.poly([[-21, 36], [21, 36], [0, 43]], granite)
	p.rect(-3, 42, 6, 5, _dk(granite))
	for x in [-19, 16]:
		p.rect(x, 36, 3, 5, _dk(granite))
	for x in [-44, 41]:
		p.rect(x, 29, 3, 4, _dk(granite))

## Paris: a Torre Eiffel.
static func _draw_eiffel(p: _Pen) -> void:
	p.arc(0, 0, 13, PI, TAU, BRONZE, 2)
	p.poly([[-27, 0], [-19, 0], [-7, 22], [-13, 22]], BRONZE)
	p.poly([[19, 0], [27, 0], [13, 22], [7, 22]], _dk(BRONZE))
	p.rect(-15, 22, 30, 3, BRONZE)
	p.flat(-15, 24, 30, 1, _lt(BRONZE))
	p.poly([[-12, 25], [-7, 25], [-2, 46], [-5, 46]], BRONZE)
	p.poly([[7, 25], [12, 25], [5, 46], [2, 46]], _dk(BRONZE))
	p.flat(-7, 46, 14, 2, BRONZE)
	p.poly([[-5, 48], [5, 48], [1.5, 74], [-1.5, 74]], BRONZE)
	p.poly([[0, 48], [5, 48], [1.5, 74], [0, 74]], _dk(BRONZE))
	for y in [56, 64]:
		p.flat(-4 + (y - 48) * 0.13, y, 8 - (y - 48) * 0.26, 1, _lt(BRONZE))
	p.rect(-2, 74, 4, 3, BRONZE)
	p.line(0, 77, 0, 83, BRONZE)
	p.lamp(-1, 75, 2, 1, _dk(BRONZE))

## Londres: o Big Ben e o Parlamento.
static func _draw_bigben(p: _Pen) -> void:
	var slate := Color("#4A5260")
	p.rect(-62, 0, 64, 18, SANDSTONE)
	for x in range(-60, 0, 5):
		p.flat(x, 18, 1, 4, SANDSTONE)
		p.lamp(x + 2, 4, 1, 10, _dk(SANDSTONE))
	p.flat(-62, 17, 64, 1, _lt(SANDSTONE))
	p.rect(-58, 0, 12, 38, SANDSTONE)
	p.rect(-49, 0, 3, 38, _dk(SANDSTONE))
	for x in [-58, -53, -47]:
		p.flat(x, 38, 1, 4, SANDSTONE)
	p.rect(6, 0, 12, 48, SANDSTONE)
	p.rect(15, 0, 3, 48, _dk(SANDSTONE))
	for x in [8, 11]:
		p.flat(x, 4, 1, 42, _dk(SANDSTONE))
	p.rect(4, 47, 16, 12, SANDSTONE)
	p.rect(17, 47, 3, 12, _dk(SANDSTONE))
	p.lamp_circle(12, 53, 4.5, Color("#F4EFD8"))
	p.line(12, 53, 12, 56, DARK)
	p.line(12, 53, 14, 53, DARK)
	p.rect(6, 59, 12, 6, SANDSTONE)
	for x in [8, 11, 14]:
		p.flat(x, 60, 2, 4, DARK)
	p.poly([[5, 65], [19, 65], [12, 80]], slate)
	p.poly([[12, 80], [19, 65], [14, 65]], _dk(slate))
	p.line(12, 80, 12, 84, GOLD)

## Roma: o Coliseu, com o lado direito em ruína.
static func _draw_colosseum(p: _Pen) -> void:
	var stone := Color("#D7C29A")
	p.poly([[-56, 0], [56, 0], [56, 22], [46, 26], [34, 34], [20, 40], [-56, 40]], stone)
	p.flat(-56, 0, 10, 40, _lt(stone))
	p.poly([[44, 0], [56, 0], [56, 22], [46, 26], [44, 27]], _dk(stone))
	for row in 3:
		var y := 3 + row * 11
		for x in range(-52, 54, 8):
			if y + 8 < _colosseum_top(x + 2):
				p.lamp(x, y, 4, 6, _dk(_dk(stone)))
				p.flat(x + 1, y + 6, 2, 1, _dk(_dk(stone)))
	for x in range(-52, 18, 8):
		p.flat(x + 1, 36, 2, 2, _dk(stone))

static func _colosseum_top(x: float) -> float:
	return 40.0 if x < 20 else lerpf(40.0, 22.0, clampf((x - 20.0) / 36.0, 0.0, 1.0))

## Budapeste: o Parlamento às margens do Danúbio.
static func _draw_parliament(p: _Pen) -> void:
	var wall := Color("#E6DFD0")
	p.rect(-60, 0, 120, 16, wall)
	p.rect(54, 0, 6, 16, _dk(wall))
	for x in range(-58, 58, 4):
		p.lamp(x, 3, 1, 9, _dk(wall))
	p.rect(-60, 16, 120, 4, ROOF_RED)
	p.flat(-60, 19, 120, 1, _lt(ROOF_RED))
	for x in range(-58, 60, 6):
		p.flat(x, 20, 1, 4, wall)
	for x in [-42, 38]:
		p.rect(x, 16, 5, 16, wall)
		p.flat(x + 3, 16, 2, 16, _dk(wall))
		p.poly([[x - 1, 32], [x + 6, 32], [x + 2.5, 41]], ROOF_RED)
	for x in [-26, 22]:
		p.rect(x, 16, 4, 11, wall)
		p.poly([[x - 1, 27], [x + 5, 27], [x + 2, 34]], ROOF_RED)
	p.rect(-9, 20, 18, 10, wall)
	p.rect(5, 20, 4, 10, _dk(wall))
	p.poly([[-12, 30], [12, 30], [9, 38], [4, 44], [0, 46], [-4, 44], [-9, 38]], ROOF_RED)
	p.poly([[0, 46], [4, 44], [9, 38], [12, 30], [3, 30]], _dk(ROOF_RED))
	p.line(0, 46, 0, 58, wall)

## Jerusalém: o Domo da Rocha atrás da muralha da Cidade Velha.
static func _draw_golden_dome(p: _Pen) -> void:
	var wall := Color("#CDB07D")
	var tile := Color("#2F6DB5")
	p.circle(0, 30, 11, _dk(GOLD))
	p.circle(-2, 31, 10, GOLD)
	p.flat(-6, 34, 2, 3, _lt(GOLD))
	p.line(0, 41, 0, 45, GOLD)
	p.rect(-11, 24, 22, 6, tile)
	p.flat(-11, 29, 22, 1, WHITE)
	p.rect(-21, 13, 42, 11, tile)
	p.rect(15, 13, 6, 11, _dk(tile))
	p.flat(-21, 22, 42, 1, WHITE)
	for x in range(-19, 19, 5):
		p.lamp(x, 15, 2, 4, _lt(tile))
	p.rect(-30, 10, 60, 3, _lt(wall))
	p.rect(-62, 0, 124, 10, wall)
	p.flat(-62, 0, 124, 2, _dk(wall))
	for x in range(-62, 62, 4):
		if absf(x) > 31:
			p.flat(x, 10, 2, 2, wall)

## Dubai: o Burj Khalifa e o Burj Al Arab.
static func _draw_burj(p: _Pen) -> void:
	var steel := Color("#A9B8C6")
	for t in [[-9, 0, 18, 18], [-7, 18, 15, 16], [-6, 34, 11, 14], [-4, 48, 9, 12], [-3, 60, 6, 10], [-2, 70, 4, 6]]:
		p.rect(t[0], t[1], t[2], t[3], steel)
		p.flat(t[0], t[1], 2, t[3], _lt(steel))
		p.flat(t[0] + t[2] - 2, t[1], 2, t[3], _dk(steel))
		p.flat(t[0], t[1] + t[3] - 1, t[2], 1, _dk(steel))
		for y in range(t[1] + 2, t[1] + t[3] - 2, 3):
			p.lamp(t[0] + 2, y, t[2] - 4, 1, Color("#8FA3B5"))
	p.line(0, 76, 0, 83, _lt(steel))
	p.poly([[38, 0], [42, 0], [52, 10], [56, 30], [42, 40], [38, 40]], WHITE)
	p.poly([[46, 4], [52, 10], [56, 30], [48, 35]], _dk(WHITE))
	p.rect(35, 0, 2, 44, _dk(WHITE))
	p.flat(48, 30, 7, 1, WHITE)

## Cairo: as pirâmides de Gizé e a Esfinge.
static func _draw_pyramid(p: _Pen) -> void:
	p.poly([[-62, 0], [-30, 0], [-46, 22]], SAND)
	p.poly([[-46, 22], [-30, 0], [-41, 0]], _dk(SAND))
	p.poly([[-40, 0], [40, 0], [0, 50]], SAND)
	p.poly([[0, 50], [40, 0], [6, 0]], _dk(SAND))
	for y in [10, 20, 30, 40]:
		p.line(-40 + y * 0.8, y, 6 - y * 0.12, y, SAND.darkened(0.08))
	p.poly([[0, 50], [3, 46], [-3, 46]], _lt(SAND))
	p.poly([[36, 0], [62, 0], [49, 24]], SAND)
	p.poly([[49, 24], [62, 0], [53, 0]], _dk(SAND))
	p.rect(-30, 0, 14, 4, _dk(SAND))
	p.rect(-19, 4, 4, 5, _dk(SAND))
	p.flat(-20, 7, 6, 2, _dk(SAND))

## Tóquio: a Tokyo Tower (o Fuji fica no fundo da cena).
static func _draw_tokyo_tower(p: _Pen) -> void:
	var orange := Color("#E5482E")
	p.arc(0, 0, 10, PI, TAU, orange, 2)
	p.poly([[-21, 0], [-15, 0], [-5, 20], [-9, 20]], orange)
	p.poly([[15, 0], [21, 0], [9, 20], [5, 20]], _dk(orange))
	p.rect(-12, 20, 24, 4, WHITE)
	p.poly([[-9, 24], [9, 24], [4, 44], [-4, 44]], orange)
	p.poly([[2, 24], [9, 24], [4, 44], [1, 44]], _dk(orange))
	for y in [30, 37]:
		p.flat(-9 + (y - 24) * 0.25, y, 18 - (y - 24) * 0.5, 2, WHITE)
	p.rect(-8, 44, 16, 5, WHITE)
	p.lamp(-7, 45, 14, 2, Color("#7FA3C0"))
	p.poly([[-4, 49], [4, 49], [1.5, 68], [-1.5, 68]], orange)
	for y in [55, 62]:
		p.flat(-3.5 + (y - 49) * 0.13, y, 7 - (y - 49) * 0.26, 2, WHITE)
	p.flat(-3, 66, 6, 2, WHITE)
	p.line(0, 68, 0, 80, WHITE)

## Sydney: a Opera House e a Harbour Bridge.
static func _draw_opera(p: _Pen) -> void:
	var podium := Color("#B5764F")
	var steel := Color("#6E7680")
	p.arc(52, 0, 16, PI, TAU, steel, 2)
	p.rect(35, 10, 34, 2, steel)
	p.rect(33, 0, 4, 14, STONE)
	p.rect(66, 0, 4, 14, STONE)
	for s in [[-46, -20, -31, 30], [-32, -2, -15, 38], [-12, 14, 1, 30], [8, 30, 18, 22]]:
		p.poly([[s[0], 6], [s[1], 6], [s[2], s[3]]], WHITE)
		p.poly([[s[2], s[3]], [s[1], 6], [(s[1] + s[2]) / 2.0, 6]], _dk(WHITE))
		p.line(s[0] + 1, 6, s[2], s[3] - 1, Color("#FFFFFF"))
	p.rect(-50, 0, 100, 6, podium)
	p.flat(-50, 5, 100, 1, _lt(podium))

## Moscou: a Catedral de São Basílio.
static func _draw_onion(p: _Pen) -> void:
	var green := Color("#1F7A4D")
	var blue := Color("#2F6DB5")
	var yellow := Color("#E0A100")
	p.rect(-42, 0, 84, 14, BRICK)
	p.flat(-42, 13, 84, 1, WHITE)
	for x in range(-38, 40, 6):
		p.lamp(x, 3, 2, 6, _dk(BRICK))
	p.rect(-5, 14, 10, 30, BRICK)
	p.rect(2, 14, 3, 30, _dk(BRICK))
	p.poly([[-6, 44], [6, 44], [0, 64]], green)
	for y in [48, 54]:
		p.flat(-6 + (y - 44) * 0.3, y, 12 - (y - 44) * 0.6, 1, WHITE)
	p.circle(0, 65, 2, GOLD)
	p.line(0, 67, 0, 71, GOLD)
	for t in [[-30, 28, RED, green], [-16, 36, blue, WHITE], [16, 36, green, yellow], [30, 28, yellow, RED]]:
		var x: float = t[0]
		var top: float = t[1]
		p.rect(x - 4, 14, 8, top - 14, BRICK)
		p.flat(x + 2, 14, 2, top - 14, _dk(BRICK))
		p.flat(x - 5, top - 2, 10, 2, WHITE)
		p.circle(x, top + 4, 5, t[2])
		p.flat(x - 3, top + 1, 1, 6, t[3])
		p.flat(x, top, 1, 8, t[3])
		p.flat(x + 3, top + 1, 1, 6, t[3])
		p.poly([[x - 3, top + 7], [x + 3, top + 7], [x, top + 12]], t[2])
		p.line(x, top + 12, x, top + 15, GOLD)

## Cidade do Cabo: a Table Mountain com a "toalha" de nuvem.
static func _draw_mesa(p: _Pen) -> void:
	p.poly([[-63, 0], [-54, 16], [-44, 38], [-38, 46], [38, 46], [45, 39], [53, 22], [63, 0]], ROCK)
	p.poly([[38, 46], [45, 39], [53, 22], [63, 0], [34, 0], [32, 30]], _dk(ROCK))
	p.poly([[-63, 0], [-54, 16], [-46, 32], [-40, 20], [-36, 0]], _lt(ROCK))
	for x in range(-34, 32, 5):
		p.flat(x, 28 + posmod(x, 3) * 2, 1, 12, _dk(ROCK))
	p.poly([[-63, 0], [-50, 10], [50, 10], [63, 0]], GREEN.darkened(0.1))
	p.flat(-38, 46, 76, 2, WHITE)
	for d in [[-30, 3], [-12, 4], [6, 2], [22, 5]]:
		p.flat(d[0], 46 - d[1], 5, d[1], Color(WHITE, 0.85))

## Pequim: o Templo do Céu.
static func _draw_temple_heaven(p: _Pen) -> void:
	var marble := Color("#EDEBE4")
	var blue := Color("#2C4F8F")
	var red := Color("#A62B2B")
	for i in 3:
		var w := 76.0 - i * 14.0
		p.rect(-w / 2, i * 4, w, 4, marble)
		p.flat(-w / 2, i * 4 + 3, w, 1, _dk(marble))
	p.rect(-12, 12, 24, 9, red)
	for x in range(-10, 11, 4):
		p.lamp(x, 12, 1, 9, _dk(red))
	p.poly([[-22, 21], [22, 21], [15, 26], [-15, 26]], blue)
	p.rect(-9, 26, 18, 4, red)
	p.poly([[-16, 30], [16, 30], [10, 35], [-10, 35]], blue)
	p.rect(-6, 35, 12, 3, red)
	p.poly([[-11, 38], [11, 38], [0, 50]], blue)
	p.poly([[0, 50], [11, 38], [4, 38]], _dk(blue))
	p.flat(-15, 25, 30, 1, GOLD)
	p.flat(-10, 34, 20, 1, GOLD)
	p.circle(0, 51, 1.5, GOLD)
	p.line(0, 52, 0, 55, GOLD)

## Santiago: a Gran Torre Costanera (os Andes ficam no fundo).
static func _draw_costanera(p: _Pen) -> void:
	p.rect(-44, 0, 14, 34, _lt(GLASS))
	p.rect(-34, 0, 4, 34, GLASS)
	p.rect(24, 0, 12, 28, _lt(GLASS))
	p.rect(32, 0, 4, 28, GLASS)
	for y in range(3, 32, 4):
		p.lamp(-42, y, 6, 1, GLASS)
		p.lamp(26, y, 4, 1, GLASS)
	p.poly([[-8, 0], [8, 0], [7, 70], [-7, 70]], GLASS)
	p.poly([[1, 0], [8, 0], [7, 70], [1, 70]], _dk(GLASS))
	p.flat(-5, 0, 2, 70, _lt(GLASS))
	for y in range(4, 70, 4):
		p.lamp(-6, y, 12, 1, _dk(GLASS))
	p.path([[-7, 70], [-4, 80], [4, 80], [7, 70]], GLASS)
	p.path([[-7, 70], [4, 80]], _dk(GLASS))
	p.path([[7, 70], [-4, 80]], _dk(GLASS))

## Nova Délhi: o Portão da Índia.
static func _draw_india_gate(p: _Pen) -> void:
	var stone := Color("#C99A6B")
	p.rect(-26, 0, 52, 3, _dk(stone))
	p.circle(0, 55, 7, stone)
	p.rect(-18, 3, 36, 40, stone)
	p.flat(-18, 3, 2, 40, _lt(stone))
	p.rect(13, 3, 5, 40, _dk(stone))
	p.rect(-6, 3, 12, 22, DARK)
	p.circle(0, 25, 6, DARK)
	p.lamp(-1, 3, 2, 2, Color("#F2A33A"))
	p.flat(-14, 36, 28, 2, _dk(stone))
	p.flat(-19, 31, 38, 2, _lt(stone))
	p.rect(-20, 43, 40, 3, stone)
	p.flat(-20, 45, 40, 1, _lt(stone))
	p.rect(-14, 46, 28, 6, stone)
	p.rect(-10, 52, 20, 3, stone)

## Toronto: a CN Tower e a cúpula do estádio.
static func _draw_needle(p: _Pen) -> void:
	var dome := Color("#D9D6CE")
	var half: Array = []
	for i in 13:
		half.append([-38 + cos(PI * i / 12.0) * 16, sin(PI * i / 12.0) * 16])
	p.poly(half, dome)
	p.arc(-38, 0, 11, PI, TAU, _dk(dome), 1)
	p.arc(-38, 0, 6, PI, TAU, _dk(dome), 1)
	p.poly([[-5, 0], [5, 0], [2, 58], [-2, 58]], CONCRETE)
	p.poly([[1, 0], [5, 0], [2, 58], [1, 58]], _dk(CONCRETE))
	p.rect(-9, 56, 18, 3, CONCRETE)
	p.rect(-8, 59, 16, 3, Color("#4B5563"))
	p.lamp(-7, 60, 14, 1, Color("#6B7280"))
	p.rect(-6, 62, 12, 2, CONCRETE)
	p.flat(-1, 64, 2, 8, CONCRETE)
	p.flat(-2, 70, 4, 2, CONCRETE)
	p.line(0, 72, 0, 83, _lt(CONCRETE))
	p.lamp(0, 82, 1, 1, RED)

## Istambul: a Mesquita Azul com os minaretes.
static func _draw_mosque(p: _Pen) -> void:
	var wall := Color("#D9D3C7")
	for m in [[-47, 54], [-37, 46], [35, 46], [45, 54]]:
		var x: float = m[0]
		var h: float = m[1]
		p.rect(x, 0, 3, h, wall)
		p.flat(x + 2, 0, 1, h, _dk(wall))
		p.flat(x - 1, roundf(h * 0.65), 5, 1, wall)
		p.flat(x - 1, roundf(h * 0.85), 5, 1, wall)
		p.poly([[x, h], [x + 3, h], [x + 1.5, h + 9]], LEAD)
	p.circle(0, 20, 14, _dk(LEAD))
	p.circle(-2, 21, 13, LEAD)
	p.line(0, 34, 0, 38, GOLD)
	for d in [[-19, 8], [19, 8], [-31, 5], [31, 5]]:
		p.circle(d[0], 14, d[1], LEAD)
	p.rect(-15, 14, 30, 6, wall)
	for x in range(-13, 14, 3):
		p.lamp(x, 15, 1, 3, _dk(wall))
	p.rect(-40, 0, 80, 14, wall)
	p.rect(34, 0, 6, 14, _dk(wall))
	for x in range(-36, 36, 6):
		p.lamp(x, 3, 2, 5, _dk(wall))

## Atenas: o Partenon no alto da Acrópole.
static func _draw_temple(p: _Pen) -> void:
	var marble := Color("#E9E2D0")
	p.poly([[-63, 0], [-52, 9], [-42, 16], [42, 16], [52, 9], [63, 0]], ROCK)
	p.poly([[42, 16], [52, 9], [63, 0], [30, 0]], _dk(ROCK))
	p.flat(-42, 15, 84, 1, _lt(ROCK))
	for v in [[-50, 4], [-30, 8], [46, 3], [20, 6]]:
		p.flat(v[0], v[1], 3, 2, GREEN)
	p.rect(-32, 16, 64, 3, marble)
	p.flat(-32, 18, 64, 1, _lt(marble))
	p.rect(-30, 19, 60, 15, _dk(_dk(marble)))
	for i in 9:
		var x := -30 + i * 7
		p.rect(x, 19, 3, 15, marble)
		p.flat(x + 2, 19, 1, 15, _dk(marble))
	p.rect(-33, 34, 66, 4, marble)
	p.flat(-33, 35, 66, 1, _dk(marble))
	p.poly([[-33, 38], [33, 38], [0, 45]], marble)
	p.poly([[0, 45], [33, 38], [0, 38]], _dk(marble))

## Berlim: o Portão de Brandemburgo com a quadriga.
static func _draw_brandenburg(p: _Pen) -> void:
	var copper := Color("#5C8C77")
	p.rect(-46, 0, 10, 20, SANDSTONE)
	p.rect(36, 0, 10, 20, SANDSTONE)
	p.flat(43, 0, 3, 20, _dk(SANDSTONE))
	p.rect(-34, 2, 68, 24, _dk(_dk(SANDSTONE)))
	p.rect(-36, 0, 72, 2, _dk(SANDSTONE))
	for x in [-34, -21, -8, 5, 18, 30]:
		p.rect(x, 2, 4, 24, SANDSTONE)
		p.flat(x + 3, 2, 1, 24, _dk(SANDSTONE))
	p.rect(-37, 26, 74, 5, SANDSTONE)
	for x in range(-35, 36, 3):
		p.flat(x, 27, 1, 2, _dk(SANDSTONE))
	p.rect(-22, 31, 44, 6, SANDSTONE)
	p.rect(-14, 37, 28, 2, SANDSTONE)
	p.rect(-9, 39, 18, 4, copper)
	p.flat(-9, 43, 3, 2, copper)
	p.flat(6, 43, 3, 2, copper)
	p.rect(-2, 43, 4, 3, copper)
	p.flat(-1, 46, 2, 6, copper)
	p.line(1, 46, 3, 56, copper)
	p.flat(2, 55, 3, 1, GOLD)

## Amsterdã: as casas estreitas da beira do canal.
static func _draw_canal(p: _Pen) -> void:
	var colors := [Color("#8B4513"), Color("#A0522D"), Color("#5C3A21"), Color("#B5651D"), Color("#2F3E46"), Color("#7A4A2A"), Color("#6B2E2E"), Color("#8A6A4A")]
	var widths := [14, 16, 13, 15, 14, 16, 13, 15]
	var heights := [36, 42, 32, 46, 38, 34, 44, 36]
	var x := -58.0
	for i in colors.size():
		var w: float = widths[i]
		var h: float = heights[i]
		var c: Color = colors[i]
		p.rect(x, 0, w, h, c)
		p.flat(x + w - 2, 0, 2, h, _dk(c))
		match i % 3:
			0:
				p.rect(x + 2, h, w - 4, 3, c)
				p.flat(x + 4, h + 3, w - 8, 3, c)
				p.flat(x + 5, h + 6, w - 10, 2, c)
			1:
				p.rect(x + 3, h, w - 6, 5, c)
				p.circle(x + w / 2, h + 5, (w - 6) / 2, c)
			2:
				p.rect(x + 4, h, w - 8, 7, c)
				p.poly([[x + 3, h + 7], [x + w - 3, h + 7], [x + w / 2, h + 10]], WHITE)
		for y in range(5, h - 3, 7):
			for wx in [x + 3, x + w - 6]:
				p.flat(wx, y, 3, 5, WHITE)
				p.lamp(wx + 1, y + 1, 1, 3, DARK)
		p.flat(x + w / 2 - 1, 0, 3, 4, DARK)
		x += w
