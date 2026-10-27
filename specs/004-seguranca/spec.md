# Spec 004 — Pentest e endurecimento (27/10/2026)

Escopo: repositório e configurações do GitHub, workflow de CI, site no
GitHub Pages e o jogo (save, entradas de texto, conteúdo).

## Achados e correções

| # | Severidade | Achado | Correção |
|---|-----------|--------|----------|
| S1 | Média | Save com `cases_solved` nulo travava o jogo na abertura (erro em `int(null)` → carreira nula), em loop até apagar o arquivo | `Career.from_dict` tolerante a tipo errado, null, NaN, infinito |
| S2 | Média | Save com contagem negativa ou gigante (estouro p/ int64 mínimo) deixava o cargo vazio e quebrava a tela de título | Contagem limitada a 0..99999; `rank_for` nunca devolve vazio |
| S3 | Baixa | Nome do repórter sem limite vindo do save (5000+ caracteres) quebrava o layout | `sanitize_name` (18 caracteres) no save e no cadastro |
| S4 | Baixa | Nome como `{city}` era interpretado como marcador da manchete | Nome inserido por último, como texto literal |
| S5 | Baixa | Na Web, todo jogo Godot do domínio `*.github.io` do autor compartilha o mesmo `user://` (IndexedDB); `career.json` genérico poderia colidir | Arquivo `onde_esta_flavio_career.json`, com migração do antigo; limite de 4 KB |
| S6 | Média | CI: Godot (1,3 GB) baixado sem verificação de integridade | SHA-512 oficial conferido antes de extrair |
| S7 | Média | CI: actions referenciadas por tag móvel; permissão de escrita no workflow inteiro | Actions fixadas por SHA + Dependabot; `permissions: {}` e mínimo por job; checkout sem credencial persistida |
| S8 | Média | CI: erro de script no Godot headless trava o processo (sem `quit()`), prendendo o runner por até 6h | `timeout` nos comandos e `timeout-minutes` nos jobs |
| S9 | Baixa | Wiki pública ativa e vazia (superfície para conteúdo indevido sob o nome do repo) | Wiki desativada |
| S10 | Baixa | `main` e tags sem proteção contra force-push/exclusão | Rulesets: main e `v*` sem exclusão nem force-push; tags imutáveis |

## Verificado sem problema

- Nenhum segredo, token, e-mail pessoal ou caminho local nos arquivos nem no
  histórico (repositório recriado sem histórico); commits com e-mail
  `noreply` do GitHub.
- Secret scanning e push protection ativos; token padrão do Actions só
  leitura; ambiente `github-pages` restrito à main; HTTPS forçado no Pages.
- Pacote publicado (`index.pck`) só contém scripts e assets do jogo — sem
  specs, testes, ferramentas, `CLAUDE*.md` ou backups `.old.png`.
- Sem campo de texto renderizado como BBCode/HTML; o jogo não abre URLs nem
  executa código vindo de dados; overrides de retrato só leem `res://`.
- Workflow sem `pull_request_target` nem interpolação de entrada não
  confiável em shell.

## Riscos aceitos

- Save local é editável (dá pra se dar cargo máximo): jogo single-player,
  sem ranking online — aceitável.
- `.exe` sem assinatura de código: o Windows SmartScreen avisa na primeira
  execução. Resolver exige certificado pago.
- PCK sem criptografia: o código já é aberto no repositório.
- Conteúdo sobre pessoa real: mitigado pelas regras do LORE (status e
  fontes nos fatos, piada só como alusão, aviso de paródia).
