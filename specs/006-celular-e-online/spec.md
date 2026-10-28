# Spec 006 — Celular responsivo, pessoas online e ranking (planejamento)

> Status: **em implementação** (parte B primeiro). Depende das specs 001–005.

## A. Jogar no celular pelo navegador (responsivo)

Hoje o jogo é desenhado em 1280×720 e escalado inteiro: no celular deitado
funciona, mas o texto fica pequeno; em pé, a spec 005 só mostra "gire o
aparelho".

- **RF36** — Layout adaptativo em vez de escala fixa: `window/stretch/aspect
  = expand` e cada tela monta um arranjo por orientação:
  - **Paisagem** (atual), **retrato** (celular em pé):
    - Cidade: paisagem em cima, fala/locais no meio, ações em grade 3×2
      embaixo (a 6ª casa é o cartaz do Flávio).
    - Viagem: mapa em cima (recortado na região dos destinos), destinos em
      lista vertical.
    - Título: arte recortada no topo, menu em coluna.
    - Jornal (briefing/capa/carreira): uma coluna, foto acima do texto, com
      rolagem.
    - Dossiê: características em lista vertical com quebra.
- **RF37** — Tamanho de fonte e de alvo de toque pelo lado curto da tela
  (mínimo ~48 px reais por botão); respeitar área segura (notch) via
  `DisplayServer.get_display_safe_area()`.
- **RF38** — Teclado virtual no nome do repórter (`html/
  experimental_virtual_keyboard`), sem hover obrigatório (o mapa já aceita
  toque).
- **RF39** — Carregamento: barra de progresso própria na página (wasm de
  ~40 MB) e aviso de "melhor em Wi-Fi".
- Plano técnico: componente `ResponsiveLayout` (sinal `orientation_changed`,
  `is_portrait()`, `ui_scale()`); telas montam o layout em função dele
  (já são montadas em código, então trocar arranjo é barato). A prévia
  (`RenderPreview`) passa a gerar cada tela em 1280×720, 844×390 (celular
  deitado) e 390×844 (em pé).

## B. Pessoas online e ranking (Cloudflare)

### Arquitetura

```
Jogo (Web/exe) ──HTTPS──► Cloudflare Worker (API)
                              ├─ Durable Object "Presence"  → contador online
                              └─ D1 (SQLite)                → partidas e ranking
```

- **Worker**: API pública, CORS só para `luiz-maehana.github.io` (e o exe,
  que não manda Origin).
