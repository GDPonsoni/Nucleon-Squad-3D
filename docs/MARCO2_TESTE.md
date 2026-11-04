# Marco 2 — Como testar (campanha de 5 capítulos, evolução, auxiliar e sons)

Como abrir, exportar e instalar no S24: veja o [`MARCO0_TESTE.md`](MARCO0_TESTE.md). O save do aparelho (versão 2) é convertido sozinho na primeira vez que algo é salvo.

## O que mudou

| Item | Como funciona |
|---|---|
| **Campanha** | 5 capítulos × 9 fases. Fase 5 = chefe intermediário, fase 9 = chefe do capítulo. Fases de 1:15 a 3:15. Capítulo novo: **Eclipse** (chefe Corona). |
| **Ondas** | Padrões reconhecíveis que se repetem: cobra de drones, diagonal, bloco, círculo, V e pinça de kamikazes, arco de Miradores. A volta seguinte vem do outro lado e maior. |
| **Seletor** | Uma página por capítulo, setas para trocar, recompensa do capítulo, chefe marcado, visto nas fases concluídas. |
| **Barra de troca** | Fica fixa na base, maior e translúcida. Troque de nave com **toque curto** no ícone, com o dedo solto (câmera lenta). Se o dedo andar ou demorar, vira arraste da nave. |
| **Nave auxiliar** | Espaço no Esquadrão (toque nele, depois na nave). Libera ao concluir o capítulo 1. Segue a nave principal, não leva dano e atira fraco. |
| **Quarks e Núcleo** | Cada inimigo rende quarks. Menu → **Núcleo** para gastar em dano, cadência, especial, casco, escudo, drops, coleta, nível inicial, auxiliar e **Sobrecarga** (sem limite). |
| **Naves novas** | Lança (cap. 2), Artilharia (cap. 3), **Tesla** (cap. 4) e **Ricochete** (cap. 5), liberadas ao concluir o capítulo. |
| **Sons** | 28 efeitos em todas as ações. Volumes e idioma em **Configurações** (menu e pausa). |

## O que observar no S24

**Barra de troca**
- Dá para trocar de nave sem errar o ícone? O espaçamento e o tamanho ficaram bons?
- Apoiar o polegar na barra para voltar a mover a nave troca sem querer? (não deveria)
- A barra translúcida atrapalha a visão durante o jogo?

**Campanha e dificuldade**
- Os padrões de onda ficam reconhecíveis? Dá para prever a próxima?
- 3-x e 4-x (antes quase impossíveis) estão passáveis? Alguma fase ainda injusta?
- O capítulo 5 é difícil na medida? As fases 8 (3-8, 4-8, 5-8) pesam demais?
- Umbra, Hidra e Corona: duração da luta e legibilidade.

**Evolução e quarks**
- Quantos quarks você ganha por fase? A árvore dá sensação de progresso sem ficar fácil demais?
- Os preços estão bons? Algum nó parece inútil ou forte demais?

**Auxiliar e naves novas**
- A auxiliar ajuda de leve sem roubar a cena? Atrapalha a visão?
- Tesla e Ricochete são legíveis e divertidas? Estão fortes ou fracas?

**Sons**
- Algum som alto demais ou baixo demais perto dos outros? Tiros cansam?
- Os controles de volume e a mudança de idioma funcionam?
- Vibração ao levar dano: gostou?

**Desempenho**
- FPS estável nas fases 5-6 a 5-8 (muitos tiros)? Veja o overlay de debug.

## Onde ajustar

| O quê | Onde |
|---|---|
| Dificuldade da campanha (intervalos, orçamento de perigo, vida e tiro por capítulo) | constantes no topo de `scripts/tools/campaign_builder.gd` e depois rodar `build_campaign.gd` |
| Volume de cada som e intervalos | `Params.sfx_gain_db`, `Params.sfx_min_gap` |
| Preços e efeitos da evolução | `data/upgrades/*.tres` |
| Quarks por abate e por fase | `Params.quarks_per_point`, `Params.quarks_stage_clear` |
| Auxiliar (tamanho, posição) e arma dela | `Params.companion_*`, campo `companion` em `data/weapons/*.tres` |
| Quais capítulos liberam o quê | `unlock_chapter` em `data/bodies/*.tres`, `Params.companion_unlock_chapter` |
