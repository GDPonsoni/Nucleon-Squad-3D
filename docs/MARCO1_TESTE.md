# Marco 1 — Como testar

Corpos trocáveis com 5 níveis de arma, power-ups, 5 tipos de inimigo, ondas em formação, chefes, 3 capítulos com 3 fases cada, salvamento local e interface nova. Como abrir, exportar e instalar no S24: veja o [`MARCO0_TESTE.md`](MARCO0_TESTE.md).

## Fluxo de telas

**Menu inicial** (estrelas + nave alternando corpos) → **Jogar** → **Seletor de fases** (por planeta) → **Partida** → **Resultado** (fase concluída ou fim de jogo, com resumo) → próxima fase / jogar de novo / escolher fase / menu. Todas as trocas de tela têm fade.

- Fases começam travadas, exceto a 1-1. Concluir uma fase libera a próxima e guarda o recorde no aparelho.
- **Atalho de debug:** no seletor, tocar **5 vezes no título** libera todas as fases (só em build de debug). Para zerar o progresso, desinstale o app ou apague `save.json` (veja abaixo).

## O que foi implementado

| Item | Como funciona |
|---|---|
| **4 corpos** | Raio (ciano), Leque (verde), Mísseis (laranja) e Órbita (roxo). Formato e arma vêm de `data/bodies/` e `data/weapons/`. |
| **Raio** | Feixes contínuos que param no primeiro inimigo. Nível 1: 1 feixe; 2: **mais grosso**; 3: + 2 feixes laterais a ±5°; 4: todos mais grossos, ±7°; 5: raio central largo + laterais a ±9°. |
| **Leque** | Alterna **projétil maior** e **mais fileiras**: 3 pequenos → 3 grandes → 5 grandes → 5 maiores → 7 grandes. |
| **Mísseis** | Cada onda **surge em anel** ao redor da nave, **mira** por 0,35 s e dispara de uma vez; a próxima onda só vem após uma pausa. 4 → 8 mísseis por onda. Bem mais fraco que antes nos níveis altos. |
| **Órbita** | 1 → 4 orbitais e anel de 8 no nível 5. Dano por contato e **destroem tiros inimigos**. |
| **Medkits** | Caixa branca com cruz verde, mais rara que os power-ups (1 a cada 13 inimigos destruídos, contra 8). Recupera 1 hit do corpo ativo (máx. 3), com um anel verde em volta da nave. Com a vida cheia, é gasto sem efeito. |
| **Especial** | Botão no canto inferior esquerdo (acima de hits e nível). O anel enche com o tempo (16–20 s com o corpo ativo); cheio, fica dourado e pulsa. Cada corpo tem a própria carga. **Raio:** raio gigante por 2,5 s + anel que limpa em volta. **Leque:** rajada de 360° + anel que limpa os tiros. **Mísseis:** chuva de mísseis atrás de todos os inimigos. **Órbita:** anel de energia que cruza a tela, limpa tiros e causa dano. Funciona também na câmera lenta. |
| **Power-ups** | Losango dourado a cada 8 inimigos destruídos. Sobe 1 nível da arma do corpo ativo (máx. 5). Perder o corpo zera o nível dele. |
| **Inimigos** | **Drone** (vermelho, desce e atira reto). **Mirador** (magenta, losango): entra pela lateral, cruza a tela e atira mirando a nave. **Kamikaze** (amarelo, triângulo): desce um pouco e mergulha na nave. **Tanque** (grande, octógono): lento, 60 de vida, solta anéis de 12 tiros girando e tira **2 hits** se encostar. |
| **Atirador** | Pentágono verde-água: desce até o alto da tela, para por 4 s disparando leques de 5 tiros mirados e depois segue descendo. Aparece no capítulo 3. |
| **Ondas em formação** | Além dos surgimentos aleatórios, cada fase tem ondas em momentos fixos: **V de kamikazes** que mergulham um após o outro, fileiras, colunas e Miradores entrando pela lateral em sequência. |
| **Capítulos e fases** | **Aurora** (azul, 1:30 a 2:30), **Vulcânia** (avermelhado, 2:30 a 3:00) e **Abismo** (violeta, **4:00, 4:30 e 5:00**, todos os inimigos e de 10 a 13 ondas por fase). |
| **Chefes** | No fim da última fase de cada capítulo: aviso "ALERTA: CHEFE À FRENTE", o chefe entra (invulnerável até parar) e a barra de vida dele aparece no topo. Muda de ataque conforme a vida cai. A fase só termina quando ele é destruído. **Sentinela** (1-3): rajadas e anel, depois espiral. **Forja** (2-3): leque largo e kamikazes, depois anel giratório. **Umbra** (3-3): três fases com espirais, anéis, leques e Miradores. Encostar no chefe tira 2 hits. |
| **Troca de corpo** | Com o dedo solto, os outros corpos vivos aparecem **em colunas ao lado da nave** (fora do caminho dos raios; perto de uma borda, vão para o lado livre). Cada ícone mostra os hits e, num anel dourado, o nível da arma. Tocar num ícone troca o corpo (+2 s de invulnerabilidade). |
| **Núcleo e câmera lenta** | O núcleo (hitbox) tem borda escura e um anel branco pulsando, mais forte na câmera lenta. Na câmera lenta, uma **moldura azul** aparece nas bordas da tela. Ao subir o nível da arma, um anel dourado se expande em volta da nave. |
| **Dano** | Hitbox = **núcleo branco**. Tiro ou encostar = 1 hit (Tanque: 2). 1 s de invulnerabilidade após o hit. **Flash vermelho** na tela. |
| **HUD** | Topo: barra de progresso da fase, pontuação e nome da fase. Base: nível da arma e hits (esquerda), formação (direita), sobre painéis. |
| **Interface** | Tema próprio (botões arredondados com borda ciano, painéis translúcidos), ícone de pausa desenhado, menus com entrada animada. |

