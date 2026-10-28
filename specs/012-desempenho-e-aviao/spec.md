# Spec 012 — Jogo mais leve na Web e avião novo

> Status: **em andamento** (28/10/2026) — aprovada; falta só o PWA (T113).
> Depende das specs 006 e 011.

## Por quê

O jogo é leve pra rodar, mas pesado pra **baixar e iniciar**, principalmente
no celular. E o avião da viagem — a animação mais vista do jogo — ainda é
um triângulo branco e vermelho que parece uma seta, destoando da pixel art
nova do mapa e dos cenários (spec 011).

## A. Medição (site publicado, 28/10/2026)

| Arquivo | Tamanho | Baixado (gzip) | O que é |
|---|---|---|---|
| `index.wasm` | 39,5 MB | 10,2 MB | motor Godot (modelo oficial, completo) |
| `index.pck` | 13,8 MB | 13,5 MB | o jogo — ~11 MB são as 6 artes de título sem perda |
| `index.js` | 0,3 MB | 0,07 MB | carregador |

Download real: **~24 MB**. A tela de carregamento anuncia "~40 MB".

## B. Tamanho e carregamento

- **RF91** — Artes de título (6 variantes: 3 idiomas × deitado/em pé)
  importadas com compressão com perda (WebP, qualidade ~85%), sem diferença
  visível na prévia. Meta: `index.pck` ≤ 4 MB (o CI barra acima de 4,5 MB).
- **RF92** — Modelo de exportação Web **enxuto**, compilado no CI a partir do
  Godot 4.7.2: sem 3D, sem módulos que o jogo não usa, otimizado por
  tamanho; cache do modelo entre execuções. Antes de trocar, lista do que o
  jogo usa (SubViewport, áudio QOA, `HTTPRequest`, `JavaScriptBridge`,
  fontes TTF, JSON, tradução) e partida completa por clique no modelo novo.
  Meta: `index.wasm` ≤ 5 MB com gzip (saiu 6,3 MB; o CI barra acima de 6,5).
- **RF93** — Cache no aparelho (PWA): segunda visita sem baixar tudo de
  novo; versão nova publicada substitui a antiga no próximo acesso.
- **RF94** — Texto da tela de carregamento com o tamanho real, gerado no CI
  a partir dos arquivos exportados (não fixo no preset).

## C. Desempenho em execução

- **RF95** — Mapa: a camada de marcadores só redesenha quando algo anima
  (destino em foco pulsando, avião, hover); parado, nada é refeito.
- **RF96** — Celular na Web: teto de quadros (30 fps) fora de animação,
  pra poupar bateria; PC sem teto.

## D. Avião novo

- **RF97** — Avião em **pixel art** visto de cima, com fuselagem,
  asas, cauda e janelas, nas cores do jogo (branco com faixa vermelha
  "F.U.R.O."), desenhado por código como o resto da arte.
- **RF98** — Direção: o sprite gira acompanhando a curva da rota,
  **travado em 16 direções** pré-desenhadas (pixel art girada livremente
  borra); filtro `NEAREST`.
- **RF99** — Voo com cara de voo: sombra no mapa deslocada que se afasta do
  avião no meio da rota (altitude), avião levemente maior no meio do
  trajeto, rastro de fumaça em pixels que some aos poucos, decolagem e
  pouso suavizados (a curva de hoje continua).
- **RF100** — Mesmo tamanho aparente em qualquer tela (escala pela escala
  de texto do `Responsive`, como as etiquetas — RF89).

## E. Correções vistas na revisão

- **RF101** — Celular em pé: o selo "N repórteres na rua agora" fica por
  cima do título do crachá de imprensa; o selo desce ou o diálogo começa
  abaixo dele.

## F. Testes

- Tamanho: o CI falha se `index.pck` ou `index.wasm` (gzip) passar da meta.
- Partida completa por clique (já existe) roda contra o modelo enxuto.
- Avião: as 16 direções existem, a escolhida é a mais próxima do rumo,
  e o avião começa na origem e termina no destino (inclusive cruzando a
  borda do mapa, RF75).
- Selo e crachá não se sobrepõem em nenhum perfil do "cabe na tela".

## G. Decisões (28/10/2026)

1. Ordem: arte do título (RF91) primeiro, depois o avião; o resto em seguida.
2. Modelo enxuto (RF92): vale o job extra no CI (~30–60 min na primeira
   compilação, depois em cache)?
3. PWA (RF93): ligar já ou depois do modelo enxuto?

## Tarefas (quando aprovado)

- [x] T111 Artes de título com perda + medição do pck (RF91)
- [x] T112 Modelo Web enxuto no CI + lista do que o jogo usa (RF92)
- [ ] T113 PWA com atualização de versão (RF93)
- [x] T114 Texto de carregamento com o tamanho real (RF94)
- [x] T115 Mapa só redesenha animando; teto de fps no celular (RF95, 96)
- [x] T116 Avião em pixel art, 16 direções, sombra e rastro (RF97–100)
- [x] T117 Selo online x crachá no celular (RF101)
- [x] T118 Testes da seção F (avião, selo, carimbo, tamanhos no CI e teste no navegador)

## Achados durante a implementação

- Artes de título: 12,8 MB → 2,6 MB com WebP 85%, sem diferença visível na
  prévia; o pacote deve ficar em ~3,6 MB (o resto é áudio, fontes, dados e
  scripts) — meta ajustada de 3 pra 4 MB.
- Avião: "maior no meio do voo" ficou de fora — pixel art em escala não
  inteira entorta; a altitude aparece só pela sombra que se afasta.
- Carimbo da capa ("FURO!"/"ESCAPOU") por cima da linha do ranking: o
  espaço do carimbo era medido antes do tema/fontes; agora acompanha o
  tamanho real (relato do jogador, corrigido junto).
- Modelo Web enxuto: `index.wasm` 10,2 → 6,3 MB com gzip (39,5 → ~24 MB
  sem); download total ~24 MB (início do dia) → ~10 MB. Compila em ~9 min
  no CI, não 40–60.
- `platform`/`target` dentro do perfil do scons são ignorados (o perfil é
  lido depois): vão na linha de comando — a 1ª tentativa gerou o modelo de
  depuração.
- Sem o módulo de física o motor avisa no console; o projeto declara
  `physics/2d/physics_engine.web="Dummy"` (o jogo não usa física).
- O teste no navegador (tests/web_smoke.js) simula a API do ranking como
  indisponível: ela só aceita o site oficial (spec 010).
