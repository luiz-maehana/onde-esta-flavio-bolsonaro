# Spec 007 — Roteiro de testes aprofundado

> Status: **implementada** (28/10/2026). Depende das specs 001–006.

## Por quê

Os testes atuais conferem caminhos conhecidos: 200 partidas roteirizadas,
saves adulterados, telas que montam, um fluxo de cliques por tela. Os bugs
que escaparam até aqui vieram de **combinações**: voltar a uma cidade
errada mais tarde, timer disparando depois da tela fechar, linha larga
demais só em pé, áudio mudo só no celular. Esta spec cobre isso com quatro
frentes:

1. **Invariantes**: regras que valem a *cada passo* de qualquer partida,
   checadas sob jogo aleatório (fuzz) e não só no final.
2. **Macaco de interface**: cliques aleatórios em botões reais, nas 3
   orientações, procurando erro de script, tela travada ou foco perdido.
3. **Casos extremos de conteúdo e entrada**: textos mais longos, nomes
   hostis, tudo de `data/` cruzado com o código.
4. **Roteiro manual** em aparelho de verdade (o que automação não pega:
   toque, teclado virtual, áudio, rede ruim).

Critério geral: todo teste novo roda headless no CI, sem rede, e falha com
uma mensagem que diz **semente + passo** pra reproduzir.

## A. Lógica — invariantes sob fuzz (`run_tests.gd`)

Jogar 2.000 casos com ações aleatórias, válidas e inválidas, em todos os
cargos, conferindo depois de **cada** ação:

- **I1 Relógio**: horas nunca diminuem. Ao passar do prazo, o desfecho é
  `TIMEOUT` e nada mais muda o relógio.
- **I2 Fim é fim**: com `is_over()`, investigar, viajar, dossiê e pauta não
  alteram o estado nem acrescentam ação ao save.
- **I3 Viagem**: as opções não têm repetição nem a cidade atual. Na trilha,
  incluem a próxima parada. Fora dela, incluem a parada certa *atual*
  (regressão do bug da cidade errada revisitada).
- **I4 Ação inválida**: viajar para cidade fora das opções, investigar
  local fora da cidade ou emitir pauta com disfarce inexistente é recusado
  sem efeito colateral.
- **I5 Contadores**: `wrong_cities` só cresce em cidade fora da rota;
  `stop_index` nunca passa do fim da rota; anotações não se duplicam.
- **I6 Save em todo prefixo**: `from_save(to_save())` refeito a cada passo
  (não só no fim) dá estado idêntico, inclusive depois do desfecho.
- **I7 Determinismo**: a mesma semente e as mesmas ações geram o mesmo
  estado e as mesmas falas, mesmo com consumo de rng fora de ação
  (`_sub_rng`).
- **I8 Vitória sempre possível**: em todo caso gerado, o jogo perfeito
  (pauta certa + rota direta) vence dentro do prazo em todos os cargos.

## B. Conteúdo e textos (`run_tests.gd`)

- **C1 Falas completas**: para toda cidade × local × traço × escândalo, o
  `ClueBuilder` não deixa `{marcador}` sem trocar, string vazia, espaço
  duplo ou pontuação dobrada.
- **C2 Pista aponta certo**: a pista de cidade na trilha descreve a próxima
  parada real (país/marco da cidade `route[i+1]`), nunca uma isca.
- **C3 Dossiê**: cada disfarce tem combinação de traços única, e os traços
  revelados em qualquer rota sempre bastam (já coberto por amostra; passa
  a ser exaustivo).
- **C4 Integridade cruzada**: ids únicos em todo `data/*.json`; todo
  id referenciado existe (cidade → marco em `SkylineLandmarks`, local →
  figurino, conquista → condição, dica → chave usada no código);
  lat/lon dentro do mapa (`LAT_TOP`/`LAT_BOTTOM`).
- **C5 Nomes de som**: todo `play_sfx`/`play_music` usado no código existe
  no `AudioManager`.
- **C6 Sátira**: cada escândalo tem `status` e `outlet` não vazios (limite
  do LORE: fato real sempre com status da apuração).

## C. Entradas hostis

- **E1 Nome do repórter**: vazio, só espaços, 18 × "W", emoji, `{city}`,
  `{player}`, BBCode `[b]`, quebra de linha, texto da direita para a
  esquerda. Sanitiza igual no jogo e no servidor; nunca quebra a manchete
  nem o layout.
- **E2 Saves**: JSON truncado, arquivo binário, arquivo de 10 MB, versão
  futura, lista de ações com 10 mil itens. O jogo abre no título com o save
  descartado, sem travar.
- **E3 Opções**: arrastar slider até os extremos, alternar mudo 50 vezes,
  rever dicas e fechar o painel antes de 1,5 s (regressão do timer).

## D. Interface — cliques reais (`ui_tests.gd`)

- **U1 Partida de ponta a ponta por clique**: título → novo caso →
  briefing → cidade → investigar → viajar → ... → capa → novo caso, só
  apertando botões, nas 3 orientações (1280×720, 844×390, 390×844).
