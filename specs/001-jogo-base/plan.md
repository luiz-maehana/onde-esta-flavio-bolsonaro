# Plano técnico — Spec 001

> Fase 2 do SDD: **como**. Requisitos referenciados por ID (RFxx/RNFxx) de
> [spec.md](spec.md).

## 1. Engine reaproveitada do PPKMN

Mesma base do projeto PPKMN, jogo anterior do autor (Godot 4.7.2), com os mesmos
padrões:

| Padrão do PPKMN | Uso aqui |
|-----------------|----------|
| `Main.gd` troca cena num container ouvindo sinais do `GameManager` | idem, com as telas do jogo |
| Autoload `GameManager` (estado + sinais) | dono do caso em andamento e da carreira |
| Autoload `AudioManager` (`play_music`/`play_sfx`, loop de WAV) | copiado quase igual |
| `UiTheme` estático (estilo compartilhado de painel/botão) | reescrito com a identidade "jornal" |
| `DialogueBox` (uma linha por vez, seta piscando, sinal `finished`) | base do `WitnessBox` |
| `SaveService` (JSON em `user://`, `.get()` defensivo) | salva só a carreira |
| `tools/build_*.gd` headless e guardados | `build_audio.gd`, `build_icon.gd` |
| Preset de export "Windows Desktop" | idem, com `embed_pck=true` (RNF02) |

## 2. Estrutura de pastas

```
data/            cities.json, disguises.json, flavor.json      (RNF03)
assets/fonts/    Press Start 2P, VT323 (+ OFL)
assets/ui/       title_background.png (arte do usuário)
assets/audio/    music/*.wav, sfx/*.wav (gerados por tools/build_audio.gd)
scripts/
  autoload/      GameManager.gd, AudioManager.gd
  core/          lógica pura, sem nó/cena (RNF04)
    GameData.gd       carrega e valida JSON
    GameClock.gd      horas, sono, prazo (RF02)
    CaseGenerator.gd  rota, iscas, disfarce, plano de pistas (RF01/04/05/07)
    CaseState.gd      estado mutável do caso em andamento
    ClueBuilder.gd    texto das testemunhas (RF03/04/05/06/09)
    Dossier.gd        filtro de disfarces (RF08)
    Career.gd         cargos (RF11)
    SaveService.gd    persistência da carreira
  ui/            UiTheme.gd, Palette.gd, componentes reutilizáveis
  art/           desenho procedural (skyline, mapa, retratos)
  screens/       uma por tela; Main.gd
scenes/          .tscn mínimos (nó raiz + script); layout montado em código
tests/           run_tests.gd (headless)
tools/           build_audio.gd, build_icon.gd
```

Decisão: as telas montam o layout em código a partir de componentes
(`UiTheme.make_button`, `NewsHeader`, `WitnessBox`…), não em `.tscn` grandes —
evita arquivo de cena gigante escrito à mão e deixa cada componente com API
própria (métodos + sinais), como `BattleHud`/`PartyBox` no PPKMN.

## 3. Modelo de dados

**cities.json** — `[{id, name, country, lon, lat, coastal, landmark,
palette:[céu, prédios, destaque], description, clues:[...]}]`. `clues` são
frases completas que descrevem *aquela* cidade ("Perguntou quanto vale um
dirham…"). Ao estar na cidade *i*, as testemunhas sorteiam `clues` da cidade
*i+1*.

**disguises.json** — `traits: {hat:[…], ride:[…], hobby:[…], snack:[…]}` com o
texto de cada valor e frases de testemunha; `disguises: [{id, name, hat,
ride, hobby, snack, reveal}]`. Combinações únicas (validado em teste).

**flavor.json** — motivos de fuga, imprevistos, falas por local (aeroporto,
hotel…), frases de "cidade errada", "ele está perto", manchetes de vitória e
derrota, cargos.

## 4. Lógica central

- **GameClock**: `hours` desde seg 00:00; começa em 9; prazo = 6·24+17 = 161.
  `advance(h)`: soma; se a hora do dia passar de 23 ou cair antes de 7,
  empurra para 07:00 do dia seguinte e reporta que dormiu.
- **CaseGenerator.generate(rng, rank)**: sorteia rota sem repetir; para cada
  parada não final sorteia 3 locais (Porto só se `coastal`) e 3 iscas (cidades
  fora da rota); escolhe disfarce; distribui as 4 características pelas
  paradas, garantindo que o conjunto revelado identifica 1 só disfarce
  (`Dossier.matching(revealed).size() == 1`). Recebe `RandomNumberGenerator`
  para ser determinístico em teste.
- **CaseState**: índice da parada certa, cidade atual, se está fora da trilha,
  visitas por cidade, pauta emitida, anotações.
- **ClueBuilder**: monta a fala da testemunha a partir de CaseState + flavor.
- **Dossier.matching(selected: Dictionary)**: filtra disfarces.

## 5. Telas e fluxo

```
Title ──(Novo caso)──► Briefing ──► City ◄──► Travel
  ▲                                  │ ├─ InvestigatePanel → WitnessBox
  │                                  │ └─ DossierPanel
  └────────────── End ◄──────────────┘ (captura / prazo / fuga)
```

`GameManager` emite `screen_requested(name)` e `Main` instancia a cena
correspondente — telas não se conhecem.

## 6. Arte

- Título: `title_background.png` em `TextureRect` com *cover*, faixa escura
  inferior com menu e aviso de paródia.
- **SkylineView** (`_draw`): céu em gradiente pela hora do relógio
  (madrugada/dia/pôr do sol/noite), sol/lua, silhueta de prédios com semente
  por cidade, janelas acesas à noite e um marco desenhado por tipo
  (`tower`, `dome`, `pyramid`, `statue`, `wheel`, `spire`, `sails`, `arch`,
  `pagoda`, `twin`).
- **WorldMapView** (`_draw`): continentes como polígonos lon/lat simplificados
  (projeção equiretangular), pontos das cidades, arco tracejado e avião
  animado na viagem.
- **Portrait**: retratos em pixel art a partir de mapas ASCII (o senador em
  sobretudo vermelho e fedora, coerente com a arte de título) e testemunhas
  procedurais (pele/cabelo/roupa sorteados por local).
- Ícone do exe: gerado por `tools/build_icon.gd` (fedora + "?").

## 7. Áudio

`tools/build_audio.gd` sintetiza (WAV 16-bit mono 22050 Hz, mesma técnica de
`build_sfx.gd` do PPKMN): trilha de título (baixo caminhante em menor, clima
"espião"), trilha de investigação, e SFX `click`, `type`, `clue`, `plane`,
`sleep`, `pauta`, `win`, `lose`, `alert`.

## 8. Testes (RNF04)

`tests/run_tests.gd` (headless, `extends SceneTree`): validação dos JSON,
relógio/sono/prazo, 500 casos gerados (rota sem repetição, iscas fora da rota,
disfarce identificável), filtro do dossiê, cargos.

```
godot --headless --path . --script res://tests/run_tests.gd
```

## 9. Build

```
godot --headless --path . --export-release "Windows Desktop" build/OndeEstaFlavio.exe
```
