# Spec 002 — Escândalos como tema dos casos

> Depende da [spec 001](../001-jogo-base/spec.md). Plano e tarefas ao fim
> deste arquivo (feature pequena: spec, plano e tarefas juntos).

## 1. Visão

Cada caso passa a girar em torno de um **escândalo real e amplamente
noticiado** envolvendo o senador. O escândalo define o motivo da fuga, as
provocações, imprevistos, falas de "ele está perto", o esconderijo e as
manchetes, e o briefing traz um box **"ENTENDA O CASO"** com o fato real, o
status jurídico atual e a fonte.

## 2. Requisitos

- **RF13** — Cada caso sorteia um escândalo de `data/scandals.json`.
- **RF14** — O briefing mostra "ENTENDA O CASO": resumo factual, **status**
  (investigado / arquivado / sem decisão judicial) e veículo de origem.
- **RF15** — Motivo da fuga e esconderijo vêm do escândalo; provocações,
  imprevistos e falas de "perto" misturam as genéricas com as do escândalo.
- **RF16** — A manchete de vitória pode ser temática do escândalo.
- **RF17** — Capa final repete o status do caso em uma linha.

## 3. Regras de conteúdo (críticas — ver LORE.md)

- O box factual só afirma o que as fontes afirmam, sempre com o status:
  investigação **não é condenação**; denúncia arquivada é dita como
  arquivada.
- Piadas fazem **alusão** ("rachar a conta", "bombom lavado") e nunca
  afirmam crime como fato.
- Nada que dependa de fato não confirmado (ex.: resultado da eleição de
  2026 não entrou porque não foi confirmado em fonte independente).
- Cada escândalo guarda as URLs das fontes no JSON.

## 4. Escândalos iniciais (pesquisa em 27/10/2026)

| id | Tema | Status |
|----|------|--------|
| rachadinha | Gabinete na Alerj, Fabrício Queiroz | denúncia arquivada pelo TJ-RJ em 2022 após STJ anular provas; pedido de reabertura em set/2026 |
| chocolate | Franquia Kopenhagen apontada pelo MP-RJ como usada para lavagem | parte da denúncia das rachadinhas, arquivada em 2022 |
| mansao | Mansão de R$ 6 mi no Lago Sul, financiamento do BRB com juros abaixo da média | apuração da PF (out/2026), sem decisão judicial |
| darkhorse | Repasses do Banco Master à produtora do filme *Dark Horse* | inquérito no STF desde jul/2026 |
| apostas | Vínculos com o advogado Willer Tomaz e empresas de apostas on-line | PF enviou ao STF em out/2026 |

## 5. Plano

- `data/scandals.json`: `{id, title, summary, status, outlet, sources[],
  reasons[], found_spots[], taunts[], gags[], near[], headlines_win[]}`.
- `CaseState.scandal` (Dictionary). `CaseGenerator.generate` sorteia e usa
  `reasons`/`found_spots` do escândalo.
- `ClueBuilder` e `CaseState.investigate` puxam listas por um helper
  `CaseState.flavor_pool(key)` = genéricas + do escândalo (sem duplicar
  lógica de mistura em vários lugares).
- `GameData.scandals()` + validação (campos obrigatórios, ≥1 fonte, status
  não vazio).
- Briefing: box "ENTENDA O CASO" (painel creme escuro, VT323 menor).
- EndScreen: manchete temática + linha de status.

## 6. Tarefas

- [x] T29 `data/scandals.json` com 5 escândalos e fontes — RF13
- [x] T30 `GameData.scandals()` + validação — RF13
- [x] T31 `CaseState.scandal` + `flavor_pool` + gerador — RF13/RF15
- [x] T32 `ClueBuilder`/gags usando `flavor_pool` — RF15
- [x] T33 Box "ENTENDA O CASO" no briefing — RF14
- [x] T34 Manchete/status temáticos no desfecho — RF16/RF17
- [x] T35 Testes (validação + todo caso tem escândalo + falas temáticas aparecem)
- [x] T36 LORE.md: regra de fatos com status e fonte
