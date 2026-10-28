# Spec 011 — Gráficos: mapa-múndi e cenário das cidades

> Status: **implementada** (28/10/2026) — decisões na seção F; entregue em
> duas partes (B primeiro).
> Depende das specs 001, 006 e 008.

## Por quê

O jogo funciona e tem identidade (jornal, pixel art, retratos), mas as
duas imagens que o jogador mais vê — o **cenário da cidade** e o
**mapa-múndi** — são as mais fracas visualmente e **deformam** conforme
a resolução. Esta spec corrige a proporção em qualquer tela e dá um salto
de qualidade nas duas artes, sem sair do "tudo desenhado por código".

## A. Diagnóstico (prévias de 1280×720, 844×390 e 390×844)

### A1. Esticamento

| Onde | O que acontece | Causa |
|---|---|---|
| Mapa deitado | O mundo (360°×138°, proporção 2,6) ocupa o quadro inteiro: em 844×390 o quadro é ~3,3 e os continentes ficam ~27% mais largos; em monitor 21:9 piora | `project()` escala x e y por fatores diferentes (`_view.size / size`) |
| Mapa em pé | Recorte já respeita a proporção (RF36), mas pode mostrar só oceano e borda reta do mundo | `_crop_view()` prende a janela dentro de `WORLD` |
| Cenário em pé | Céu enorme, prédios finos e altíssimos, marco gigante | Marco escala por `h / 150`, prédios têm largura fixa em px e altura proporcional ao chão |
| Cenário deitado baixo (844×390) | Marco minúsculo, faixa estreita de prédios | Mesma conta: altura pequena = marco pequeno |
| Ambos | "Pixel art" com círculos e linhas suavizados e tamanho de pixel diferente entre marco, prédio e sol | Desenha direto na resolução da tela; `PIXEL := 4` só vale pros prédios |

### A2. Acabamento

**Cenário**
- Prédios genéricos e iguais em toda cidade (só muda a cor da paleta);
  nada diz "Rio", "Cairo" ou "Sydney" além do marco.
- Marco pequeno e chapado (uma cor só, sem luz/sombra); em Brasília as
  cúpulas do Congresso quase somem atrás dos prédios.
- Marcos repetidos: `arch` em Madri, Nova Délhi e Berlim; `pagoda` em
  Tóquio e Pequim; `dome` em Washington e Budapeste; `burj` em Dubai e
  Santiago.
- Chão é uma faixa lisa; céu em faixas grossas, sem nuvem.

**Mapa**
- Contornos com poucos pontos: Itália, Índia, Sudeste Asiático, Caribe e
  Japão irreconhecíveis; faltam Antártida, Filipinas, Coreia, Sri Lanka,
  Nova Zelândia (só uma ilha), Taiwan, Indonésia.
- Continente chapado cor de papel com contorno grosso; oceano liso com
  grade; não conversa com o tema de jornal/mapa antigo.

## B. Proporção correta em qualquer tela

- **RF73** — O mapa usa **sempre a mesma escala nos dois eixos** (graus
  por pixel iguais em x e y), deitado ou em pé.
- **RF74** — Sobra de largura mostra **mais longitude**, com o mundo
  **dando a volta** (o mapa é repetido em x; Pacífico continua do outro
  lado). Sobra de altura mostra mais latitude (até a Antártida/Ártico) e,
  se ainda sobrar, oceano. O mundo inteiro (ou o recorte de RF36) sempre
  cabe: escala = a que encaixa o conteúdo, nunca a que corta.
- **RF75** — Rotas e o avião usam o caminho mais curto em longitude
  (Tóquio→Sydney não atravessa o mapa inteiro; Santiago→Sydney pode
  sair por um lado e entrar pelo outro, se for mais curto).
- **RF76** — O cenário da cidade é composto numa **tela virtual de pixel
  art** e ampliado por um **fator inteiro** com filtro `NEAREST`. Fator =
  maior inteiro que deixa pelo menos **100 px de arte** de altura e
  **130** de largura (3× no PC deitado, 2× no quadro em pé); sobra horizontal mostra mais cidade (prédios
  gerados pra largura virtual real), sobra vertical mostra mais céu, nunca
  estica. Prédios e marco têm tamanho em pixels de arte, não em fração do
  quadro.
