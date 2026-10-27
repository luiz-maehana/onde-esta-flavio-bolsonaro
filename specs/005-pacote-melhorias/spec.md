# Spec 005 — Pacote de melhorias (opções, dificuldade, progresso, conteúdo, ajuda, plataforma)

> Depende das specs 001–004. Seis frentes, cada uma com requisitos,
> plano curto e tarefas.

## A. Opções e pausa

- **RF23** — Tela de Opções (título e pausa): volume de música e de efeitos
  (0–100%), mudo, tela cheia, velocidade do texto (lenta / normal /
  instantânea), dicas ligadas/desligadas. Aplica na hora e persiste em
  `user://onde_esta_flavio_settings.json` (sanitizado como o save).
- **RF24** — Esc na cidade (sem painel aberto) abre a pausa: Continuar,
  Opções, Salvar e sair, Abandonar caso.
- Plano: `Settings` (core, dado + load/save), buses de áudio `Music`/`SFX`
  criados pelo `AudioManager`, componente `OptionsPanel`, `PauseMenu`.

## B. Dificuldade por cargo

- **RF25** — Cada cargo define: tamanho da rota, prazo, tipo de isca
  (`random` ou `near` = cidades mais próximas do destino certo) e quantas
  características do disfarce são reveladas.
- **RF26** — Curva validada por simulação em teste: Estagiário vence
  investigando tudo com 3 cidades erradas; Editor-Chefe vence investigando
  tudo sem erro e perde na maioria com 2 erros.

## C. Progresso

- **RF27** — Caso em andamento salvo automaticamente a cada ação; "Continuar
  caso" no título. Formato: semente + lista de ações, refeitas
  deterministicamente (save pequeno e impossível de deixar em estado
  incoerente; ação inválida descarta o caso).
- **RF28** — Estatísticas da carreira: melhor tempo, disfarces flagrados,
  escândalos cobertos, cidades visitadas, casos sem erro.
- **RF29** — Conquistas (`data/achievements.json`), anunciadas na capa final e
  listadas na tela Carreira.

## D. Conteúdo

- **RF30** — +8 cidades (Pequim, Nova Délhi, Santiago, Toronto, Istambul,
  Atenas, Berlim, Amsterdã) com 4 marcos novos (agulha, mesquita, templo,
  casas de canal).
- **RF31** — +6 disfarces com retrato, abrindo um 5º valor em cada
  característica (chapéu de peão, jatinho, churrasco, pão de queijo); a regra
  "2 características identificam 1 disfarce" continua valendo (teste).
- Escândalos continuam 5: o caso dos imóveis pagos em dinheiro vivo ficou
  fora porque a reportagem original foi removida por decisão liminar
  (risco jurídico).

## E. Ajuda e mapa

- **RF32** — Dicas contextuais no primeiro caso (briefing, primeira cidade,
  primeira pista, primeira pista de disfarce, viagem, última cidade),
  mostradas uma vez cada, desligáveis em Opções.
- **RF33** — Mapa: passar o mouse/tocar numa cidade mostra nome e país;
  destinos oferecidos mostram a bandeira simplificada do país.

## F. Plataforma

- **RF34** — Celular: aviso "gire o aparelho" em retrato; alvos de toque
  maiores em tela sensível ao toque.
- **RF35** — Cartão de compartilhamento: Open Graph/Twitter na página
  (imagem 1200×630 JPG leve, título e descrição).

## Tarefas

- [x] T44 Settings + buses de áudio + OptionsPanel + PauseMenu (A)
- [x] T45 Velocidade do texto e tela cheia ligadas ao Settings (A)
- [x] T46 Parâmetros de dificuldade por cargo + iscas próximas + teste de curva (B)
- [x] T47 Log de ações + replay + save do caso + Continuar caso (C)
- [x] T48 Estatísticas + conquistas + tela Carreira (C)
- [x] T49 8 cidades + 4 marcos (D)
- [x] T50 6 disfarces + 5º valor de característica + retratos (D)
- [x] T51 Dicas do primeiro caso (E)
- [x] T52 Mapa: rótulo ao passar o mouse + bandeiras (E)
- [x] T53 Aviso de rotação + toque maior (F)
- [x] T54 Open Graph + imagem de compartilhamento (F)
