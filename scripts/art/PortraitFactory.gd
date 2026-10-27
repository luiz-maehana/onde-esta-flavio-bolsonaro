class_name PortraitFactory
extends RefCounted
## Monta retratos 48x48 a partir de um "spec" (Dictionary) em camadas:
## fundo (cabelo longo, mochila) -> corpo/roupa -> pescoço -> orelhas ->
## cabeça -> rosto -> cabelo -> chapéu -> óculos -> objeto -> contorno.
## Figurinos vêm de dados (disguises.json / flavor.json); o rosto do senador
## é constante aqui porque é a identidade do personagem.

const CX := 24.0
const CY := 19.5
const FACE_RY := 11.5
const INK := Color("#141414")
const EYE_WHITE := Color("#F4F1EA")
const SKIN_TONES := ["#F6D3B8", "#E8B796", "#D29A72", "#B87A50", "#8D5A3B", "#5E3A26"]
const HAIR_COLORS := ["#1B1410", "#3B2416", "#6B4226", "#A0703C", "#D8B46A", "#8A2E1C"]
const GREY_HAIR := ["#9A9A9A", "#C9C9C9", "#E6E6E6"]
const EYE_COLORS := ["#3B2416", "#4A2C17", "#2E5E8C", "#3E6B3A", "#1B1410"]

const DEFAULTS := {
	"skin": "#E8B796", "hair": "short", "hair_color": "#1B1410", "brows": "normal",
	"eye_color": "#3B2416", "gaze": "front", "face_rx": 9.5, "age": 1,
	"facial_hair": "", "glasses": "", "lips": "", "earrings": false, "mouth": "neutral",
	"clothes": "tshirt", "colors": ["#1D3557", "#FFFFFF", "#C8102E"],
	"headwear": "", "headwear_colors": ["#C8102E", "#141414"], "prop": "",
}

## --- Senador ---------------------------------------------------------------

## Caricatura (RF19): cabelo escuro curto penteado de lado com topete,
## sobrancelha grossa, rosto mais largo, olhar de canto, sorriso de lado.
const FLAVIO_FACE := {
	"skin": "#E9B995", "hair": "side_part", "hair_color": "#24170F", "brows": "thick",
	"eye_color": "#4A2C17", "gaze": "side", "face_rx": 10.3, "age": 1, "mouth": "smirk",
	"facial_hair": "shadow",
}

static func flavio_spec(outfit: Dictionary) -> Dictionary:
	var spec := FLAVIO_FACE.duplicate()
	spec.merge(outfit, true)
	return spec

## Procurado: fedora e sobretudo vermelhos (identidade da capa).
static func flavio_wanted_spec() -> Dictionary:
	return flavio_spec({"clothes": "trench", "colors": ["#C8102E", "#F4F1EA", "#009C3B"], "headwear": "fedora", "headwear_colors": ["#C8102E", "#141414"]})

## Foto oficial de senador: terno escuro, camisa branca, gravata verde.
static func flavio_official_spec() -> Dictionary:
	return flavio_spec({"clothes": "suit", "colors": ["#1F2A44", "#F4F1EA", "#009C3B"], "gaze": "front", "mouth": "smile"})

## --- Testemunhas -------------------------------------------------------------

