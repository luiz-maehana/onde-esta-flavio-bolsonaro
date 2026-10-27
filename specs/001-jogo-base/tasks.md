# Tarefas — Spec 001

> Fase 3 do SDD. Cada tarefa referencia o requisito que atende. Marcar `[x]`
> ao concluir.

## Fase A — Fundação
- [x] T01 Baixar fontes OFL (Press Start 2P, VT323) — RNF05
- [x] T02 Mover arte de título para `assets/ui/title_background.png` — US1
- [x] T03 `project.godot`, autoloads, preset de export com pck embutido — RNF01/02/06
- [x] T04 `Palette` + `UiTheme` (identidade jornal) — §6 spec

## Fase B — Conteúdo (dados)
- [x] T05 `data/cities.json` (20 cidades com pistas) — RF04, RNF03
- [x] T06 `data/disguises.json` (características + 8 disfarces) — RF05/08
- [x] T07 `data/flavor.json` (motivos, imprevistos, falas, manchetes, cargos) — RF06/09/10/11

## Fase C — Núcleo (lógica pura)
- [x] T08 `GameData` (carrega/valida JSON)
- [x] T09 `GameClock` — RF02
- [x] T10 `Dossier` — RF08
- [x] T11 `CaseGenerator` + `CaseState` — RF01/04/05/07
- [x] T12 `ClueBuilder` — RF03/04/05/06/09/10
- [x] T13 `Career` + `SaveService` — RF11, US2
- [x] T14 `tests/run_tests.gd` verde — RNF04, aceite 3

## Fase D — Arte procedural
- [x] T15 `SkylineView` — US4
- [x] T16 `WorldMapView` + animação de avião — US6
- [x] T17 `Portrait` (senador + testemunhas) — US4/US9

## Fase E — Telas
- [x] T18 `Main` + `GameManager` (fluxo de telas)
- [x] T19 `TitleScreen` (arte, nome, carreira, aviso de paródia) — US1/US2
- [x] T20 `BriefingScreen` (manchete) — US3
- [x] T21 `CityScreen` + `InvestigatePanel` + `WitnessBox` — US4/US5/US7
- [x] T22 `DossierPanel` — US8
- [x] T23 `TravelScreen` — US6
- [x] T24 `EndScreen` (capa de jornal) — US9

## Fase F — Áudio e entrega
- [x] T25 `tools/build_audio.gd` + `AudioManager` — US10
- [x] T26 `tools/build_icon.gd` (ícone do exe)
- [x] T27 Export `build/OndeEstaFlavio.exe` e teste de fumaça — aceite 1
- [x] T28 `CLAUDE.md`, `LORE.md`, `README.md`
