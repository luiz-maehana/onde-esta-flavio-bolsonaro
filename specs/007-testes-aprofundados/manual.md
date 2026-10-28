# Checklist manual — antes de cada publicação (spec 007, F)

O que a automação não pega: toque, teclado virtual, áudio do navegador,
rede ruim e o armazenamento da versão Web. Leva ~20 minutos.

Anote em cada linha ✔ ou ✘, o aparelho/navegador e, se falhar, o que
apareceu. Bug achado aqui vira teste automatizado quando der.

**Versão:** ______ **Data:** ______ **Quem testou:** ______

## 1. Celular — Android (Chrome) e iPhone (Safari)

| # | Passo | Esperado | Android | iPhone |
|---|-------|----------|---------|--------|
| 1.1 | Abrir o link em 4G | Barra de carregamento avança; título aparece | | |
| 1.2 | Primeiro toque em qualquer botão | Música e efeitos começam (não fica mudo) | | |
| 1.3 | Em pé: título, novo caso, briefing | Tudo legível, nada cortado, botões fáceis de acertar | | |
| 1.4 | TROCAR REPÓRTER → digitar nome | Teclado virtual abre, o campo continua visível acima dele | | |
| 1.4b | Abrir o link pelo **Instagram** (navegador interno) e tocar no campo do nome | Teclado abre; o nome digitado aparece e ASSINAR CONTRATO aceita | | |
| 1.5 | Investigar um local e **girar** durante a fala | Volta na cidade sem perder hora nem anotação | | |
| 1.6 | Viajar e **girar** durante o voo | Chega numa cidade só; relógio anda uma vez | | |
| 1.7 | Abrir dossiê, marcar 2 traços, **girar** | Marcações continuam lá | | |
| 1.8 | Achar o senador e **girar** na última fala | Vai pra capa normalmente | | |
| 1.9 | Deitado: cidade, viagem, capa | Mapa e botões cabem; fala longa rola dentro da caixa | | |
| 1.10 | Mapa: tocar numa cidade que não é destino | Mostra nome e país | | |

## 2. Rede e armazenamento (navegador)

| # | Passo | Esperado | Resultado |
|---|-------|----------|-----------|
| 2.1 | DevTools → rede "Slow 3G", recarregar | Carrega (devagar) com a barra; nenhuma tela branca | |
| 2.2 | No meio do caso, desligar a internet e seguir jogando | Caso continua; contador de online some | |
| 2.3 | Religar a internet | Contador volta em até ~1 min | |
| 2.4 | **Fechar a aba** no meio do caso, abrir de novo | CONTINUAR CASO na mesma cidade, mesma hora | |
| 2.5 | Vencer 2 casos, fechar o navegador, abrir, vencer outro | No ranking você aparece **uma vez**, com o melhor resultado | |
| 2.6 | Duas abas abertas ao mesmo tempo, jogar nas duas | Nenhuma trava; ao recarregar, carreira não some | |
| 2.7 | Aba anônima | Jogo funciona (começa do zero, sem erro) | |
| 2.8 | Opções → rodapé | "Versão vX.Y.Z-N-g<hash>" igual ao commit do deploy no GitHub | |
| 2.9 | Opções → TELA CHEIA (computador e Android) | Entra e sai da tela cheia; depois de Esc o botão mostra NÃO | |

## 3. Windows (.exe)

| # | Passo | Esperado | Resultado |
|---|-------|----------|-----------|
| 3.1 | F11 algumas vezes, inclusive durante o voo | Alterna tela cheia sem travar | |
| 3.2 | Escala do Windows em 150% | Texto nítido, nada fora da janela | |
| 3.3 | Monitor ultrawide (ou janela bem larga) | Laterais preenchidas, nada esticado | |
| 3.4 | Alt+Tab durante o voo e voltar | Voo termina e chega na cidade | |
| 3.5 | Jogar só no teclado (Tab, setas, Enter, Esc) | Dá pra jogar um caso inteiro sem mouse | |

## 4. Ranking online

| # | Passo | Esperado | Resultado |
|---|-------|----------|-----------|
| 4.1 | Primeira vitória com ranking em "perguntar" | Pergunta aparece uma vez; SIM publica | |
| 4.2 | Opções → NÃO PARTICIPAR, vencer | Não aparece no ranking | |
| 4.3 | Abrir RANKING sem internet | Aviso "indisponível", sem travar | |