- **Presença** (RF40): o jogo manda um *heartbeat* a cada 60 s com um id de
  sessão aleatório; o Durable Object conta sessões vistas nos últimos 150 s.
  (60 s e não 30 s: é o que mais consome do limite grátis de 100 mil
  requisições/dia — ~1.600 horas-jogador por dia. Se a API estourar o
  limite, o jogo só esconde o contador; nada quebra.)
  `GET /online` devolve o número. Exibido no título ("12 repórteres na
  rua agora") e na pausa.
- **Ranking** (RF41): só casos **vencidos**. Pontuação = base do cargo ×
  cidades da rota + horas que sobraram − penalidade por cidade errada.
  Ranking semanal e geral, top 50, com apelido e cargo.

### Antitrapaça (o ponto mais importante)

O jogo roda no cliente, então qualquer resultado enviado "pronto" é
falsificável. A spec 005 já deixou o caminho certo pronto: **o caso é
semente + ações e é 100% determinístico.**

1. `POST /runs/start` → o servidor sorteia a **semente** e a configuração
   do cargo, guarda e devolve um `run_id`.
2. O jogo joga com essa semente.
3. `POST /runs/finish {run_id, actions}` → o servidor **refaz o caso** a
   partir da semente e das ações e calcula ele mesmo o desfecho e a
   pontuação. O cliente nunca informa pontos.

Para isso o núcleo (`GameClock`, `CaseGenerator`, `CaseState`,
`ClueBuilder` na parte que consome o rng) é portado para TypeScript, junto
com o `RandomNumberGenerator` do Godot (PCG32) bit a bit. **Paridade
garantida por teste**: o Godot exporta centenas de casos (semente + ações →
estado final) em JSON e o teste do Worker refaz todos e compara.

Proteções adicionais: limite de partidas por sessão/IP (rate limiting do
Cloudflare), prazo máximo entre start e finish, ações ≤ 1000, run usado uma
vez só, Turnstile (captcha invisível) opcional no start.

### Privacidade (LGPD) e moderação

- Sem login e sem dado pessoal: id de dispositivo aleatório (gerado no
  jogo, em `user://`), apelido, pontuação e data. IP só para limite de
  requisições, sem armazenar.
- Apelido sanitizado (18 caracteres, lista de palavrões/termos ofensivos),
  e rota de administração protegida por segredo para remover entradas.
- Participação **opcional** (Opções → "Ranking online"); o jogo funciona
  normalmente offline ou se a API cair.

### Freio do plano gratuito (sem cobrança, jogo sempre no ar)

- No plano Free o Cloudflare **não cobra**: passou de 100 mil requisições no
  dia, a API para até 0h UTC. O jogo (GitHub Pages) continua no ar e já
  trata API fora (sem contador, caso local).
- Pra a API não chegar lá: o servidor devolve o intervalo do próximo sinal
  de cada jogador, calculado pra os sinais do dia caberem em 70 mil (sobram
  30 mil pra partidas/ranking). Até ~48 pessoas simultâneas o dia todo: 1
  sinal/min; mais gente: mais espaçado (2.000 pessoas: ~42 min). Orçamento
  esgotado: próximo sinal só depois da meia-noite UTC. Testado simulando um
  dia inteiro com 1.000 e 5.000 pessoas.
- O jogo obedece o intervalo e, se a API falhar, espaça as tentativas (2, 4,
  8 até 15 min).

### Custos e implantação

- Plano gratuito do Cloudflare cobre com folga: Workers (100 mil
  requisições/dia), Durable Objects com SQLite, D1 (5 milhões de
  leituras/dia).
- Deploy com `wrangler` pelo GitHub Actions usando um token de API do
  Cloudflare guardado em *secret* do repositório (permissões só de Workers e
  D1 da conta).

## Tarefas (quando aprovado)

- [x] T55 `ResponsiveLayout` + aspect expand + escala por lado curto (A)
  — `Responsive`: orientação, tamanho-base 1280x720/720x1280, alvo de toque
  de 48 px reais e texto até 1,3x pelo lado curto da tela em px de CSS.
- [x] T56 Arranjo retrato das 7 telas + prévias em 3 tamanhos (A)
- [x] T57 Área segura, teclado virtual, barra de carregamento (A)
  — área segura: a página não usa viewport-fit=cover (Safari mantém fora do
  notch; teste garante); crachá de nome no alto no toque; aviso de ~40 MB /
  Wi-Fi e barra nas cores do jogo via head_include.
- [x] T58 Exportar vetores de paridade do Godot (semente + ações → estado) (B)
- [x] T59 Porte do núcleo + PCG32 para TypeScript com teste de paridade (B)
- [x] T60 Worker + Durable Object de presença + D1 + rotas (B)
- [x] T61 Cliente no jogo: heartbeat, start/finish, telas de ranking, opção (B)
- [x] T62 Rate limit, CORS, moderação de apelido, rota de admin (B)
- [x] T63 Deploy pelo Actions com token do Cloudflare em secret (B)

## Decisões (27/10/2026)

1. Ranking: o jogo **pergunta ao fim do primeiro caso** ("ask"); dá pra
   mudar em Opções. Enquanto não decidiu, o caso já é registrado no
   servidor (anônimo) pra poder entrar no ranking se o jogador aceitar.
2. Contador de online **para todos** (anônimo), no título e na pausa.
3. API em `onde-esta-flavio-api.ondeestaflavio.workers.dev`.
4. Turnstile **depois**, se aparecer abuso — o replay no servidor já é a
   antitrapaça principal.
5. Moderação de apelido: lista de bloqueio no servidor + remoção manual
   pelo console do D1 no painel (sem rota de admin exposta).
6. Pra o porte ser exato, o núcleo deixa de usar `randf()` (algoritmo de
   float do Godot é difícil de replicar) e passa a usar só inteiros;
   `SAVE_VERSION` sobe pra 2 (save de caso antigo é descartado, não
   refeito errado).
