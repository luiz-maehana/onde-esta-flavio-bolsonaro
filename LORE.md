# LORE — universo, tom e termos

## Premissa

O senador Flávio "Zero Um" Bolsonaro sumiu no meio de uma coletiva e está
rodando o mundo disfarçado. A **Agência F.U.R.O.** (Força Unificada de
Repórteres Obstinados), redação do jornal **O FURO**, manda o jogador atrás
dele para fazer *só uma perguntinha* antes do fechamento da edição de
domingo.

## Termos do jogo

| Termo | Significado |
|-------|-------------|
| Pauta | equivalente ao "mandado" do Carmen Sandiego: autorização da redação para abordar o disfarce certo |
| Dossiê | tela onde se cruzam as características do disfarce |
| Caderno de anotações | log das falas das testemunhas |
| Furo | vitória (matéria exclusiva) |
| Escapou | derrota |
| Cargos | Estagiário(a) → Repórter Júnior → Repórter → Repórter Sênior → Editor(a)-Chefe |

Características de disfarce: **Na cabeça**, **Transporte**, **Passatempo**,
**Lanche** (valores em `data/disguises.json`).

## Visual

Sobretudo e fedora vermelhos (da arte de título), tinta preta, papel de
jornal, acentos verde-amarelos. Manchetes, carimbos, sombras duras.

## Tom e limites da sátira

- Humor de charge: exagero, trocadilho, meme, situações absurdas.
- Referências a episódios públicos amplamente noticiados podem aparecer
  como **piada ou alusão**, nunca afirmando crime, condenação ou fato
  inventado como verdade.
- Nada de violência contra o personagem, conteúdo sexual ou ataque a
  terceiros não públicos (assessores, familiares sem cargo etc.).
- O aviso de paródia na tela de título é obrigatório.
- O personagem é sempre o alvo da piada pelo "foge da imprensa", não por
  características pessoais (aparência, família, religião).

## Parceiros (spec 009)

Além do Flávio, o caso pode ser atrás de um **parceiro**: figura pública
ligada a ele, com o próprio escândalo real (\`data/targets.json\`). Mesmas
regras do Flávio:

- Todo alvo é "procurado para entrevista" e foge da imprensa — a piada é a
  fuga, nunca acusação. "Cúmplice" e afins não entram (o termo é
  "parceiros").
- Só figuras com cargo ou papel público próprio; o box "Entenda o caso"
  traz o status (condenado só onde há condenação definitiva) e a negativa.
- Retratos genéricos, sem buscar semelhança; nada de aparência, família ou
  religião.
- Fora: quem não tem papel público próprio (aparece só no box de outro) e
  notícia não confirmada.

## Escândalos reais (spec 002)

Os casos usam escândalos reais de `data/scandals.json`. Regras:

- O box "ENTENDA O CASO" é a **única** parte factual: resume o que as fontes
  publicaram, sempre com o **status** (investigado, arquivado, sem decisão)
  e, quando houver, a negativa do senador ou dos envolvidos.
- Todo escândalo guarda URLs de fonte; preferir fatos confirmados por mais
  de um veículo, de linhas editoriais diferentes.
- Fato não confirmado em fonte independente não entra (ex.: o resultado do
  2º turno de 2026 ficou de fora).
- Piadas do escândalo (motivos, bilhetes, imprevistos, esconderijos) são
  alusões e nunca afirmam crime como fato.
- Status muda com o tempo — revisar `status` de cada escândalo antes de cada
  release.
