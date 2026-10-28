# Onde Está Flávio Bolsonaro? — guia do projeto

Jogo de investigação/geografia estilo *Carmen Sandiego*, em tom de paródia,
feito em **Godot 4.7.2 (GDScript)** reaproveitando a engine e os padrões do
projeto PPKMN (jogo anterior do autor). Desenvolvido com **SDD** (spec-driven
development): toda feature nova começa por uma spec em `specs/NNN-nome/`.

## 1. Fluxo SDD

1. `specs/NNN-nome/spec.md` — o quê e por quê (histórias, RFs, aceite).
2. `specs/NNN-nome/plan.md` — como (arquitetura, dados, decisões).
3. `specs/NNN-nome/tasks.md` — tarefas numeradas ligadas aos requisitos.
4. Implementar marcando `[x]` nas tarefas; testes verdes antes de fechar.

Spec base: [specs/001-jogo-base](specs/001-jogo-base/spec.md).

## 2. Comandos

Godot 4.7.2 instalado localmente — caminho em `CLAUDE.local.md` (fora do
git); abaixo, `godot`.

```
godot --headless --path . --import                         # reimporta assets / cache de classes
godot --headless --path . --script res://tests/run_tests.gd # testes da lógica
godot --headless --path . res://tests/UiTests.tscn         # testes de interface (cliques reais)
godot --headless --path . --script res://tools/build_audio.gd  # regera música/SFX
godot --headless --path . --script res://tools/build_icon.gd   # regera ícone
godot --headless --path . --script res://tools/build_portrait_sheet.gd  # build/portraits.png com todos os retratos
godot --path . --script res://tools/build_skyline_sheet.gd      # build/skylines_day|night.png com todos os cenários (precisa de janela)
godot --headless --path . --script res://tools/build_world.gd -- <ne_110m_land.geojson>  # contornos do mapa em data/world.json
node tests/web_smoke.js <url> <saída>  # joga a versão Web num navegador (Playwright; o CI roda no build)
godot --headless --path . --script res://tools/build_og.gd    # imagem de compartilhamento (assets/web/og.jpg)
godot --path . res://tools/RenderPreview.tscn              # PNG de cada tela em build/preview/<idioma>/<tamanho>/
godot --headless --path . --export-release "Windows Desktop" build/OndeEstaFlavio.exe
```

A versão Web exporta com um modelo enxuto compilado no CI
(`tools/web_template/custom.py`: sem 3D, só os módulos usados). Recurso
novo do motor (módulo, formato de imagem/áudio) tem que entrar no perfil —
o teste no navegador do build acusa o que faltar.

Scripts com `extends SceneTree` (`--script`) não enxergam autoloads; quem
precisa de `GameManager`/`AudioManager` roda como cena (ver RenderPreview).
Ferramentas que rodam o jogo devem ligar `SaveService.read_only = true` pra
não gravar por cima dos saves reais. Edite arquivos com as ferramentas de
arquivo ou bash — o PowerShell 5 corrompe UTF-8 (há teste que acusa).

Persistência: carreira, opções e caso em andamento ficam em `user://`
(`onde_esta_flavio_*.json`); o caso é salvo como semente + ações e refeito
por replay (`CaseState.to_save/from_save`), então todo rng consumido fora
de ação tem que usar `_sub_rng()`.

## 2b. Servidor (ranking e contador online) — `server/`

Cloudflare Worker em TypeScript (spec 006-B). O núcleo do jogo é portado
em `server/src/engine/` e **tem que bater bit a bit** com o GDScript:
qualquer mudança em `scripts/core/` ou `data/` exige regerar os vetores
(`godot --headless --path . --script res://tools/export_parity.gd`) e
rodar `npm test` em `server/` (o CI confere as duas coisas). Ordem dos
sorteios importa — inclusive `dict[chave] = valor` (o GDScript avalia o
valor antes da chave).