- **RF77** — O marco tem **tamanho fixo em pixels de arte** e fica
  sempre inteiro e visível (centro, na frente dos prédios de fundo); em
  quadro muito estreito (em pé), o recorte acompanha o marco.
- **RF78** — Mesmo pixel em toda a cena: céu, astro, prédios, marco e
  chão desenhados na tela virtual — nada de linha/círculo suavizado com
  outro tamanho de pixel.
- **RF79** — Mudar o tamanho da janela ou girar o celular recompõe a cena
  e o mapa sem distorção (mesmo `resized` de hoje).

## C. Cenário das cidades mais bonito

- **RF80** — **Três planos com profundidade**: fundo (silhueta clara,
  perspectiva atmosférica), meio (marco + prédios da cidade), frente
  (rua/orla/vegetação com detalhes). Prédios ganham variação: telhado,
  antena, caixa d'água, toldo, recuo; luz de um lado e sombra do outro.
- **RF81** — **Terreno por cidade** em dado (`data/scenery.json`, por id
  de cidade; ver F3): tipo de chão (`plain`, `water`, `beach`, `desert`,
  `hills`, `mountains`, `river`), morros/montanhas de fundo, vegetação
  (palmeira, conífera, nenhuma), estilo dos prédios (`tower`, `colonial`,
  `low`, `mixed`). Ex.: Rio com morros e mar, Cidade do Cabo com a mesa,
  Cairo deserto, Amsterdã canal, Sydney baía, Santiago Andes.
- **RF82** — **Marcos redesenhados em pixel art** com 2–3 tons (luz,
  base, sombra) + contorno, no tamanho fixo de RF77, e **um marco próprio
  por cidade**: Berlim (Portão de Brandemburgo), Nova Délhi (Portão da
  Índia), Madri (Porta de Alcalá), Pequim (Templo do Céu), Budapeste
  (Parlamento), Santiago (Gran Torre + Andes) — os demais refeitos no
  novo padrão. Brasília: Congresso (cúpulas + torres) inteiro e legível.
- **RF83** — **Céu**: gradiente com pontilhado (dithering) em vez de
  faixas grossas; nuvens de pixel que andam devagar; estrelas e lua em
  pixel à noite; janelas acesas à noite em todos os planos.
- **RF84** — Animação leve opcional (nuvem, água, avião ao longe) que
  **não** consome o rng do caso (é arte; usa rng próprio — ver §2 do
  CLAUDE.md sobre replay) e respeita a opção de reduzir movimento, se
  existir.
- **RF85** — Mesma cidade = mesmo perfil sempre (semente pelo id, como
  hoje) e em qualquer resolução: a parte central da cena é idêntica; só
  as bordas revelam mais ou menos.

## D. Mapa-múndi mais bonito

- **RF86** — **Contornos novos** a partir do Natural Earth 1:110m (domínio
  público), simplificados por ferramenta guardada
  (`tools/build_world.gd` ou script equivalente) para `data/world.json`
  (ou continuar em `WorldShapes`, gerado). Inclui as ilhas que hoje
  faltam (A2) e a Antártida.
- **RF87** — Estilo de **mapa de jornal antigo / pixel**: terra em papel
  com sombra deslocada (relevo de "recorte"), litoral com contorno fino,
  oceano com textura de ondas em pixel e graticule discreta; opcional:
  rosa dos ventos num canto livre.
- **RF88** — Mapa **rasterizado** numa textura de pixel art (mesmo
  princípio de RF76/78) e ampliado com `NEAREST`; marcadores, etiquetas,
  rota e avião continuam desenhados por cima na resolução da tela
  (texto legível e nítido).
- **RF89** — Etiquetas e bandeiras com tamanho pela escala de texto do
  `Responsive` (hoje são 24 fixo), sem sobrepor (a lógica de `_placed`
  continua) e sem sair do quadro.
- **RF90** — Desempenho: mapa e cenário rasterizados **uma vez** por
  tamanho/cidade/hora (cache), não refeitos a cada quadro; o `_process`
  só redesenha a camada de marcadores/avião. Meta: sem queda de quadro no
  celular da build Web.

## E. Testes

- **Proporção** (RF73/76): para cada perfil do teste "cabe na tela"
  (spec 007) + 21:9 (2520×1080 → base expand) — mapa: `px por grau` em x
  igual ao de y (tolerância 1%); cenário: fator de escala inteiro e igual
  nos dois eixos.
