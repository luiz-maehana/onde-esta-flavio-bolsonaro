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
godot --headless --path . --script res://tools/build_og.gd    # imagem de compartilhamento (assets/web/og.jpg)
godot --path . res://tools/RenderPreview.tscn              # PNG de cada tela em build/preview/
godot --headless --path . --export-release "Windows Desktop" build/OndeEstaFlavio.exe
```

Scripts com `extends SceneTree` (`--script`) não enxergam autoloads; quem
precisa de `GameManager`/`AudioManager` roda como cena (ver RenderPreview).
Ferramentas que rodam o jogo devem ligar `SaveService.read_only = true` pra
não gravar por cima dos saves reais. Edite arquivos com as ferramentas de
arquivo ou bash — o PowerShell 5 corrompe UTF-8 (há teste que acusa).

Persistência: carreira, opções e caso em andamento ficam em `user://`
(`onde_esta_flavio_*.json`); o caso é salvo como semente + ações e refeito
por replay (`CaseState.to_save/from_save`), então todo rng consumido fora
de ação tem que usar `_sub_rng()`.

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
- `scripts/art/` — tudo desenhado por código: skyline + marcos, mapa-múndi,
  retratos 48x48 (`PortraitPainter` primitivas, `PortraitFactory` camadas,
  `PixelPortrait` fachada com cache e override por `assets/portraits/`).
  Figurinos são dados: `disguises.json` (`portrait`) e `flavor.json`
  (`locations.*.outfit`).
- `data/*.json` — todo o conteúdo (cidades, disfarces, falas). Cidade nova =
  entrada em `cities.json` (+ marco novo em `SkylineLandmarks` se precisar).

## 4. Convenções

- Conteúdo/texto: conferir [LORE.md](LORE.md) (tom e limites da sátira).
- Layout montado em código a partir de componentes; `.tscn` só com raiz +
  script.
- Cores só de `Palette`; estilo só via `UiTheme` (nada de StyleBox solto).
- Fontes: Pixelify Sans Bold (títulos/botões), VT323 (texto), Press Start 2P
  só em logotipo sem acento ("O FURO", "F.U.R.O.") — os acentos maiúsculos
  dela somem.
- Pixel art com `TEXTURE_FILTER_NEAREST`; arte do título é a exceção
  (ilustração, filtro linear).
- Ferramentas de asset ficam em `tools/build_*.gd`, guardadas e rodáveis.
- Mesmo cuidado de qualidade do PPKMN: SOLID pragmático, sem duplicação,
  dado dirigido.
- Automação de tela: nunca mandar tecla para janela sem confirmar o foco
  (incidente do PPKMN). A prévia por PNG não envia tecla nenhuma.