## Traços sorteados (pele, idade, cabelo, barba, óculos) + figurino do local.
static func witness_spec(rng: RandomNumberGenerator, outfit: Dictionary) -> Dictionary:
	var feminine := rng.randf() < 0.5
	var age := rng.randi_range(0, 2)
	if outfit.has("min_age"):
		age = maxi(age, int(outfit["min_age"]))
	var hair_color: String = HAIR_COLORS[rng.randi_range(0, HAIR_COLORS.size() - 1)]
	if age == 2 and rng.randf() < 0.75:
		hair_color = GREY_HAIR[rng.randi_range(0, GREY_HAIR.size() - 1)]
	var styles := ["long", "bun", "ponytail", "curly", "short"] if feminine else ["short", "buzz", "curly", "side_part", "bald"]
	var spec := {
		"skin": SKIN_TONES[rng.randi_range(0, SKIN_TONES.size() - 1)],
		"hair": styles[rng.randi_range(0, styles.size() - 1)],
		"hair_color": hair_color,
		"brows": "thin" if feminine else ["normal", "thick"][rng.randi_range(0, 1)],
		"eye_color": EYE_COLORS[rng.randi_range(0, EYE_COLORS.size() - 1)],
		"face_rx": rng.randf_range(8.8, 10.0) if not feminine else rng.randf_range(8.6, 9.4),
		"age": age,
		"mouth": ["neutral", "smile", "neutral"][rng.randi_range(0, 2)],
		"gaze": "front",
		"earrings": feminine and rng.randf() < 0.5,
		"lips": ["#B23A48", "#8E2C3C", ""][rng.randi_range(0, 2)] if feminine else "",
		"facial_hair": "" if feminine else ["", "", "mustache", "beard", "stubble"][rng.randi_range(0, 4)],
	}
	var glasses_chance: float = outfit.get("glasses", 0.2)
	spec["glasses"] = ["round", "square"][rng.randi_range(0, 1)] if rng.randf() < glasses_chance else ""
	if outfit.has("hair") and outfit["hair"] != "":
		spec["hair"] = outfit["hair"]
	for k in ["clothes", "colors", "headwear", "headwear_colors", "prop"]:
		if outfit.has(k):
			spec[k] = outfit[k]
	return spec

## --- Pintura -------------------------------------------------------------------

static func paint(spec_in: Dictionary) -> Image:
	var s := DEFAULTS.duplicate()
	s.merge(spec_in, true)
	var p := PortraitPainter.new()
	var skin := Color(s["skin"])
	var hair_color := Color(s["hair_color"])
	var cols: Array = s["colors"].map(func(c): return Color(c))
	var rx: float = s["face_rx"]

	_back_layer(p, s, hair_color, rx)
	_clothes(p, s["clothes"], cols, skin)
	p.darken_region(36, 34, 12, 14, 0.14)
	_neck(p, skin)
	p.shaded_ellipse(CX - rx - 0.2, 20.5, 1.9, 2.9, skin)
	p.shaded_ellipse(CX + rx + 0.2, 20.5, 1.9, 2.9, skin.darkened(0.08))
	p.shaded_ellipse(CX, CY, rx, FACE_RY, skin)
	_face(p, s, skin, hair_color)
	_hair(p, s["hair"], hair_color, rx)
	_headwear(p, s["headwear"], s["headwear_colors"].map(func(c): return Color(c)), rx)
	_glasses(p, s["glasses"])
	_prop(p, s["prop"], skin, cols)
	p.outline(INK)
	return p.img

## Cabelo comprido / peruca atrás dos ombros e mochila de entregador.
static func _back_layer(p: PortraitPainter, s: Dictionary, hair_color: Color, rx: float) -> void:
	match s["hair"]:
		"long", "wig_long":
			p.poly([[CX - rx - 2, 14], [CX + rx + 2, 14], [CX + rx + 4, 40], [CX - rx - 4, 40]], hair_color.darkened(0.15))
		"wig_volume":
			p.ellipse(CX, 22, rx + 6, 17, hair_color.darkened(0.12))
		"ponytail":
			p.poly([[33, 14], [37, 18], [38, 32], [35, 34], [34, 20]], hair_color.darkened(0.15))
	if s["prop"] == "thermal_bag":
		p.rect(26, 15, 20, 22, Color("#C8102E"))
		p.rect(26, 15, 20, 3, Color("#7A0A1C"))
		p.rect(31, 22, 10, 6, Color("#F4F1EA"))
		p.darken_region(40, 15, 6, 22, 0.2)