- **U2 Macaco**: 3 sementes × 400 cliques em botões visíveis e habilitados
  sorteados, mais ESC aleatório. A cada passo: nenhum erro de script, existe
  uma tela atual, o foco está num controle visível, no máximo um overlay
  aberto. Falha imprime semente e passo.
- **U3 Clique duplo/reentrada**: apertar VIAJAR para um destino duas vezes
  durante o voo, NOVO CASO duas vezes antes do servidor responder,
  CONTINUAR na fala durante a digitação. Só uma ação entra no save.
- **U4 Girar no meio**: trocar a orientação com a fala aberta, o avião
  voando, o dossiê aberto, a pausa aberta e o crachá de nome aberto. O caso
  não muda, nenhuma ação é duplicada, a tela remonta usável.
- **U5 Cabe na tela**: para cada tela **e cada overlay** (pausa, opções,
  dicas, crachá, pergunta do ranking), nas 3 orientações, com os **textos
  mais longos** do jogo (maior cidade, maior disfarce, maior escândalo,
  nome de 18 caracteres): nada vaza da borda e nenhum botão fica menor que
  48 px de altura em pé.
- **U6 Teclado/controle**: em cada tela, Tab/setas alcançam todos os botões
  e ESC tem o efeito esperado (voltar, pausar, fechar overlay), sem ficar
  sem foco.
- **U7 Salvar e continuar**: SALVAR E SAIR no meio do caso → CONTINUAR
  CASO restaura cidade, relógio, dossiê e anotações iguais.

## E. Servidor (`server/test`)

- **S1 Paridade fuzz**: vetores com ações inválidas e ações depois do fim
  (o servidor tem que recusar/ignorar igual ao Godot).
- **S2 API hostil**: JSON malformado, corpo enorme, campos com tipo errado,
  apelido com unicode/controle, `finish` duplo concorrente no mesmo run
  (só um conta), virada da semana do ranking.

## F. Roteiro manual (antes de cada publicação)

Checklist curto em `specs/007-testes-aprofundados/manual.md`, uma linha por
item com ✔/✘ e o aparelho usado:

- Android Chrome e iPhone Safari, em pé e deitado: abrir, girar no meio da
  fala e do voo, digitar o nome com teclado virtual, primeiro toque libera o
  som.
- Rede lenta (3G simulado): a barra de carregamento avança; cair a internet
  no meio do caso → caso continua local, contador some e volta.
- Fechar a aba no meio do caso → reabrir → CONTINUAR CASO.
- Duas abas ao mesmo tempo (save compartilhado não corrompe).
- Windows .exe: F11, DPI 150%, monitor ultrawide, alt-tab durante o voo.

## Tarefas (quando aprovado)

- [x] T64 Gerador de partidas fuzz + invariantes I1–I8
- [x] T65 Conteúdo C1–C6
- [x] T66 Entradas hostis E1–E3
- [x] T67 Partida por clique (U1) e salvar/continuar (U7)
- [x] T68 Macaco de interface (U2) + reentrada (U3)
- [x] T69 Girar no meio (U4) + cabe na tela com textos extremos (U5)
- [x] T70 Navegação por teclado (U6)
- [x] T71 Servidor S1–S2
- [x] T72 Checklist manual (F)

## Achados (27/10/2026)

- **I2**: `set_dossier` aceitava marcação depois do fim do caso (no jogo e
  no servidor). Corrigido nos dois motores; paridade regerada.
- **U2 (macaco)**: INVESTIGAR com dossiê/anotações abertos abria o painel
  dentro da cena escondida — nada aparecia e o foco ia pra botão
  invisível.
- **U4**: girar o aparelho durante a última fala prendia o jogador na
  cidade com o caso encerrado (nunca chegava à capa).
- **U5**: barra do título deitado vazava com nome/cargo longos; capa de
  jornal deitada não rolava; fala longa de testemunha empurrava CONTINUAR
  pra fora da caixa (relatado também jogando).
- **Ranking** (relatado jogando): cada caso vencido virava uma linha — o
  mesmo jogador aparecia várias vezes. Agora é o melhor resultado de cada
  aparelho; consulta conferida num SQLite real.
- Infra: em `read_only` o caso em andamento vai pra memória (testes não leem
  mais o save real do jogador); `Online.mock` aceita corrotina (servidor
  lento); UI tests registram todo erro do motor via `Logger`.
- **E1** (28/10): o nome do repórter aceitava quebra de linha, caractere de
  controle e inversão de direção (U+202E) vindos de save adulterado; agora
  viram espaço, no jogo e no apelido do servidor (que juntava "Ana
Furo"
  em "AnaFuro").
- **S1**: 120 vetores de recusa no `vectors.json` — o servidor recusa tudo
  que o Godot recusa (inclui ação depois do fim).
- T65, T67 e T70 passaram de primeira: textos, partida inteira por clique,
  salvar/continuar e navegação por teclado já estavam corretos.
- U5 com alvo de toque de 48 px reais: entrou com a escala por lado curto
  (spec 008/T55) e é conferido no teste "cabe na tela".

Ordem sugerida: T64 → T68 → T69 → T65, porque são os que mais acham bug por
linha de teste. O resto depois.