## O que observar no S24

**Legibilidade**
- O núcleo fica fácil de achar no meio da ação? O anel pulsando incomoda?
- A moldura azul deixa claro quando está em câmera lenta sem atrapalhar a visão?
- Os ícones de troca em colunas ficam fáceis de ver e tocar com a nave no centro, nos cantos e no topo?

**Armas (nova versão)**
- **Mísseis:** ficou menos "roubado"? O anel mirando é legível? A pausa entre ondas parece boa?
- **Raio:** cada nível muda visivelmente (mais grosso, novos feixes, ângulo pequeno)? O ângulo de até 9° ficou bom?
- **Leque:** dá para sentir a diferença entre níveis com projétil maior e níveis com mais fileiras?

**Medkits**
- A raridade (1 a cada 13 inimigos) está boa? Dá para diferenciar do power-up rapidamente?

**Especial**
- O botão fica fácil de alcançar com o polegar sem atrapalhar o arraste da nave?
- O tempo de recarga (16–20 s) e a força de cada especial estão bons? Algum ficou fraco ou forte demais?

**Ondas e chefes**
- As ondas de kamikaze em V são desviáveis? O mergulho em sequência fica claro?
- Os chefes são legíveis (espirais e anéis) e a duração da luta é boa? No teste automático: ~30 s com arma no nível 5, ~75–100 s com arma no nível 3.
- O aviso antes do chefe chama atenção suficiente?
- As fases de 4 a 5 minutos do Abismo ficaram longas demais para jogar no celular?

**Inimigos e fases**
- A dificuldade sobe de forma sensata de 1-1 até 2-3? Alguma fase ficou injusta ou fácil demais?
- **Kamikaze** é possível de desviar? **Mirador** atira demais? **Tanque**: os anéis ficam legíveis com outros tiros na tela?
- A duração das fases (1:30 a 3:00) está boa para jogar no celular?

**Interface**
- Menu, seletor, HUD e resultados ficaram claros e fáceis de tocar?
- A barra de progresso e a pontuação atrapalham a visão do jogo (topo da tela)?
- O flash vermelho do hit é útil ou incomoda?

**Salvamento**
- Concluir uma fase, fechar o app e abrir de novo: a próxima continua liberada e o recorde aparece?

**Desempenho**
- Na 2-3 (com tanques), o FPS se mantém? O overlay mostra a contagem de objetos (no teste automático: até ~60 tiros inimigos e 10 inimigos ao mesmo tempo).

## Onde ajustar

| O quê | Onde |
|---|---|
| Inimigos (vida, velocidade, movimento, tiro, pontos) | `data/enemies/*.tres` |
| Fases (duração, inimigos, pesos, frequência, ondas, chefe) | `data/stages/*.tres` (ondas como sub-recursos `WaveData`) |
| Chefes (vida, movimento, fases e ataques) | `data/bosses/*.tres` |
| Planetas (nome, cores, fases) e ordem da campanha | `data/planets/*.tres`, `data/campaign.tres` |
| Valores de cada nível de arma e do especial | `data/weapons/*.tres` (um sub-recurso por nível; especial no grupo "Especial") |
| Formato e cor dos corpos / formação | `data/bodies/*.tres`, `data/formations/default.tres` |
| Power-ups, hits, invulnerabilidade, HUD, cores da interface | `scripts/core/params.gd` |
| Liberar todas as fases sem tocar no save | `debug_unlock_all = true` em `params.gd` |
| Começar com as armas em outro nível | `debug_start_weapon_level` em `params.gd` (1 a 5) |

**Save no aparelho:** `user://save.json` (no Android, dentro dos dados do app; no Linux, `~/.local/share/godot/app_userdata/nucleonSquad/save.json`).

Os `.tres` também podem ser editados pelo **Inspector** do Godot (duplo clique no arquivo).