static func _neck(p: PortraitPainter, skin: Color) -> void:
	p.rect(20, 27, 8, 7, skin.darkened(0.12))
	p.rect(20, 27, 8, 2, skin.darkened(0.25))

static func _torso(p: PortraitPainter, c: Color) -> void:
	p.poly([[5, 48], [7, 39], [11, 35], [18, 33], [30, 33], [37, 35], [41, 39], [43, 48]], c)

## --- Roupas ------------------------------------------------------------------

static func _clothes(p: PortraitPainter, kind: String, c: Array, skin: Color) -> void:
	var c1: Color = c[0]
	var c2: Color = c[1] if c.size() > 1 else Color.WHITE
	var c3: Color = c[2] if c.size() > 2 else c1.darkened(0.3)
	match kind:
		"suit", "white_suit":
			_torso(p, c1)
			p.poly([[19, 33], [29, 33], [24, 43]], c2)
			if kind == "suit":
				p.poly([[23, 35], [25, 35], [26, 41], [24, 44], [22, 41]], c3)
				p.rect(23, 33, 3, 2, c3.darkened(0.2))
			p.line(19, 33, 23, 45, c1.darkened(0.3))
			p.line(29, 33, 25, 45, c1.darkened(0.3))
		"trench":
			_torso(p, c1)
			p.poly([[19, 33], [29, 33], [24, 41]], c2)
			p.poly([[23, 35], [25, 35], [25, 40], [24, 41], [23, 40]], c3)
			p.poly([[10, 37], [16, 26], [21, 33], [17, 42]], c1.darkened(0.12))
			p.poly([[38, 37], [32, 26], [27, 33], [31, 42]], c1.darkened(0.25))
			p.line(21, 33, 23, 47, c1.darkened(0.35))
		"shirt", "floral", "polo":
			_torso(p, c1)
			if kind == "floral":
				var rng := RandomNumberGenerator.new()
				rng.seed = 99
				for i in 14:
					var fx := rng.randi_range(8, 40)
					var fy := rng.randi_range(36, 46)
					p.rect(fx, fy, 2, 2, c2 if i % 2 == 0 else c3)
					p.px(fx, fy, c3 if i % 2 == 0 else c2)
			p.poly([[18, 33], [23, 33], [21, 38]], c1.lightened(0.25) if kind == "polo" else c2)
			p.poly([[30, 33], [25, 33], [27, 38]], c1.lightened(0.25) if kind == "polo" else c2)
			p.line(24, 35, 24, 47, c1.darkened(0.25))
			if kind == "polo":
				p.rect(30, 39, 3, 2, c2)
		"tshirt":
			_torso(p, c1)
			p.ellipse(24, 33, 4.5, 2.2, skin.darkened(0.12))
		"tank":
			_torso(p, skin.darkened(0.05))
			p.poly([[15, 37], [18, 34], [20, 34], [21, 38], [27, 38], [28, 34], [30, 34], [33, 37], [35, 48], [13, 48]], c1)
		"hivis":
			_torso(p, c2)
			p.ellipse(24, 33, 4.5, 2.2, skin.darkened(0.12))
			p.poly([[7, 48], [8, 38], [12, 35], [19, 34], [21, 48]], c1)
			p.poly([[41, 48], [40, 38], [36, 35], [29, 34], [27, 48]], c1)
			p.hline(8, 20, 42, Color("#D9D9D9"))
			p.hline(28, 40, 42, Color("#D9D9D9"))
			p.hline(8, 20, 45, Color("#D9D9D9"))
			p.hline(28, 40, 45, Color("#D9D9D9"))
		"lifejacket":
			_torso(p, c2)
			p.poly([[7, 48], [8, 37], [13, 33], [21, 33], [22, 48]], c1)
			p.poly([[41, 48], [40, 37], [35, 33], [27, 33], [26, 48]], c1)
			p.hline(8, 40, 41, INK)
			p.hline(8, 40, 45, INK)
			p.rect(23, 40, 3, 3, Color("#C0C0C0"))
			p.rect(23, 44, 3, 3, Color("#C0C0C0"))
		"sequins":
			_torso(p, skin.darkened(0.05))
			p.poly([[11, 48], [12, 39], [16, 37], [32, 37], [36, 39], [37, 48]], c1)
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = 7
			for i in 30:
				p.px(rng2.randi_range(12, 36), rng2.randi_range(38, 47), c1.lightened(0.55) if i % 3 else Color.WHITE)
		"striped":
			_torso(p, c1)
			for y in range(35, 48, 3):
				p.hline(5, 43, y, c2)
			p.ellipse(24, 33, 4.5, 2.2, skin.darkened(0.12))
		"apron":
			_torso(p, c1)
			p.ellipse(24, 33, 4.5, 2.2, skin.darkened(0.12))
			p.poly([[16, 38], [32, 38], [33, 48], [15, 48]], c2)
			p.line(17, 38, 20, 33, c2)
			p.line(31, 38, 28, 33, c2)
		"uniform":
			_torso(p, c1)
			p.poly([[19, 33], [29, 33], [24, 42]], c2)
			p.poly([[20, 33], [28, 33], [24, 38]], c3)
			for y in [40, 45]:
				p.px(20, y, Color("#E0B000"))
				p.px(28, y, Color("#E0B000"))
		"vest":
			_torso(p, c2)
			p.poly([[7, 48], [8, 38], [12, 35], [18, 33], [23, 45], [23, 48]], c1)
			p.poly([[41, 48], [40, 38], [36, 35], [30, 33], [25, 45], [25, 48]], c1)
			p.poly([[20, 33], [24, 35], [20, 37]], INK)
			p.poly([[28, 33], [24, 35], [28, 37]], INK)
		"cardigan":
			_torso(p, c1)
			p.poly([[20, 33], [28, 33], [27, 48], [21, 48]], c2)
			for y in [38, 42, 46]:
				p.px(20, y, c1.lightened(0.4))
		_:
			_torso(p, c1)