```
cd server && npm test                 # paridade com o Godot + API
cd server && npx wrangler deploy --dry-run --outdir /tmp/w   # empacota sem publicar
```

Deploy só pelo workflow `api.yml` (secrets `CLOUDFLARE_API_TOKEN` e
`CLOUDFLARE_ACCOUNT_ID`). Plano grátis: o servidor dosa o intervalo do
contador pra não passar de 100 mil requisições/dia (`presence.ts`).
No jogo, `Online` (autoload) desliga sozinho em `res://tests` e
`res://tools`; testes simulam respostas com `Online.mock`.

## 3. Arquitetura (resumo — detalhe em plan.md)

- `scripts/core/` — lógica pura, sem nó: `CaseGenerator` sorteia,
  `CaseState` aplica as regras (investigar/viajar/pauta), `ClueBuilder`
  monta falas, `GameClock`, `Dossier`, `Career`, `SaveService`, `GameData`.
  Regra de jogo nunca mora em tela.
- `scripts/autoload/` — `GameManager` (estado + troca de tela por sinal),
  `AudioManager` (música/SFX por nome).
- `scripts/screens/` — uma tela por cena; `Main` troca com fade.
- `scripts/ui/` — `UiTheme` (tema único), `Palette`, componentes com API
  própria (`NewsHeader`, `WitnessBox`, `NewspaperPage`, painéis).
- `scripts/art/` — tudo desenhado por código: cenário (`SkylineView`, pixel
  art em SubViewport com fator inteiro; terreno/estilo em
  `data/scenery.json`) + marcos (`SkylineLandmarks`, um por cidade), mapa-múndi,
  retratos 48x48 (`PortraitPainter` primitivas, `PortraitFactory` camadas,
  `PixelPortrait` fachada com cache e override por `assets/portraits/`).
  Figurinos são dados: `disguises.json` (`portrait`) e `flavor.json`
  (`locations.*.outfit`).
- `data/*.json` — todo o conteúdo (cidades, disfarces, falas, alvos em
  `targets.json` — o Flávio e os parceiros da spec 009; o servidor lê o
  mesmo arquivo). Cidade nova =
  entrada em `cities.json` + `scenery.json` + marco próprio em
  `SkylineLandmarks` (os testes exigem um marco por cidade).

## 4. Convenções

- Conteúdo/texto: conferir [LORE.md](LORE.md) (tom e limites da sátira).
- Idiomas (spec 008, pt/en/es): texto de interface vai em
  `data/i18n/ui.csv` com o português como chave (botão/label com texto fixo é
  traduzido sozinho; texto montado com % passa por `Lang.t()`). Dados
  traduzidos em `data/i18n/<idioma>/` com os mesmos ids e listas do mesmo
  tamanho (os sorteios dependem disso). O caso guarda ids/índices, nunca
  texto. Texto novo sem tradução quebra os testes.
- Layout montado em código a partir de componentes; `.tscn` só com raiz +
  script.
- Cores só de `Palette`; estilo só via `UiTheme` (nada de StyleBox solto).
- Fontes: Pixelify Sans Bold (títulos/botões), VT323 (texto), Press Start 2P
  só em logotipo sem acento ("O FURO", "F.U.R.O.") — os acentos maiúsculos
  dela somem.
- Celular (spec 006): telas montam o arranjo por `Responsive` (orientação,
  alvo de toque de 48 px reais, escala de texto). O teste "cabe na tela"
  simula PC e celular de 360 px; layout novo tem que passar nele.
- Pixel art com `TEXTURE_FILTER_NEAREST`; arte do título é a exceção
  (ilustração, filtro linear).
- Ferramentas de asset ficam em `tools/build_*.gd`, guardadas e rodáveis.
- Mesmo cuidado de qualidade do PPKMN: SOLID pragmático, sem duplicação,
  dado dirigido.
- Automação de tela: nunca mandar tecla para janela sem confirmar o foco
  (incidente do PPKMN). A prévia por PNG não envia tecla nenhuma.
