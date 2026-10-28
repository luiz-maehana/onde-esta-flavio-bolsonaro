# Spec 008 — Idiomas (pt, en, es) e revisão de espaçamento

> Status: **implementada** (28/10/2026).
> Depende das specs 001–007.

## Por quê

O jogo é só em português. Com a versão Web e o ranking online, quem chega
pelo link em inglês ou espanhol não consegue jogar. As artes do título em
inglês e espanhol já existem (horizontal e vertical de cada).

No celular, algumas telas têm botões com mais espaço de um lado que do
outro (fileiras alinhadas à esquerda ou à direita, grades que não ocupam a
largura). Fica com cara de desalinhado.

## A. Idioma nas opções

- **RF42** — Opções ganham a linha **IDIOMA** com três botões: PORTUGUÊS,
  ENGLISH, ESPAÑOL (cada um escrito no próprio idioma). Trocar aplica na
  hora: a tela atual é remontada no idioma novo (mesmo mecanismo de girar o
  aparelho, `Main`), sem perder caso, relógio, dossiê ou anotações.
- **RF43** — Primeira vez: idioma do sistema/navegador (`OS.get_locale()`).
  `pt*` → português, `es*` → espanhol, qualquer outro → inglês (ver E1).
  Depois disso vale o que o jogador escolheu, salvo em `Settings`
  (`language`), sanitizado como os outros campos.
- **RF44** — Título usa a arte do idioma e da orientação:

  | Idioma | Deitado (1672×941) | Em pé (941×1672) |
  |---|---|---|
  | pt | `title_background.png` | `title_background_portrait.png` |
  | en | `title_background_en.png` | `title_background_portrait_en.png` |
  | es | `title_background_es.png` | `title_background_portrait_es.png` |

  Arquivos de origem (hoje soltos na raiz):
  - en deitado: `Onde Está Flávio_ Mistério Brasileiro.png`
  - en em pé: `Onde Está Flávio Bolsonaro_ (2).png`
  - es deitado: `Mistério Político no Rio de Janeiro.png`
  - es em pé: `Onde Está Flávio Bolsonaro_ (3).png`

## B. Todo texto do jogo traduzido

Inventário atual: ~220 textos no código (botões, títulos, avisos, dicas
da interface) e ~750 nos dados (~4.500 palavras: cidades e pistas 2.200,
disfarces 660, enfeites 590, escândalos 880, conquistas 110).

- **RF45** — Textos da interface (código) saem dos scripts para um catálogo
  por idioma, com o texto em português como chave (`tr()` do Godot,
  arquivo `.po`/`.csv` em `data/i18n/`). Nenhum texto visível fica
  escrito direto no código; teste acusa.
- **RF46** — Textos dos dados: o português continua em `data/*.json`
  (fonte da verdade, ids e estrutura); cada idioma tem
  `data/i18n/<idioma>/*.json` só com os textos, nos **mesmos ids e com as
  listas do mesmo tamanho**. `GameData` entrega o texto no idioma atual.
- **RF47** — O caso guarda **índices**, não textos. Hoje o `CaseState`
  guarda o texto sorteado (pistas da rota, motivo, esconderijo, falas e
  anotações). Isso passa a ser índice nas listas e o texto é montado na
  hora de mostrar, no idioma atual. Consequências:
  - os sorteios não mudam (só dependem do tamanho das listas): saves
    antigos continuam valendo e a paridade com o servidor continua bit a
    bit (vetores regerados, `npm test` verde);
  - trocar de idioma no meio do caso traduz até as anotações já feitas;
  - um save começado em português pode ser retomado em espanhol.
- **RF48** — Formatos por idioma: dias da semana, hora em 24 h (pt "17h",
  en/es "17:00"), plural ("1 caso"/"2 casos"), gênero
  ("Estagiário(a)" → "Intern"/"Becario(a)"). Marcadores das manchetes
  (`{city}`, `{spot}`, `{player}`) iguais em todos os idiomas.
- **RF49** — Boxes "Entenda o caso" (fato real): tradução fiel, sem
  suavizar nem agravar; o **status da apuração** traduzido literalmente
  (investigado / arquivado / sem decisão), veículo e links originais.
  Mesmos limites do [LORE](../../LORE.md): investigação não é condenação.
- **RF50** — Ranking online: o servidor passa a mandar o **índice do
  cargo** (além do título em português, pra não quebrar versão antiga) e
  o cliente mostra o cargo no idioma do jogador. "Repórter Anônimo" (apelido
  recusado) também é traduzido no cliente. Apelidos dos jogadores não são
  traduzidos.
- **RF51** — Fontes: Pixelify Sans, VT323 e Press Start 2P conferidas para
  ¿ ¡ ñ Ñ ü e acentos do espanhol (`tools/check_fonts.gd` passa a cobrir
  as três fontes e os caracteres de todos os idiomas).
- **RF52** — Nome da janela/aba por idioma (`config/name_localized`).

