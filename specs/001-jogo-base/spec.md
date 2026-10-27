# Spec 001 — Onde Está Flávio Bolsonaro? (jogo base)

> Fase 1 do SDD: **o quê** e **por quê**. Nada de implementação aqui — isso
> fica em [plan.md](plan.md); a quebra em passos fica em [tasks.md](tasks.md).

## 1. Visão

Jogo de investigação e geografia no estilo *Where in the World is Carmen
Sandiego?*, em tom de **paródia política**. O senador Flávio "Zero Um"
Bolsonaro sumiu de uma coletiva de imprensa e está fugindo pelo mundo
disfarçado. O jogador é um(a) repórter da agência **F.U.R.O.** (Força Unificada
de Repórteres Obstinados) e precisa segui-lo de cidade em cidade, deduzindo o
próximo destino pelas pistas das testemunhas, descobrir qual **disfarce** ele
está usando e encurralá-lo antes do prazo para fazer *só uma perguntinha*.

Entregável: **executável Windows** (`.exe`) jogável sem instalar nada.

## 2. Público e tom

- Público adulto brasileiro, familiarizado com o noticiário político.
- Humor de charge: exagero, trocadilho, meme. Referências a episódios
  públicos e amplamente noticiados são permitidas **como piada**, nunca
  afirmando crime como fato (ver regras de conteúdo em [LORE.md](../../LORE.md)).
- Aviso de paródia/ficção visível na tela de título.

## 3. Histórias de usuário

| ID | Como jogador, eu quero… | Para… |
|----|-------------------------|-------|
| US1 | abrir o `.exe` e ver uma tela de título com a arte do jogo | saber que jogo é e começar rápido |
| US2 | informar meu nome de repórter e ter minha carreira salva | evoluir de cargo entre partidas |
| US3 | receber um *briefing* em forma de manchete com a cidade inicial e o prazo | entender o caso |
| US4 | investigar 3 locais por cidade e ouvir testemunhas | coletar pistas do próximo destino e do disfarce |
| US5 | ver o relógio avançar a cada ação (e dormir à noite) | sentir a pressão do prazo |
| US6 | abrir o mapa-múndi, escolher entre destinos e ver o avião viajar | seguir a trilha |
| US7 | perceber quando estou na cidade errada | voltar para a trilha |
| US8 | marcar características no **Dossiê** e emitir a **Pauta** do disfarce | ter o direito de fazer a pergunta quando encontrá-lo |
| US9 | encontrá-lo na última cidade e ver o desfecho em capa de jornal | fechar o caso (furo ou fracasso) |
| US10 | ouvir trilha e efeitos sonoros | imersão |

## 4. Regras do jogo (requisitos funcionais)

- **RF01 — Caso**: cada caso sorteia uma rota de `N` cidades distintas
  (`N` depende do cargo: 4 a 7), um disfarce e um motivo de fuga (piada).
- **RF02 — Relógio**: o caso começa *segunda 09:00* e termina *domingo 17:00*.
  Entre 23:00 e 07:00 o repórter dorme (pula automaticamente 8h quando uma ação
  passa das 23:00). Prazo estourado = derrota.
- **RF03 — Investigar**: cada cidade tem 3 locais. Ir a um local custa horas
  (2h, depois 3h, depois 4h na mesma cidade). Revisitar um local repete a
  pista sem custo extra de descoberta mas gasta 1h.
- **RF04 — Pistas de rota**: na cidade certa (não final), cada testemunha dá
  uma pista sobre a **próxima** cidade (bandeira, moeda, idioma, ponto
  turístico, curiosidade).
- **RF05 — Pistas de disfarce**: ao longo da rota, testemunhas revelam
  características do disfarce (chapéu, transporte, hobby, lanche). A rota
  sempre entrega pistas suficientes para identificar um disfarce único.
- **RF06 — Cidade errada**: nenhuma testemunha viu o senador; frase clara de
  que a trilha esfriou.
- **RF07 — Viajar**: na cidade certa, 4 opções (a próxima + 3 iscas). Na errada,
  a opção de voltar à última cidade certa + 2 iscas. Viagem custa 2–7h
  conforme a distância.
- **RF08 — Dossiê/Pauta**: o jogador marca características; a lista de
  disfarces compatíveis é filtrada; se sobrar exatamente 1, pode emitir a
  Pauta. Emitir é grátis e pode ser refeito.
- **RF09 — Cidade final**: testemunhas dizem que ele está muito perto; um dos
  3 locais o esconde. Ao achá-lo: com Pauta certa = vitória; sem Pauta ou
  errada = ele escapa (derrota).
- **RF10 — Imprevistos**: chance pequena de um evento cômico custar 1–2h
  (ex.: assessor oferecendo cafezinho de duas horas).
- **RF11 — Carreira**: vitórias sobem o cargo (Estagiário → Repórter Júnior →
  Repórter → Repórter Sênior → Editor-Chefe). Salva em disco.
- **RF12 — Controles**: mouse e teclado (setas/Enter/Esc) em todas as telas.

## 5. Requisitos não funcionais

- **RNF01** — Godot 4.7 / GDScript, mesma engine do projeto PPKMN.
- **RNF02** — Exporta um único `.exe` (pck embutido) para Windows x86_64.
- **RNF03** — Conteúdo (cidades, disfarces, falas) em dados JSON, não em código.
- **RNF04** — Lógica de jogo (gerador de caso, relógio, dossiê) sem
  dependência de cena, coberta por testes headless.
- **RNF05** — Assets próprios: arte do título (fornecida pelo usuário), demais
  gráficos gerados por código, áudio sintetizado, fontes OFL.
- **RNF06** — Resolução base 1280×720, escala mantendo proporção.

## 6. Identidade visual

Derivada da arte de título:
- **Paleta**: vermelho-sobretudo `#C8102E`, vermelho escuro `#7A0A1C`, preto
  tinta `#141414`, creme de jornal `#F1E9D2`, cinza de jornal `#8C8576`,
  amarelo-Brasil `#FFD100` e verde-Brasil `#009C3B` como acentos.
- **Tipografia**: *Pixelify Sans Bold* para títulos/manchetes, *Press Start 2P* só no logotipo e *VT323* para texto
  corrido (ambas OFL).
- **Linguagem gráfica**: recortes de jornal (manchetes, carimbos "URGENTE"),
  silhueta de chapéu fedora, sombras duras deslocadas, sem cantos arredondados.

## 7. Fora de escopo (por ora)

Dublagem, múltiplos idiomas, mobile/web, modo multijogador, ranking online.

## 8. Critérios de aceite

1. `build/OndeEstaFlavio.exe` abre direto na tela de título com a arte.
2. É possível jogar um caso inteiro só com teclado e só com mouse.
3. 500 casos gerados em teste têm rota válida e disfarce identificável.
4. Vitória e derrota (prazo e pauta errada) têm telas próprias.
5. Carreira persiste entre execuções.
