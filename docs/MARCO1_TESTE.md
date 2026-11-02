# Marco 1 — Como testar

Corpos trocáveis com 5 níveis de arma, power-ups, 5 tipos de inimigo, ondas em formação, chefes, 3 capítulos com 3 fases cada, salvamento local e interface nova. Como abrir, exportar e instalar no S24: veja o [`MARCO0_TESTE.md`](MARCO0_TESTE.md).

## Fluxo de telas

**Menu inicial** (estrelas + nave alternando corpos) → **Esquadrão** (montar os 4 corpos) ou **Jogar** → **Seletor de fases** (por planeta) → **Partida** → **Resultado** (fase concluída ou fim de jogo, com resumo) → próxima fase / jogar de novo / escolher fase / menu. Todas as trocas de tela têm fade.

- A **primeira fase de cada capítulo** está sempre liberada. Concluir uma fase libera a próxima do mesmo capítulo e guarda o recorde no aparelho.
- **Atalho de debug:** no seletor, tocar **5 vezes no título** libera todas as fases (só em build de debug). Para zerar o progresso, desinstale o app ou apague `save.json` (veja abaixo).

## O que foi implementado

| Item | Como funciona |
|---|---|
| **6 naves, esquadrão de 4** | Raio (ciano), Leque (verde), Mísseis (laranja), Órbita (roxo), **Lança** (azul) e **Artilharia** (coral). Na tela **Esquadrão** você escolhe 4 e a ordem (a 1ª começa a fase); a escolha fica salva. Formato e arma vêm de `data/bodies/` e `data/weapons/`. |
| **Lança** | Tiro lento e forte que **atravessa** vários inimigos (2 → todos no nível 5). Boa contra filas, colunas e Tanques. Especial: leque de 7 lanças gigantes. |
| **Artilharia** | Projéteis lentos que **explodem em área** (raio 120 → 190). Boa contra formações. Especial: bombardeio de 12 explosões. |
| **Raio** | Feixes contínuos que param no primeiro inimigo. Nível 1: 1 feixe; 2: **mais grosso**; 3: + 2 feixes laterais a ±5°; 4: todos mais grossos, ±7°; 5: raio central largo + laterais a ±9°. |
| **Leque** | Alterna **projétil maior** e **mais fileiras**: 3 pequenos → 3 grandes → 5 grandes → 5 maiores → 7 grandes. |
| **Mísseis** | Cada onda **surge em anel** ao redor da nave, **mira** por 0,35 s e dispara de uma vez; a próxima onda só vem após uma pausa. 4 → 8 mísseis por onda. Bem mais fraco que antes nos níveis altos. |
| **Órbita** | 1 → 4 orbitais e anel de 8 no nível 5. Dano por contato e **destroem tiros inimigos**. |
| **Continuar com anúncio** | Ao perder todos os corpos: "Continuar?" com contagem de 20 s. **Assistir anúncio** (por enquanto **simulado**, 2,5 s) faz o último corpo usado voltar com a vida cheia e o nível de arma que tinha, do ponto onde parou, invulnerável por 3 s e sem tiros inimigos na tela. Uma vez por partida. Recusar ou deixar o tempo acabar mostra o fim de jogo. |
| **Medkits** | Caixa branca com cruz verde, mais rara que os power-ups (1 a cada 13 inimigos destruídos, contra 8). Recupera 1 hit do corpo ativo (máx. 3), com um anel verde em volta da nave. Com a vida cheia, é gasto sem efeito. |
| **Especial** | Botão no canto inferior esquerdo (acima de hits e nível). O anel enche com o tempo (16–20 s com o corpo ativo); cheio, fica dourado e pulsa. Cada corpo tem a própria carga. **Raio:** raio gigante por 2,5 s + anel que limpa em volta. **Leque:** rajada de 360° + anel que limpa os tiros. **Mísseis:** chuva de mísseis atrás de todos os inimigos. **Órbita:** anel de energia que cruza a tela, limpa tiros e causa dano. Funciona também na câmera lenta. |
| **Power-ups** | Losango dourado a cada 8 inimigos destruídos. Sobe 1 nível da arma do corpo ativo (máx. 5). Perder o corpo zera o nível dele. |
| **Inimigos** | **Drone** (vermelho, desce e atira reto). **Mirador** (magenta, losango): entra pela lateral, cruza a tela e atira mirando a nave. **Kamikaze** (amarelo, triângulo): desce um pouco e mergulha na nave. **Tanque** (grande, octógono): lento, 60 de vida, solta anéis de 12 tiros girando e tira **2 hits** se encostar. |
| **Atirador** | Pentágono verde-água: desce até o alto da tela, para por 4 s disparando leques de 5 tiros mirados e depois segue descendo. Aparece no capítulo 3. |
| **Semeador e Caçador** | **Semeador** (heptágono branco): para no alto e solta orbes lentos com anel externo que **se dividem em 6 tiros**. **Caçador** (triângulo vermelho-laranja): cruza a tela soltando tiros laranja que **perseguem a nave por 1,2 s** e depois seguem reto. Aparecem no capítulo 4. |
| **Ondas em formação** | Além dos surgimentos aleatórios, cada fase tem ondas em momentos fixos: **V de kamikazes** que mergulham um após o outro, fileiras, colunas e Miradores entrando pela lateral em sequência. |
| **Capítulos e fases** | **Aurora** (azul, 1:30 a 2:30), **Vulcânia** (avermelhado, 2:30 a 3:00) e **Abismo** (violeta, **4:00, 4:30 e 5:00**, de 10 a 13 ondas por fase) e **Singularidade** (verde-água escuro, **4 fases de 4:00 a 5:00**, as mais difíceis, com Semeadores e Caçadores). |
| **Chefes** | No fim da última fase de cada capítulo: aviso "ALERTA: CHEFE À FRENTE", o chefe entra (invulnerável até parar) e a barra de vida dele aparece no topo. Muda de ataque conforme a vida cai. A fase só termina quando ele é destruído. **Sentinela** (1-3): rajadas e anel, depois espiral. **Forja** (2-3): leque largo e kamikazes, depois anel giratório. **Umbra** (3-3): três fases com espirais, anéis, leques e Miradores; faz um oito e depois persegue a nave. **Hidra** (4-4, 2200 de vida): quatro fases com orbes que se dividem, rajadas perseguidoras, espirais e kamikazes; balança, faz um oito e persegue a nave. Encostar no chefe tira 2 hits. |
| **Troca de corpo** | Com o dedo solto, uma **faixa fixa na base da tela** mostra todos os corpos (no lugar dos painéis do HUD): o atual com anel branco, os vivos com hits e nível, os **abatidos apagados com um X**. Tocar num corpo vivo troca (+2 s de invulnerabilidade); tocar fora retoma. |
| **Núcleo e câmera lenta** | O núcleo (hitbox) tem borda escura e um anel branco pulsando, mais forte na câmera lenta. Na câmera lenta, uma **moldura azul** aparece nas bordas da tela. Ao subir o nível da arma, um anel dourado se expande em volta da nave. |
| **Dano** | Hitbox = **núcleo branco**. Tiro ou encostar = 1 hit (Tanque: 2). 1 s de invulnerabilidade após o hit. **Flash vermelho** na tela. |
| **HUD** | Topo: barra de progresso da fase, pontuação e nome da fase. Base: nível da arma e hits (esquerda), formação (direita), sobre painéis. |
| **Interface** | Tema próprio (botões arredondados com borda ciano, painéis translúcidos), ícone de pausa desenhado, menus com entrada animada. |