## --- Rosto --------------------------------------------------------------------

static func _face(p: PortraitPainter, s: Dictionary, skin: Color, hair_color: Color) -> void:
	var dark := skin.darkened(0.55)
	var brow_color := hair_color if hair_color.get_luminance() < 0.6 else hair_color.darkened(0.4)
	# olhos (pálpebra + branco + íris) — "side" = olhar de canto pra direita
	var iris := Color(s["eye_color"])
	for base_x in [19, 27]:
		p.hline(base_x - 1, base_x + 3, 18, dark)
		p.rect(base_x, 19, 3, 2, EYE_WHITE)
		var ix: int = base_x + 2 if s["gaze"] == "side" else base_x + 1
		p.rect(ix, 19, 1, 2, iris)
		p.px(ix, 19, INK)
	# sobrancelhas
	match s["brows"]:
		"thick":
			p.hline(18, 22, 15, brow_color)
			p.hline(17, 22, 16, brow_color)
			p.hline(26, 30, 15, brow_color)
			p.hline(26, 31, 16, brow_color)
			p.px(22, 17, brow_color)
			p.px(26, 17, brow_color)
		"thin":
			p.hline(18, 21, 16, brow_color)
			p.hline(27, 30, 16, brow_color)
		_:
			p.hline(18, 22, 16, brow_color)
			p.hline(26, 30, 16, brow_color)
	# nariz: sombra do lado direito + narinas
	var shade := skin.darkened(0.2)
	p.rect(25, 20, 1, 3, shade)
	p.hline(23, 25, 23, shade)
	p.px(24, 23, skin)
	# idade
	if int(s["age"]) >= 2:
		p.px(17, 20, shade)
		p.px(31, 20, shade)
		p.hline(21, 23, 25, shade)
		p.hline(26, 27, 24, shade)
	# barba por baixo da boca
	match s["facial_hair"]:
		"beard":
			for y in range(23, 32):
				for x in range(13, 36):
					if PortraitPainter.in_ellipse(x, y, CX, CY, float(s["face_rx"]), FACE_RY) and (y >= 25 or x <= 16 or x >= 32):
						p.px(x, y, hair_color.darkened(0.1))
		"stubble", "shadow":
			# barba por fazer (pontilhada) ou só a sombra azulada de barba feita
			var amount := 0.22 if s["facial_hair"] == "stubble" else 0.0
			for y in range(24, 32):
				for x in range(13, 36):
					if not PortraitPainter.in_ellipse(x, y, CX, CY, float(s["face_rx"]), FACE_RY):
						continue
					var base := p.get_px(x, y)
					var c := base.lerp(Color("#5A6378"), 0.16)
					if amount > 0.0 and (x * 7 + y * 3) % 4 == 0:
						c = base.lerp(hair_color, amount + 0.12)
					p.px(x, y, c)
	# boca
	var mouth := dark
	if s["lips"] != "":
		var lips := Color(s["lips"])
		p.hline(21, 27, 26, lips)
		p.hline(22, 26, 27, lips.lightened(0.15))
		mouth = lips.darkened(0.35)
	match s["mouth"]:
		"smirk":
			p.hline(21, 26, 26, mouth)
			p.px(27, 25, mouth)
			p.px(28, 25, mouth)
		"smile":
			p.px(20, 25, mouth)
			p.hline(21, 27, 26, mouth)
			p.px(28, 25, mouth)
			p.hline(22, 26, 27, skin.darkened(0.08))
		_:
			p.hline(21, 27, 26, mouth)
	if s["facial_hair"] in ["mustache", "beard"]:
		p.hline(20, 28, 24, hair_color)
		p.hline(21, 27, 25, hair_color)
		p.px(24, 25, hair_color.darkened(0.2))
	if s["earrings"]:
		var rx: float = s["face_rx"]
		p.rect(int(CX - rx - 1), 23, 1, 2, Color("#E0B000"))
		p.rect(int(CX + rx), 23, 1, 2, Color("#E0B000"))

