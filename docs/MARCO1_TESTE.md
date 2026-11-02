# Marco 1 — Como testar

Corpos trocáveis, primeiro inimigo, dano e fundo em movimento. Como abrir, exportar e instalar no S24: veja o [`MARCO0_TESTE.md`](MARCO0_TESTE.md).

## O que foi implementado

| Item | Como funciona |
|---|---|
| **4 corpos** | Raio (ciano), Leque (verde), Mísseis (laranja) e Órbita (roxo). Formato e arma vêm de `data/bodies/` e `data/weapons/`. |
| **Armas (nível 1)** | **Raio:** feixe contínuo que para no primeiro inimigo da coluna. **Leque:** 3 tiros abertos em 24°. **Mísseis:** teleguiados ao inimigo mais próximo. **Órbita:** 1 orbital girando em volta da nave, com dano por contato. |
| **Troca de corpo** | Com o dedo solto (câmera lenta), os outros corpos vivos aparecem em arco ao redor da nave. Tocar num ícone troca o corpo (reconstrução + 2 s de invulnerabilidade, piscando). Tocar fora retoma com o corpo atual. |
| **Inimigo** | Hexágono vermelho que desce reto e atira bolas rosa para baixo. 6 de vida. Surge a cada 0,9–1,8 s (`data/stages/stage_01.tres`). |
| **Dano** | A hitbox é só o **núcleo branco** (bem menor que a nave). Tiro inimigo ou encostar num inimigo = 1 hit. Depois de um hit, 1 s de invulnerabilidade. |
| **Perda de corpo** | No 3º hit o corpo some, o núcleo racha e o jogo **fica em câmera lenta até escolher outro corpo**, mesmo com o dedo na tela. Se só sobra um, ele é escolhido sozinho. |
| **Fim de jogo** | Sem corpos vivos: tela "Fim de jogo" com **Jogar de novo** e **Voltar ao menu**. |
| **HUD** | Embaixo à esquerda: hits do corpo ativo. Embaixo à direita: a formação (X = destruído, anel = ativo). |
| **Fundo** | 3 camadas de estrelas descendo em velocidades diferentes. Também desacelera na câmera lenta. |

## O que observar no S24

**Troca de corpo**
- Os ícones aparecem rápido e ficam fáceis de tocar com o polegar? Algum fica escondido sob o dedo ou fora da tela (teste com a nave nos cantos e no topo)?
- A troca parece clara (corpo cresce a partir do núcleo, nave piscando)?
- Tocar fora dos ícones retoma sem trocar?

**Armas**
- Cada corpo parece diferente de jogar? Qual é o mais forte e qual o mais fraco?
- **Órbita:** só causa dano quando o inimigo chega perto, então tende a ser bem mais fraca que as outras. Anotar se faz sentido assim ou se o orbital deveria, por exemplo, também bloquear tiros ou ter um tiro fraco para frente.

**Inimigos e dano**
- Os tiros inimigos (rosa) ficam legíveis contra o fundo e os tiros da nave?
- A hitbox no núcleo parece justa ou tolerante demais?
- 1 s de invulnerabilidade após o hit é bom? (`hit_invulnerability_seconds`, em aberto no GDD)
- Perder um corpo e escolher outro em câmera lenta forçada fica claro?

**Desempenho**
- O overlay mostra FPS e a contagem de tiros, inimigos e tiros inimigos. Anotar se o FPS cai com muitos objetos.

## Onde ajustar

| O quê | Onde |
|---|---|
| Vida, velocidade e tiro do inimigo | `data/enemies/drone.tres` |
| Frequência de inimigos | `data/stages/stage_01.tres` |
| Dano, cadência e forma de cada arma | `data/weapons/*.tres` |
| Formato e cor dos corpos | `data/bodies/*.tres` |
| Corpos da formação (qualquer quantidade) | `data/formations/default.tres` |
| Hits, invulnerabilidade, hitbox, ícones de troca, HUD, fundo | `scripts/core/params.gd` |

Os `.tres` também podem ser editados pelo **Inspector** do Godot (duplo clique no arquivo).