## O que observar no S24

**Esquadrão e naves novas**
- A tela de esquadrão é clara? Dá para entender cada nave pela descrição?
- Lança e Artilharia parecem estratégias diferentes das outras? Alguma ficou fraca ou forte demais?
- A faixa de troca na base fica fácil de ver e tocar? Os abatidos ficam claros?

**Legibilidade**
- O núcleo fica fácil de achar no meio da ação? O anel pulsando incomoda?
- A moldura azul deixa claro quando está em câmera lenta sem atrapalhar a visão?

**Armas (nova versão)**
- **Mísseis:** ficou menos "roubado"? O anel mirando é legível? A pausa entre ondas parece boa?
- **Raio:** cada nível muda visivelmente (mais grosso, novos feixes, ângulo pequeno)? O ângulo de até 9° ficou bom?
- **Leque:** dá para sentir a diferença entre níveis com projétil maior e níveis com mais fileiras?

**Continuar com anúncio**
- A oferta fica clara? 20 s é um bom tempo? Voltar invulnerável por 3 s e com a tela limpa parece justo?

**Medkits**
- A raridade (1 a cada 13 inimigos) está boa? Dá para diferenciar do power-up rapidamente?

**Especial**
- O botão fica fácil de alcançar com o polegar sem atrapalhar o arraste da nave?
- O tempo de recarga (16–20 s) e a força de cada especial estão bons? Algum ficou fraco ou forte demais?

**Ondas e chefes**
- Os orbes do Semeador são reconhecíveis antes de se dividir? Os tiros perseguidores do Caçador forçam o movimento sem ficar injustos?
- A Hidra é desafiadora mas legível? No teste automático: ~95 s com arma no nível 5 e ~165 s no nível 3 (talvez longo demais).
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
| Formato e cor dos corpos / esquadrão inicial / naves disponíveis | `data/bodies/*.tres`, `data/formations/default.tres`, `data/formations/roster.tres` |
| Power-ups, hits, invulnerabilidade, HUD, cores da interface | `scripts/core/params.gd` |
| Liberar todas as fases sem tocar no save | `debug_unlock_all = true` em `params.gd` |
| Começar com as armas em outro nível | `debug_start_weapon_level` em `params.gd` (1 a 5) |

**Save no aparelho:** `user://save.json` (no Android, dentro dos dados do app; no Linux, `~/.local/share/godot/app_userdata/nucleonSquad/save.json`).

Os `.tres` também podem ser editados pelo **Inspector** do Godot (duplo clique no arquivo).
