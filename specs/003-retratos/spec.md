# Spec 003 — Retratos: flagrante do disfarce e NPCs mais realistas

> Depende das specs [001](../001-jogo-base/spec.md) e
> [002](../002-escandalos/spec.md). Spec, plano e tarefas juntos.

## 1. Visão

1. Cada um dos 8 disfarces ganha um **retrato do senador disfarçado**. Na
   captura e na capa final aparecem lado a lado **"FLAGRANTE"** (disfarçado)
   e **"FOTO OFICIAL"** (de terno, como senador).
2. As testemunhas deixam de ser um boneco genérico recolorido: cada local
   tem **figurino próprio** (comissária, gerente de banco, marinheiro…) e
   cada pessoa varia em tom de pele, idade, cabelo, barba, óculos e
   acessórios.

## 2. Requisitos

- **RF18** — Retrato do senador em 3 versões: *procurado* (fedora e
  sobretudo vermelhos, identidade do jogo), *oficial* (terno) e
  *disfarçado* (um por disfarce, fiel ao texto `reveal`).
- **RF19** — Caricatura reconhecível e consistente nas 3 versões: cabelo
  escuro curto penteado de lado, sobrancelhas grossas, rosto arredondado,
  olhar de canto (como na arte de capa).
- **RF20** — Ao achar o senador, a fala da captura mostra o retrato
  disfarçado; a capa final mostra FLAGRANTE + FOTO OFICIAL (em derrota por
  prazo: só a foto oficial com "paradeiro desconhecido").
- **RF21** — Testemunhas com figurino por local (dados em `flavor.json`) e
  traços sorteados com semente fixa por cidade+local.
- **RF22** — Imagem em `assets/portraits/<nome>.png`, se existir, substitui
  o retrato gerado (`flavio`, `flavio_oficial`, `flavio_<disfarce>`).

## 3. Restrições

- Sem foto real do senador (direito de imagem; foto montada em disfarce
  poderia passar por verdadeira). Sempre caricatura claramente desenhada.
- Retratos gerados por código (sem gerador de imagem no ambiente),
  48×48 px, exibidos em escala inteira com filtro *nearest*.

## 4. Plano

- `PortraitPainter` — primitivas em `Image` 48×48: retângulo, elipse
  sombreada, polígono, linha, contorno externo automático.
- `PortraitFactory` — monta um retrato a partir de um *spec* (dicionário):
  rosto (pele, cabelo, sobrancelha, idade, barba, óculos, batom), roupa,
  chapéu/peruca e objeto de mão. Camadas: fundo → corpo → cabeça → rosto →
  cabelo/chapéu → óculos → objeto → contorno.
- Rosto do senador é constante em código (identidade); figurino de
  disfarce em `disguises.json` (`portrait`), figurino de testemunha em
  `flavor.json` (`locations.*.outfit`).
- `PixelPortrait` vira fachada com cache: `flavio()`, `flavio_official()`,
  `flavio_disguised(id)`, `witness(key, loc_id)`, `make_rect(tex, px)`.
- `tools/build_portrait_sheet.gd` gera `build/portraits.png` com todos os
  retratos pra revisão visual.

## 5. Tarefas

- [x] T37 `PortraitPainter` (primitivas + contorno)
- [x] T38 `PortraitFactory` (rosto, cabelos, roupas, chapéus, objetos)
- [x] T39 Figurinos dos 8 disfarces em `disguises.json` — RF18
- [x] T40 Figurinos dos 12 locais em `flavor.json` — RF21
- [x] T41 Fachada `PixelPortrait` + override por arquivo — RF22
- [x] T42 Captura e capa final com FLAGRANTE + FOTO OFICIAL — RF20
- [x] T43 Folha de revisão + testes (todo disfarce/local tem figurino válido)
