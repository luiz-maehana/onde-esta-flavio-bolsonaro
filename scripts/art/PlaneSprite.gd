class_name PlaneSprite
extends RefCounted
## Avião da viagem em pixel art visto de cima (spec 012, RF97/98): branco com
## a faixa vermelha da F.U.R.O., desenhado como mapa de caracteres apontando
## pra direita e girado em DIRECTIONS direções fixas (pixel art girada
## livremente borra). Texturas geradas uma vez e guardadas.

const DIRECTIONS := 16
## Metade de cima (a de baixo é o espelho); a última linha é o eixo.
## k contorno, w branco, g sombra do branco, r vermelho, b janela da cabine.
const HALF := [
	"....kkk..............",
	"....krrk.............",
	".....kwwk............",
	"kk....kwgk...........",
	"krk...kwwgk..........",
	"kwgk..kwwwgk.........",
	".kwgkkkwwwwgkkkkkkk..",
	".kwwwwwwwwwwwwwwwwbk.",
	".krrrrrrrrrrrrrrrrrbk",
]
const COLORS := {
	"k": Color("#141414"), "w": Color("#FFFFFF"), "g": Color("#C9C3B5"),
	"r": Color("#C8102E"), "b": Color("#5FA8D3"),
}
## Lado do quadro quadrado: cabe o avião em qualquer giro.
const FRAME := 25

static var _frames: Array[ImageTexture] = []

## Quadro da direção mais próxima do rumo `dir` (vetor de tela).
static func frame_for(dir: Vector2) -> ImageTexture:
	return frames()[index_for(dir)]

static func index_for(dir: Vector2) -> int:
	return posmod(roundi(dir.angle() / (TAU / DIRECTIONS)), DIRECTIONS)

static func frames() -> Array[ImageTexture]:
	if _frames.is_empty():
		var base := _base_image()
		for i in DIRECTIONS:
			_frames.append(ImageTexture.create_from_image(_rotated(base, i * TAU / DIRECTIONS)))
	return _frames

static func _base_image() -> Image:
	var lower: Array = HALF.slice(0, HALF.size() - 1)
	lower.reverse()
	var rows: Array = HALF + lower
	var img := Image.create_empty(FRAME, FRAME, false, Image.FORMAT_RGBA8)
	var offset := Vector2i((FRAME - HALF[0].length()) / 2, (FRAME - rows.size()) / 2)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if COLORS.has(row[x]):
				img.set_pixelv(offset + Vector2i(x, y), COLORS[row[x]])
	return img

## Giro pelo vizinho mais próximo, amostrando o centro de cada pixel.
static func _rotated(src: Image, angle: float) -> Image:
	var out := Image.create_empty(FRAME, FRAME, false, Image.FORMAT_RGBA8)
	var c := Vector2(FRAME, FRAME) / 2.0
	for y in FRAME:
		for x in FRAME:
			var p := (Vector2(x + 0.5, y + 0.5) - c).rotated(-angle) + c
			var sx := floori(p.x)
			var sy := floori(p.y)
			if sx >= 0 and sy >= 0 and sx < FRAME and sy < FRAME:
				out.set_pixel(x, y, src.get_pixel(sx, sy))
	return out