- **Mapa inteiro visível** (RF74): deitado, toda cidade do jogo cai
  dentro do quadro em todos os perfis; em pé, origem + destinos + trilha
  cabem (como RF36).
- **Volta ao mundo** (RF75): rota entre cidades de lados opostos do
  antimeridiano escolhe o caminho mais curto.
- **Marco inteiro** (RF77): retângulo do marco dentro do quadro em todos
  os perfis e cidades.
- **Determinismo** (RF85): mesma cidade/hora gera a mesma imagem (hash da
  região central) em resoluções diferentes; o caso salvo e o replay não
  mudam (`CaseState` intacto) e a paridade com o servidor continua verde.
- **Dados** (RF81/82): toda cidade de `cities.json` tem entrada em
  `scenery.json` com valores válidos; todo `landmark` existe e nenhum é
  repetido.
- **Prévia**: `RenderPreview` gera cidade (dia e noite) e viagem nos três
  tamanhos — conferência visual de cada cidade (prévia extra com as 30
  cidades numa folha: `tools/build_skyline_sheet.gd`, como
  `build_portrait_sheet`).

## F. Decisões (28/10/2026)

1. **Resolução da arte**: pixel de arte = 3 px do jogo no PC deitado
   (altura de referência de 100 px de arte, RF76). A proposta original
   ("240 px") contava a tela inteira, não o quadro do cenário.
2. **Sobra no mapa deitado**: o mundo dá a volta (RF74).
3. **Terreno** em `data/scenery.json` separado — `cities.json` e a
   paridade com o servidor ficam intocados.
4. **Arte por código**, com override opcional por PNG em
   `assets/skylines/` (mesmo mecanismo dos retratos).
5. **Animação leve** (nuvens e água) incluída — RF84.
6. **Duas partes**: B (proporção) primeiro; C/D (arte nova) depois.

## Achados durante a implementação

- O fator do cenário só pela altura deixava o marco espremido em quadro
  estreito e alto: o fator também respeita uma largura mínima (RF76).
- A prévia decidia a orientação pelo tamanho real da janela, que no Windows
  com HiDPI vem diferente do pedido: agora força pela medida pedida.
- Os marcos repetidos (RF82) trocaram de nome no `cities.json` (um id por
  cidade, ex.: `twin` → `congress`). O servidor não lê `landmark`: os
  vetores de paridade regerados não mudaram.
- O cache do céu era esvaziado com texturas ainda em uso (30 cenários na
  folha de revisão) e o céu saía branco: cada cenário segura a sua.
- `resized` não dispara quando o tamanho é dado antes de entrar na árvore:
  o fator também é calculado no `_ready`.
- No celular deitado (844×390) o quadro do cenário tem ~170 px do jogo e
  fica em fator 1 — sem esticar, mas com pixel mais fino que no PC.
- Estilo `tower` alto demais escondia o marco: alturas reduzidas, e Brasília
  usa `low` (superquadras).
- Mapa: o Natural Earth 1:110m (127 polígonos) vira 100 terras + o Cáspio
  (buraco) e ~2 mil pontos em `data/world.json`; ilhas abaixo de 0,8 grau²
  somem. O arquivo de origem não fica no repositório (a ferramenta diz de
  onde baixar). A rosa dos ventos ficou no canto de baixo à esquerda.

## Tarefas

- [x] T100 Mapa com escala igual nos eixos e volta ao mundo (RF73–75, 79)
- [x] T101 Cenário em tela virtual com fator inteiro e marco fixo (RF76–79)
- [x] T102 Testes de proporção, volta ao mundo e marco inteiro (seção E)
- [x] T103 `data/scenery.json` (só ids, sem texto a traduzir) + teste de dados (RF81)
- [x] T104 Planos, prédios por estilo, terreno e céu novos (RF80, 83, 85)
- [x] T105 Marcos redesenhados e únicos por cidade (RF82)
- [x] T106 Ferramenta de contornos Natural Earth → dados do mapa (RF86)
- [x] T107 Estilo novo do mapa rasterizado + cache (RF87, 88, 90)
- [x] T108 Etiquetas pela escala do `Responsive` (RF89)
- [x] T109 Animação leve: nuvens e água (RF84)
- [x] T110 `tools/build_skyline_sheet.gd` (folha de dia e de noite) + prévias atualizadas
