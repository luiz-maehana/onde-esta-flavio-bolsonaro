# Spec 010 — Segurança do ranking, do servidor e do repositório

> Status: **implementada** (29/10/2026); G1–G3 ficam com o dono do repositório. Depende das specs
> 004 e 006. Origem: auditoria de segurança de 29/10/2026.

## Por quê

A auditoria não achou falha crítica (sem segredo vazado, sem injeção, sem
acesso a dados de outros), mas achou brechas de **integridade do ranking**,
um jeito barato de derrubar a API do plano grátis e pontos de
configuração. A pior foi reproduzida: um robô que lê a solução da semente
venceu 200 de 200 casos com média de 1.063 pontos, contra 581 de um
jogador cuidadoso.

## Achados e o que fazer

| # | Gravidade | Achado | RF |
|---|---|---|---|
| 1 | Alta | Robô resolve o caso pela semente e o código aberto | RF64 |
| 2 | Média | Cargo declarado pelo cliente aumenta a pontuação | RF65 |
| 3 | Média | `/presence` sem limite: infla o contador e queima a cota | RF66 |
| 4 | Média | `main` sem proteção; push publica direto em produção | G1 |
| 5 | Baixa | Limite por aparelho contornável (id do cliente) | RF66 |
| 6 | Baixa | Apelido burla o filtro com outro alfabeto e usa nome alheio | RF67 |
| 7 | Baixa | 3 vulnerabilidades no `wrangler` (só deploy); Dependabot desligado | RF68, G2 |
| 8 | Baixa | Limite do corpo confia no `Content-Length` | RF69 |
| 9 | Info | Id do aparelho na URL do ranking (vai pra log) | RF70 |
| 10 | Info | `.exe` sem hash publicado | RF71 |
| — | Conteúdo | Sem canal pra pessoa citada pedir correção | RF72 |

## Requisitos

- **RF64 — Partida plausível.** O servidor continua aceitando qualquer
  partida legal, mas só publica no ranking a que uma pessoa poderia ter
  jogado. Marca (`flag`) e não publica quando:
  - terminou rápido demais: menos de 60 s ou menos de 3 s por ação;
  - viajou para o destino certo sem ter investigado nenhum local da cidade
    (a pista do destino vem da investigação);
  - emitiu a pauta antes de ouvir pelo menos 2 características do
    disfarce.
  A partida conta normalmente pro jogador (desfecho e pontos voltam); só
  não vai pro ranking. Não impede um robô que imite uma pessoa, mas tira a
  vantagem: ele cai pro nível de um bom jogador. Turnstile segue guardado
  pra se aparecer abuso.
- **RF65 — Cargo pelo servidor.** O cargo usado no caso e na pontuação é o
  menor entre o pedido pelo jogo e o que o servidor calcula pelas vitórias
  daquele aparelho registradas nele. Consequência aceita: quem jogou
  offline começa o ranking num cargo abaixo do da carreira.
- **RF66 — Limites por IP.** Limite de requisições por IP (hash) com o
  rate limiting do próprio Workers, em todas as rotas que gastam; e no
  máximo 5 sessões de online por IP no contador. Limitação conhecida: no
  domínio `workers.dev` não há como barrar as requisições antes de
  chegarem ao Worker, então um ataque ainda consome a cota diária (sem
  custo; API volta à meia-noite UTC). Domínio próprio + regra de WAF
  resolveria (fora do escopo).
- **RF67 — Apelidos.** Só alfabeto latino (com acentos), números e
  `. _ -`; nomes reservados (o Flávio, os parceiros, "Repórter Anônimo")
  viram "Repórter Anônimo".
- **RF68 — Dependências.** `wrangler` atualizado (corrige o `undici`).
- **RF69 — Corpo da requisição.** Lido em partes, parando ao passar de
  64 KB, com ou sem `Content-Length`.
- **RF70 — Ranking sem id do aparelho na URL.** O jogo manda um hash do
  id (só serve pra marcar "você"); o servidor aceita os dois por um tempo
  (versões antigas).
- **RF71 — Hash do `.exe`.** A release no GitHub publica o SHA-256.
- **RF72 — Canal de correção.** `SECURITY.md` e README ganham como pedir
  correção ou remoção de conteúdo sobre pessoas reais.

## Configurações (passo a passo pro dono do repositório)

- **G1 — GitHub:** proteger a `main` (bloquear force-push e exclusão);
  opcional: ambiente `production` com aprovação manual no `api.yml`;
  conferir 2FA.
- **G2 — GitHub:** ligar os alertas do Dependabot.
- **G3 — Cloudflare:** notificação de uso por e-mail; conferir que a conta
  está no plano Free.

## Passo a passo das configurações

**G1 — Proteger a `main`** (GitHub → Settings → Branches → Add branch
ruleset): alvo `main`; marcar *Restrict deletions* e *Block force pushes*.
Não marcar *Require a pull request* (o fluxo atual é push direto). Opcional:
Settings → Environments → New environment `production` → *Required
reviewers* (você) e, no `api.yml`, `environment: production` no job — cada
deploy do servidor passa a esperar sua aprovação. Conferir 2FA em
Settings da conta → Password and authentication.

**G2 — Dependabot** (Settings → Code security): ligar *Dependabot alerts*
(e, se quiser, *security updates*, que abrem PRs com a correção).

**G3 — Cloudflare**: Notifications → Add → *Workers usage* (ou *Usage
Based Billing*), com e-mail; em Workers & Pages → Plans, conferir que a
conta está no **Free** (no Paid, o que passar da cota é cobrado).

## Decisões de implementação

- `wrangler` 4.154.0: a correção do `undici` só existe a partir da
  4.153.0 (versões de out/2026); a 4.154.0 tem procedência SLSA verificada
  (`npm audit signatures`), que o CI passa a exigir antes do deploy.
- Limite de volume por IP: no plano grátis com workers.dev não há como
  fazer de forma confiável. O rate limiting nativo foi aceito, mas no teste
  em produção deixou passar ~170 req/min por IP; um limitador em memória
  também não barrou (as requisições caem em muitas instâncias). Fica o
  nativo como barreira extra. O que protege de fato é por IP dentro do que
  é consistente: sessões no contador (Durable Object, máx. 5), partidas
  (D1, 60/h) — e o ranking em cache de 30 s no Durable Object, que limita
  as leituras do D1 a ~2 por 30 s qualquer que seja o tráfego (antes, alguns
  milhares de consultas esgotariam os 5 milhões de linhas/dia do D1 e
  derrubariam o ranking até o dia seguinte).

## Testes

- Robô da auditoria: suas partidas são marcadas e não entram no ranking;
  partidas humanas (investigando, tempo real) entram.
- Cargo pedido acima do merecido cai pro calculado.
- Limite por IP devolve 429; 6ª sessão do mesmo IP não aumenta o contador.
- Apelidos com cirílico e nomes reservados viram anônimo.
- Corpo grande sem `Content-Length` é recusado.
- Ranking marca "você" com o hash e com o id antigo.

## Tarefas

- [x] T91 Plausibilidade e marca no servidor (RF64) + migração do D1
- [x] T92 Cargo calculado pelo servidor (RF65)
- [x] T93 Rate limiting por IP e sessões por IP (RF66)
- [x] T94 Apelidos (RF67)
- [x] T95 `wrangler` atualizado (RF68)
- [x] T96 Corpo lido em partes (RF69)
- [x] T97 Hash do aparelho no ranking (RF70)
- [x] T98 SHA-256 na release (RF71) e canal de correção (RF72)
- [x] T99 Testes e passo a passo das configurações (G1–G3)
