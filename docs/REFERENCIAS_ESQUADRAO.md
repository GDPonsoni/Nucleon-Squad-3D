# Referências — naves novas e tela de esquadrão

Pesquisa feita antes de implementar as naves Lança e Artilharia e a tela de montar o esquadrão (02/11/2026).

## Arquétipos de arma em shmups

- **Devlog "Weapon Planning" (Dimensional Drift)** — organiza as armas em arquétipos que mudam a *forma* de acertar, não só os números: tiro rápido (perdoa erros), **laser que atravessa** inimigos em linha (sem tempo de viagem), **foguete explosivo** com dano em área e corpo a corpo em cone. Upgrades devem mudar o jeito de jogar, não só aumentar dano. <https://crelu.itch.io/dimensional-drift/devlog/917163/devlog-weapon-planning>
- **Pixelblog 32 — Shmup Design Part 2 (SLYNYRD)** — geometria, cadência, poder e aparência da arma são ligados: **cadência lenta pede mais dano** e vice-versa; teleguiado ajuda iniciantes mas deve ter o **menor dano**; o laser alarga com upgrades e atravessa alvos. Itens precisam de significado claro, raridade variada e visual que não pareça perigo. <https://www.slynyrd.com/blog/2021/2/15/pixelblog-32-shmup-design-part-2>
- **Gradius — Laser** — laser contínuo que atravessa; tiros "armor piercing" são mais lentos e com mais dano por acerto. <https://community.fandom.com/wiki/w:c:gradius:Laser>
- **Fórum shmups.system11 — armas principais teleguiadas** — diferencia teleguiado de "tracking" (trava no alvo até ele morrer). <https://shmups.system11.org/viewtopic.php?p=1422862>

**Como foi aplicado:** o jogo já tinha raio que para no primeiro inimigo (Raio), leque (Leque), teleguiado (Mísseis) e defesa por contato (Órbita). Faltavam **perfurar** e **dano em área**:

| Nave | Arquétipo | Estratégia | Equilíbrio |
|---|---|---|---|
| **Lança** | perfuração (atravessa inimigos) | filas, colunas de kamikazes, Tanques atrás de outros inimigos | cadência lenta (2,5–3 tiros/s) com dano alto por tiro |
| **Artilharia** | explosão em área | formações agrupadas (V, fileiras) | projétil lento (precisa antecipar), dano dividido em área |

## Referência principal do GDD

- **Squadron — Bullet Hell Shooter (App Store)** — 4 naves para escolher, cada uma com um padrão de tiro; jogadores pedem para escolher as naves do início. Reforça a ideia de montar o esquadrão antes da fase. <https://apps.apple.com/app/id958215499>

## Telas de loadout / esquadrão

- **Design patterns de UX em jogos (GameIndustry)** — reduzir a distância entre intenção e ação; deixar a próxima ação óbvia sem esconder alternativas; confirmar com feedback discreto, sem diálogos extras. <https://www.gameindustry.com/news-industry-happenings/design-patterns-that-keep-players-engaged-in-modern-game-ux>
- **Hunt: Showdown — melhorias de UI** — escurecer o que não importa e destacar o espaço sendo escolhido. <https://www.huntshowdown.com/news/developer-insight-upcoming-ui-improvements>
- **Feedback de jogadores (Battlefield 6, MechWarrior Online)** — evitar trocar de tela para escolher; mostrar espaços ocupados/vazios; botão de salvar claro. <https://forums.ea.com/discussions/battlefield-6-general-discussion-en/the-customize-loadout-user-flow-could-be-improved-by-removing-a-screen-/12453607> · <https://mwomercs.com/forums/topic/149349-ui-20-suggestions>

**Como foi aplicado:** tela única com os 4 espaços no topo (vazios tracejados), cartões de todas as naves com descrição curta da arma e do especial, número do espaço no cartão escolhido, toque para adicionar/remover e Salvar só ativo com o esquadrão completo.