## --- Cabelo -------------------------------------------------------------------

## Até que linha (y) vai o cabelo em cada coluna — as laterais descem até a
## costeleta/ombro, o meio para na testa.
static func _hairline(style: String, x: int, rx: float) -> int:
	var side := x <= int(CX - rx + 1) or x >= int(CX + rx - 1)
	var temple := x <= int(CX - rx + 3) or x >= int(CX + rx - 3)
	match style:
		"side_part":
			if side: return 18
			if temple: return 13
			return 11
		"buzz":
			return 15 if side else 10
		"bald":
			return 18 if side else -1
		"long", "wig_long", "wig_volume":
			if side: return 34
			if temple: return 16
			return 13 if style != "long" else 11
		"curly":
			return 19 if side else 12
		_:
			return 17 if side else 11

static func _hair(p: PortraitPainter, style: String, c: Color, rx: float) -> void:
	if style == "":
		return
	var grow := 1.2
	if style == "curly":
		grow = 2.6
	elif style == "wig_volume":
		grow = 3.5
	var dark := c.darkened(0.22)
	var light := c.lightened(0.18)
	for y in range(0, 36):
		for x in range(0, 48):
			if not PortraitPainter.in_ellipse(x, y, CX, CY, rx + grow, FACE_RY + grow):
				continue
			if y > _hairline(style, x, rx):
				continue
			if style == "bald" and y < 13:
				continue
			var col := c
			if x > CX + rx * 0.45:
				col = dark
			elif y <= 10 and x > CX - 4 and x < CX + 3:
				col = light
			if style == "buzz":
				col = col.lerp(Color("#C8A88A"), 0.25)
			if style == "curly" and (x + y) % 3 == 0:
				col = dark
			p.px(x, y, col)
	match style:
		"side_part":
			# risca do lado esquerdo + topete pra direita
			p.line(19, 7, 18, 11, dark)
			p.ellipse(27, 8, 7, 3, c)
			p.hline(23, 30, 7, light)
		"bun":
			p.shaded_ellipse(24, 5.5, 4.5, 3.5, c)
		"wig_long", "wig_volume":
			# franja
			for x in range(int(CX - rx + 2), int(CX + rx - 1)):
				if x % 3 != 0:
					p.px(x, 13, dark)

