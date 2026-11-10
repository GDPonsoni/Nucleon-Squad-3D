# Roteiro de teste da versão 3D no Galaxy S24

O app 3D se chama **Nucleon Squad 3D** (pacote `com.example.nucleonsquad3d`). Ele **não substitui** o app 2D e tem save próprio: começa do zero. Para liberar tudo, toque 5 vezes no título do seletor de fases (build de debug).

```bash
G=../Godot_v4.7.2-stable_linux.x86_64
ADB=~/Android/Sdk/platform-tools/adb
timeout 300 $G --headless --path . --export-debug "Android" builds/nucleon-squad-3d.apk
$ADB install -r builds/nucleon-squad-3d.apk
$ADB shell monkey -p com.example.nucleonsquad3d 1
```

Erros no celular: `$ADB logcat -d -s godot:*`.

Deixe as **estatísticas na tela** ligadas (Configurações) para ver o FPS.

## 1. Primeira impressão (fase 1-1)

- [ ] A partida abre em 3D: chão em grade rolando, nave com volume, inimigos com volume. HUD, pausa e barra de troca iguais ao 2D.
- [ ] A área de jogo cabe inteira acima da barra de troca. Nada importante fica cortado nas laterais.
- [ ] Mover o dedo: a nave acompanha. **Observe:** no fundo da tela a nave anda um pouco menos que o dedo (perspectiva). Incomoda?
- [ ] A câmera desliza de leve quando a nave vai para os cantos. Incomoda ou dá enjoo? (`camera_follow_factor`, `camera_follow_max_px`)
- [ ] A nave inclina ao andar de lado e baixa o nariz ao avançar.

## 2. Leitura (o mais importante)

- [ ] A 70°, dá para ler os tiros inimigos vindo de longe? Eles se destacam do chão e das estrelas?
- [ ] O **núcleo** (domo claro no meio da nave) é fácil de achar? Ele é a hitbox.
- [ ] O tamanho dos inimigos lá no fundo está bom ou pequeno demais? (`camera_fov_deg`, `camera_pitch_deg`)
- [ ] Os avisos de tiro (linhas tracejadas, anéis) aparecem a tempo e no lugar certo.

## 3. Visual x colisão

- [ ] Um tiro que **parece** passar longe do núcleo nunca acerta, e um que parece acertar, acerta. Se não bater: `bullet_height_3d` (altura dos tiros) ou `nucleus_height_3d`.
- [ ] Encostar num inimigo dá dano quando os modelos se tocam, não antes nem depois.
- [ ] Rochas: bloqueiam tiros onde parecem estar.

## 4. Troca de nave e auxiliar

- [ ] Trocar de nave: o corpo antigo recolhe girando para o núcleo e o novo cresce a partir dele.
- [ ] Perder um corpo: ele quebra em pedaços que tombam; sobra só o núcleo, mais avermelhado a cada corpo perdido.
- [ ] Nave piscando enquanto invulnerável (o modelo fica "pontilhado").
- [ ] Auxiliar (depois do capítulo 2): acompanha ao lado, inclina, recolhe quando a nave fica sem corpo.

## 5. Chefes (1-5, 1-9 e, se der, 3-9 e 5-9)

- [ ] O chefe tem casco, miolo girando, placas, espinhos, torretas que miram em você e olho que te segue.
- [ ] Rachaduras laranja acendem conforme a vida cai; o olho avermelha nas fases finais.
- [ ] **Avisos e perigos aparecem a tempo de desviar:** faixa do laser, varredura, investida, marcadores da chuva, brecha verde da cortina.
- [ ] Entrada por surgimento (cresce do nada) e por queda funcionam.
- [ ] FPS durante a luta.

## 6. Itens e Incursão

- [ ] Power-up (octaedro dourado girando), kit médico (caixa branca com cruz verde), power-up da auxiliar (lilás).
- [ ] Incursão: orbes de XP verdes, baú dourado, elites maiores com aura e barra de vida.

## 7. Desempenho

- [ ] FPS estável em 60 na 1-1.
- [ ] FPS na **5-8** (a mais pesada: até ~450 tiros inimigos) e num chefe do capítulo 5.
- [ ] Se cair: baixar `ground_fx_resolution` para 0,5 em `params.gd` e testar de novo. Anote os dois números.
- [ ] Se ainda cair: `particles_enabled_3d = false` e `scenery_enabled_3d = false`, um de cada vez, para achar o culpado.
- [ ] Aquecimento ou consumo de bateria fora do normal depois de 10 minutos?

## 8. Cenário e partículas

- [ ] Rochas e planetoides escuros passam por baixo do plano de jogo. **Eles atrapalham a leitura dos tiros?** (`scenery_rock_tint_3d` menor = mais discreto; `scenery_enabled_3d = false` desliga)
- [ ] Explosão solta estilhaços na cor do inimigo, que sobem e caem. Acertos soltam fagulhas.
- [ ] Rastro do propulsor atrás da nave, na cor do corpo. Coletar item solta um brilho na cor dele.
- [ ] Com "efeitos visuais reduzidos" ligado nas Configurações: menos rochas e metade das partículas.

## 9. Tutorial e telas

- [ ] Com o save novo, as dicas da 1-1 aparecem e o **recorte iluminado cai em cima do alvo** (nave, inimigo que avisa, item).
- [ ] Tela de esquadrão e inspeção de nave (ⓘ) seguem em 2D, com a nave e a demo da arma visíveis.
- [ ] Pausa, resultado, revive e fim de fase (a nave sobe e sai) funcionam.

## Ajustes sem mexer em código

Tudo em `scripts/core/params.gd`, bloco "Visão 3D":

| Quero… | Parâmetro |
|---|---|
| Câmera mais de cima / mais deitada | `camera_pitch_deg` (90 = de cima) |
| Mais ou menos perspectiva | `camera_fov_deg` |
| Câmera parada | `camera_follow_factor = 0` |
| Jogo maior na tela | `camera_fit_margin` e `camera_follow_max_px` menores (a margem precisa ser ≥ o máximo) |
| Tiros mais coloridos / mais claros | `bullet_core_white_3d` |
| Mais leve | `ground_fx_resolution`, `particles_enabled_3d`, `scenery_enabled_3d` |
| Cenário mais discreto ou mais presente | `scenery_rock_tint_3d`, `scenery_rock_count_3d` |
| Mais ou menos estilhaços | `particle_explosion_amount_3d`, `particle_budget_3d` (teto geral) |
| Voltar ao 2D para comparar | `render_3d = false` |