## C. Revisão de espaçamento (principalmente celular)

Achados nas prévias de 390×844 e 844×390:

| Tela | O que acontece |
|---|---|
| Título em pé | Grade de 2 colunas com largura fixa (320): sobra espaço só à direita |
| Opções em pé | Linhas TEXTO, DICAS e RANKING com botões de largura fixa alinhados à esquerda |
| Capa, briefing, carreira, ranking | Botões de ação alinhados à direita: em pé ficam todos de um lado |
| Dossiê | Botões de cada característica quebram linha com a última fileira "torta" |
| Fala da testemunha | CONTINUAR à direita (ok deitado; em pé pode ocupar a largura) |

- **RF53** — Em pé (e no celular deitado, quando a fileira quebra linha),
  fileiras e grades de botões **ocupam a largura toda** com colunas
  iguais; botão sozinho numa linha fica centralizado ou na largura toda.
  Margens laterais iguais nos dois lados da tela.
- **RF54** — Teste de **simetria**: em cada tela e overlay, em todos os
  perfis de aparelho do teste "cabe na tela" (spec 007) e nos três
  idiomas, a margem esquerda e a direita do conteúdo diferem no máximo
  4 px; fileiras de botões em pé não deixam sobra de um lado só.
- **RF55** — Textos em inglês/espanhol tendem a ser mais longos (espanhol
  ~20–30%): o teste "cabe na tela" e o de simetria rodam nos três
  idiomas, com os textos mais longos de cada um.

## D. Testes

- Catálogo completo: toda chave da interface existe nos três idiomas e
  nenhuma tradução está vazia.
- Dados: todo id do português existe em en/es; listas do mesmo tamanho;
  mesmos marcadores; nenhum campo sobrando.
- Nenhum texto visível em português com o jogo em en/es (macaco e partida
  por clique rodam em en e es e conferem os textos na tela contra uma lista
  de palavras típicas do português — heurística, com exceções: nomes
  próprios, "PASTEL", nome do jornal).
- Trocar de idioma no meio do caso: estado igual, textos no idioma novo.
- Save começado em pt retomado em es: mesmo estado.
- Paridade com o servidor intacta (vetores regerados não mudam).
- RF53/54: simetria e "cabe na tela" nos 3 idiomas × 4 perfis.
- Prévia (`RenderPreview`) gera cada tela por idioma e tamanho.

## E. Decisões (28/10/2026)

1. Primeira vez: idioma do navegador/sistema (pt → pt, es → es, resto → en).
2. "O FURO" / "F.U.R.O." ficam como nome próprio em todos os idiomas; só a
   explicação da sigla é traduzida.
3. Artes aceitas como estão (en vertical sem acento em "FLAVIO").
4. Tradução completa feita aqui, sem etapa de revisão externa.
5. Hora sempre em 24 h: pt "17h" (como hoje), en/es "17:00".
6. Página Web (descrição e imagem de compartilhamento) segue em português;
   só o título da aba muda com o idioma.

## Achados durante a implementação

- O "●" do selo de online não existia em nenhuma fonte (no navegador virava
  quadradinho, já em português): agora é desenhado.
- Título do box factual não quebrava linha: em inglês vazava da tela em pé.
- Título do escândalo no meio da frase ia todo pra minúscula ("lago sul"):
  agora só a primeira letra.
- Sem coluna pt no catálogo, o Godot caía no inglês: fallback = pt_BR.

## Tarefas (quando aprovado)

- [x] T73 Mover as 4 artes pra `assets/ui/` com nomes por idioma; título
  escolhe por idioma e orientação (RF44)
- [x] T74 Infra de idioma: `Settings.language`, detecção do sistema,
  linha IDIOMA nas Opções, remontagem da tela ao trocar (RF42, RF43)
- [x] T75 Catálogo da interface: tirar textos dos scripts, `tr()`, teste
  de chave faltando (RF45)
- [x] T76 Caso por índices em vez de textos — GDScript e porte TS, vetores
  regerados, saves antigos válidos (RF47)
- [x] T77 Dados por idioma: `data/i18n/en|es`, `GameData` por idioma,
  testes de estrutura (RF46, RF48)
- [x] T78 Tradução en + es de todo o conteúdo; boxes factuais com cuidado
  (RF49)
- [x] T79 Ranking: índice do cargo na API e cargo/anônimo traduzidos no
  cliente (RF50)
- [x] T80 Fontes e nome da janela (RF51, RF52)
- [x] T81 Espaçamento: fileiras/grades na largura toda em pé, margens
  iguais (RF53)
- [x] T82 Testes de simetria e "cabe na tela" × 3 idiomas; macaco e
  partida por clique em en/es; prévias por idioma (RF54, RF55, D)

Ordem sugerida: T81 (espaçamento, independe do resto) → T73/T74 → T76
(base técnica) → T75/T77 → T78 (o maior) → T79/T80 → T82.