## --- Chapéus ------------------------------------------------------------------

static func _headwear(p: PortraitPainter, kind: String, hc: Array, rx: float) -> void:
	if kind == "":
		return
	var c1: Color = hc[0]
	var c2: Color = hc[1] if hc.size() > 1 else c1.darkened(0.4)
	match kind:
		"fedora":
			p.ellipse(CX, 12.5, 16.5, 2.8, c1.darkened(0.12))
			p.poly([[14.5, 12], [16, 5], [19, 2.5], [29, 2.5], [32, 5], [33.5, 12]], c1)
			p.hline(20, 28, 3, c1.darkened(0.3))
			p.rect(15, 9, 19, 3, c2)
			p.darken_region(29, 2, 6, 10, 0.18)
		"panama":
			p.ellipse(CX, 12.5, 16, 2.6, c1.darkened(0.08))
			p.poly([[16, 12], [16.5, 6], [19, 4], [29, 4], [31.5, 6], [32, 12]], c1)
			p.rect(16, 9, 16, 2, c2)
			p.darken_region(28, 4, 5, 9, 0.15)
			for x in range(17, 31, 2):
				p.px(x, 6, c1.darkened(0.12))
		"cap", "cap_back":
			for y in range(4, 13):
				for x in range(12, 37):
					if PortraitPainter.in_ellipse(x, y, CX, 13, rx + 1.5, 8.5):
						p.px(x, y, c1 if x < CX + 5 else c1.darkened(0.15))
			if kind == "cap":
				p.ellipse(CX, 12.8, rx + 3.5, 1.8, c1.darkened(0.3))
				p.rect(22, 7, 5, 3, c2)
			else:
				p.hline(16, 32, 12, c1.darkened(0.3))
				p.rect(22, 9, 5, 2, c2)
		"helmet", "helmet_cam":
			for y in range(3, 31):
				for x in range(9, 40):
					if not PortraitPainter.in_ellipse(x, y, CX, 17, rx + 3.5, 14):
						continue
					if y >= 14 and PortraitPainter.in_ellipse(x, y, CX, 22, rx - 0.5, 10):
						continue
					p.px(x, y, c1 if x < CX + 6 else c1.darkened(0.2))
			p.rect(int(CX - rx), 10, int(rx * 2) + 1, 3, c2)
			p.hline(int(CX - rx) + 2, int(CX + rx) - 4, 10, c2.lightened(0.4))
			if kind == "helmet_cam":
				p.rect(21, 0, 7, 4, INK)
				p.rect(23, 1, 3, 2, Color("#5A5A5A"))
				p.px(24, 1, Color("#9AD0EC"))
		"sailor_cap":
			for y in range(5, 12):
				for x in range(13, 36):
					if PortraitPainter.in_ellipse(x, y, CX, 10, 11, 5):
						p.px(x, y, c1)
			p.rect(15, 11, 19, 2, c2)
			p.px(24, 8, Color("#E0B000"))
		"driver_cap":
			for y in range(5, 13):
				for x in range(12, 37):
					if PortraitPainter.in_ellipse(x, y, CX + 1, 11, 12, 6):
						p.px(x, y, c1 if x < CX + 6 else c1.darkened(0.15))
			p.hline(15, 33, 12, c2)
			p.hline(16, 31, 13, c2)

