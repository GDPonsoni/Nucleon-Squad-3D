# Decisões tomadas na execução autônoma do PLANO_3D

Registro das decisões tomadas sem o Gabriel por perto (regra da seção 7 do `docs/PLANO_3D.md`). Cada item traz a decisão, o motivo e a alternativa descartada. Se alguma não agradar, é só dizer: quase todas são fáceis de trocar.

## D1. Efeitos de chão: a camada 2D inteira vira textura no plano de jogo

- **Decisão:** em vez de refazer cada `draw_arc`/`draw_line` (avisos, feixes, escudo, aura, ondas de choque, explosões, faíscas, números de dano, efeitos das armas) como primitivas 3D, o desenho 2D que já existe é renderizado num `SubViewport` transparente e aplicado como textura num quadrado deitado no plano de jogo (`scripts/render3d/ground_fx.gd`). Os nós 2D do jogo vão para uma camada de visibilidade própria; a tela principal deixa de desenhá-la e o `SubViewport` (que compartilha o mesmo `World2D`) só desenha ela.
- **Motivo:** o plano pedia que "o desenho 2D e o 3D consumam a mesma geometria, para não duplicar regra" e apontava a T9 como a mais arriscada. Assim a geometria é literalmente a mesma: o aviso aparece exatamente onde a colisão acontece, e nenhum efeito fica de fora.
- **Descartado:** `ground_fx.gd` com primitivas (anel, arco, faixa, disco) e um espelho 3D para cada efeito. Seriam dezenas de pontos de desenho duplicados, com risco alto de aviso desalinhado da colisão.
- **Custo:** uma textura do tamanho da tela por quadro. Se pesar no S24, baixar `Params.ground_fx_resolution` (0,5 = metade da resolução).
- **Consequência visual:** esses efeitos ficam "deitados" no plano (sem volume). Naves, inimigos, chefes, projéteis e itens são modelos 3D de verdade por cima.

## D2. Guarda do desenho 2D: `Renderer3D.active` em vez de `Params.render_3d`

- **Decisão:** as entidades deixam de desenhar o próprio corpo em 2D quando existe uma visão 3D em cena (`Renderer3D.active`), não só pelo parâmetro.
- **Motivo:** `Player`, `Companion` e as armas também são usados fora da partida (demonstração na tela de inspeção da nave), onde não há visão 3D. Com a guarda pelo parâmetro, a nave sumiria nessa tela.
- **Descartado:** `if Params.render_3d: return` no começo de cada `_draw()`, como o plano sugeria.

## D3. Seguimento da câmera: máximo de 60 px (o plano sugeria 120)

- **Decisão:** `camera_follow_factor` 0,15 (como no plano), `camera_follow_max_px` 60 e `camera_fit_margin` 60.
- **Motivo:** a garantia "a área jogável nunca é cortada" exige margem ≥ deslocamento máximo, e a margem encolhe tudo na tela. Com 120 px o jogo ficaria 18% menor num celular; com 60 px, 10%. O pedido era um seguimento "leve, só para dar ideia de movimento".
- **Descartado:** 120 px. Para testar, basta mudar os dois valores em `params.gd` (o renderer nunca deixa o seguimento passar da margem).

## D4. Simulação não determinística (já na versão 2D) e a opção `--deterministic`

- **Decisão:** a prova de equivalência (T11) usa a opção nova `--deterministic` do simulador (zera os sons só dentro da ferramenta). Ver `docs/3D_BASELINE.md`.
- **Motivo:** o plano supunha que a mesma semente dá o mesmo resultado. Não dá: `Audio.play` decide pelo relógio real se toca e consome o sorteio global. Duas execuções do 2D original já divergem.
- **Descartado:** consertar o áudio (seria mudar o jogo) ou comparar só por faixa de valores (prova fraca).

## D5. Sorteio global preservado nos `_draw` que deixaram de desenhar

- **Decisão:** onde um `_draw()` usava `randf` (chama do míssil em `bullet.gd`, faíscas do raio em `beam_weapon.gd`), a versão 3D continua consumindo o mesmo sorteio.
- **Motivo:** pular esses sorteios mudaria a sequência global e, com ela, as ondas. A simulação tem de ser idêntica com e sem 3D.
- **Descartado:** trocar esses sorteios por um gerador próprio (mudaria também o 2D em relação à linha de base).

## D6. Matemática da câmera própria (`CameraRig`)

- **Decisão:** enquadramento, seguimento e `project_to_screen` são calculados por uma classe sem nós (`scripts/render3d/camera_rig.gd`); a `Camera3D` só recebe o resultado.
- **Motivo:** dá para testar em headless ("retângulo jogável sempre cabe", "deslocamento máximo respeitado") e o HUD usa exatamente a mesma conta da câmera.
- **Descartado:** `Camera3D.unproject_position`, que depende do nó na árvore e do tamanho real da janela.