static func _glasses(p: PortraitPainter, kind: String) -> void:
	if kind == "":
		return
	var frame := INK if kind != "round" else Color("#6B4226")
	for base_x in [18, 26]:
		if kind == "sun":
			p.rect(base_x, 18, 5, 3, Color("#1A1A2E"))
			p.px(base_x + 1, 18, Color("#5A6A8A"))
		else:
			p.hline(base_x, base_x + 4, 18, frame)
			p.hline(base_x, base_x + 4, 21, frame)
			p.px(base_x, 19, frame)
			p.px(base_x, 20, frame)
			p.px(base_x + 4, 19, frame)
			p.px(base_x + 4, 20, frame)
	p.hline(23, 25, 19, frame)

## --- Objetos de mão / acessórios ---------------------------------------------------

static func _hand(p: PortraitPainter, x: float, y: float, skin: Color) -> void:
	p.shaded_ellipse(x, y, 3.2, 2.8, skin)

static func _prop(p: PortraitPainter, kind: String, skin: Color, cols: Array) -> void:
	match kind:
		"selfie_stick":
			p.line(38, 46, 43, 17, Color("#8A8A8A"))
			p.rect(40, 9, 7, 10, INK)
			p.rect(41, 10, 5, 7, Color("#5DADE2"))
			_hand(p, 38.5, 44, skin)
		"phone":
			_hand(p, 37, 45, skin)
			p.rect(33, 33, 8, 12, INK)
			p.rect(34, 34, 6, 9, Color("#4A90E2"))
			p.px(38, 35, Color("#E63946"))
		"golf_club":
			p.line(11, 46, 5, 16, Color("#C0C0C0"), 1)
			p.rect(2, 13, 5, 4, Color("#E0B000"))
			p.px(3, 13, Color("#FFF1A8"))
			_hand(p, 11, 44, skin)
		"pandeiro":
			p.ellipse(37, 40, 7, 7, Color("#8B5A2B"))
			p.ellipse(37, 40, 5.3, 5.3, Color("#F3E5C0"))
			for a in [[31, 40], [43, 40], [37, 34], [37, 46]]:
				p.rect(a[0], a[1], 2, 1, Color("#E0B000"))
			_hand(p, 42, 45, skin)
		"microphone":
			p.rect(35, 37, 3, 8, INK)
			p.shaded_ellipse(36.5, 35, 3, 3, Color("#A8A8A8"))
			p.px(35, 34, Color("#6A6A6A"))
			p.px(37, 35, Color("#6A6A6A"))
			_hand(p, 36.5, 44.5, skin)
		"thermal_bag":
			p.line(31, 33, 29, 47, INK, 2)
			p.line(17, 33, 19, 47, INK, 2)
		"shell_necklace":
			for x in range(19, 30):
				p.px(x, 34 + (1 if x > 21 and x < 27 else 0), Color("#FFFFFF") if x % 2 else Color("#F4A6B8"))
		"pochete":
			p.line(12, 35, 35, 44, Color("#222222"), 2)
			p.rect(27, 41, 11, 6, Color("#2E8B57"))
			p.hline(28, 36, 43, Color("#FFD100"))
		"name_tag":
			p.rect(30, 39, 7, 3, Color("#F4F1EA"))
			p.hline(31, 35, 40, Color("#8C8576"))
		"lanyard":
			var strap: Color = cols[2] if cols.size() > 2 else Color("#C8102E")
			p.line(20, 33, 23, 42, strap)
			p.line(28, 33, 25, 42, strap)
			p.rect(21, 42, 6, 5, Color("#F4F1EA"))
			p.rect(22, 43, 2, 2, Color("#8C8576"))
		"pin":
			p.rect(31, 38, 2, 2, Color("#E0B000"))
		"bowtie":
			p.poly([[20, 33], [24, 35], [20, 37]], INK)
			p.poly([[28, 33], [24, 35], [28, 37]], INK)
