# PLANO_3D — Nucleon-Squad-3D

Plano para transformar uma cópia do Nucleon Squad em versão 3D low poly, com câmera de perseguição inclinada. Feito para o Claude Code rodar sozinho no PC durante a noite e para o Gabriel testar no S24 no dia seguinte.

> **Para o Claude Code:** leia `CLAUDE.md`, `docs/ESTADO_ATUAL.md`, o GDD e este arquivo (`docs/PLANO_3D.md`) antes de começar. Siga a seção 7 (regras de execução autônoma). Ninguém estará disponível para responder dúvidas: decida pela leitura mais razoável e registre em `docs/3D_DECISOES.md`.

---

## 1. Decisões fechadas

| Tema | Decisão |
|---|---|
| Visão | Câmera de perseguição atrás da nave, com perspectiva. Inclinação inicial de **70° abaixo da horizontal** (olhando bem de cima), em parâmetro. **Confirmado pelo Gabriel em 2026-11-10** |
| Seguimento | Leve e limitado, só para dar ideia de movimento. A área jogável **nunca** sai inteira da tela |
| Modelos | Low poly facetado (flat shading), gerados por código a partir dos dados que já existem. Sem arte externa |
| Detalhe | Simples: poucas dezenas de faces por nave |
| 2D | O 3D **substitui** a visão 2D. Sem alternância |
| Repositório | `https://github.com/GDPonsoni/Nucleon-Squad-3D` (público), histórico mantido. Pasta local: `Nucleon Squad/nucleon-squad-3D` |
| Escopo da 1ª noite | T0–T12: câmera, chão, naves, inimigos, chefes, projéteis, drops. **Se T0–T12 terminar e sobrar cota, seguir com T13–T14** (cenário e partículas), decisão do Gabriel em 2026-11-10 |
| Branch | Todo o trabalho em `feat/3d-render`. A `main` fica igual à versão 2D até o Gabriel testar e fazer o merge |
| Execução | Uma sessão, tarefas em sequência, **sem subagentes em paralelo** (economia de cota e sem conflito em `game.gd`/`params.gd`). Permissões liberadas em `.claude/settings.local.json` |
| Modelo de IA | Fable em tudo |
| Se algo falhar | Reverter a tarefa, registrar o motivo e seguir para a próxima independente |

---

## 2. Preparação — **FEITA em 2026-11-10**

> Já executada: cópia com histórico em `nucleon-squad-3D`, `origin` apontando para `https://github.com/GDPonsoni/Nucleon-Squad-3D.git`, `main` publicada (`73a6305` + este plano), `.godot/` presente, branch `feat/3d-render` criada a partir da `main`. Os passos abaixo ficam só como registro.

1. No GitHub, criar um repositório **vazio** chamado `Nucleon-Squad-3D` (sem README, sem .gitignore). O GitHub não deixa forkar o próprio repositório na mesma conta, por isso não é um fork.
2. No repositório atual, conferir que o que vale levar está commitado: `git status` limpo e a branch certa.
3. Criar a cópia com histórico e apontar para o novo remote:

```bash
cd "$HOME/Documentos/outros/PROJETOS/Nucleon Squad"
git clone --no-hardlinks nucleon-squad Nucleon-Squad-3D
cd Nucleon-Squad-3D
git checkout <branch-com-o-trabalho-mais-recente>   # se não for a main
git checkout -B main
git remote set-url origin https://github.com/GDPonsoni/Nucleon-Squad-3D.git
git push -u origin main
G=../Godot_v4.7.2-stable_linux.x86_64
timeout 300 $G --headless --path . --import          # gera .godot/ (não vem no clone)
```

A pasta nova fica ao lado da original, então o caminho relativo do Godot continua valendo. Depois abrir o Claude Code dentro de `Nucleon-Squad-3D` e colar o prompt da seção 9.

---

## 3. Arquitetura

**Princípio: a simulação 2D continua sendo a fonte da verdade; o 3D só desenha.**

Motivo (verificado no código): inimigos, projéteis e nave são `Node2D` com posição em pixels, colisão própria por círculos e cerca de 30 pontos que usam `get_viewport_rect()` como limite da arena. Reescrever a simulação em 3D quebraria os testes e o balanceamento. Mantendo-a intacta, as simulações de fase com a mesma seed devem dar **resultado idêntico** ao da versão 2D — isso vira o teste principal de que nada foi quebrado.

- **Mapeamento:** posição 2D `(x, y)` em px vira mundo 3D `(x·S, 0, y·S)`, com `S = Params.world_scale_3d` (comece com 0.01). `y` maior = mais perto da câmera. Inimigos nascem em `y` pequeno, ou seja, longe.
- **Desenho 2D desligado:** os nós 2D continuam existindo e processando, mas o início de cada `_draw()` de entidade de jogo faz `if Params.render_3d: return`. HUD, menus e telas (`scripts/ui`) continuam 2D, por cima do 3D.
- **Pasta nova `scripts/render3d/`:**
  - `renderer_3d.gd`: `Node3D` com `Camera3D`, uma luz direcional, ambiente escuro, chão e a função `project_to_screen(pos2d) -> Vector2`. Entra em `game.gd` **e** em `run_game.gd` (modo run).
  - `mesh_factory.gd`: gera `ArrayMesh` facetado (normais por face) com cache por forma. Funções: `extrude_polygon`, `prism`, `pyramid`, `ring`, `quad`, `icosphere_low`.
  - `entity_views.gd`: espelha jogador, auxiliar, inimigos, chefes, drops. Um `MeshInstance3D` reaproveitado por entidade ativa, sincronizado a cada quadro depois da simulação.
  - `bullet_view.gd`: um `MultiMeshInstance3D` por forma de projétil (um draw call por forma), alimentado pelos pools existentes (`node_pool.gd`).
  - `ground_fx.gd`: primitivas planas no chão (anel, arco, faixa, disco) com material sem sombreamento e transparência.
- **Getters mínimos nas entidades** (cor com flash, visibilidade, raio, orientação) em vez de ler variáveis privadas. Nenhuma mudança de lógica.
- **Parâmetros novos em `params.gd`** (nada de número mágico): `render_3d`, `world_scale_3d`, `camera_pitch_deg`, `camera_fov_deg`, `camera_fit_margin`, `camera_follow_factor`, `camera_follow_max_px`, `camera_follow_smooth`.

---

## 4. Câmera

- Pitch `camera_pitch_deg = 70`, yaw 0, FOV vertical inicial 38° (FOV baixo distorce menos a perspectiva).
- **Enquadramento automático:** calcular altura e distância para o retângulo jogável inteiro caber na tela, respeitando o espaço reservado da barra de troca de corpos (`reserved_bottom` em `game.gd`). Com perspectiva, a borda de cima fica mais estreita que a de baixo: a largura da borda de **baixo** define o enquadramento.
- **Seguimento leve:** `offset = clamp((pos_nave − centro_da_arena) · camera_follow_factor, ±camera_follow_max_px)`, suavizado por `camera_follow_smooth`. Valores iniciais: fator 0.15, máximo 120 px, suavização 6/s.
- **Garantia:** `camera_fit_margin ≥ camera_follow_max_px`, para o seguimento nunca cortar a área jogável. Teste automático para isso.
- O chão rolando (textura em grade ou estrelas) dá a sensação de avanço, independente do seguimento.

---

## 5. Low poly (gerado dos dados existentes)

Estilo: flat shading, cor vinda dos dados, partes internas em `color.darkened(...)`, uma luz direcional, **sem sombras em tempo real** (no máximo uma sombra-mancha barata no chão). Modelos baixos (altura ≤ 0.4 do raio) para o visual não destoar da colisão, que é um círculo plano.

| Elemento | Fonte dos dados | Modelo |
|---|---|---|
| Naves do jogador (8) e auxiliar | `BodyData.shape` (polígono) e `color` | Polígono extrudado com topo afunilado e cockpit claro. Frente = −Z |
| Inimigos comuns | `EnemyData.sides`, `radius`, `color` | Prisma de N lados com topo piramidal baixo e "cristal" interno escuro (hoje `inner` = 0.45 do raio) |
| Rochas | `_rock_shape` em `enemy.gd` | Contorno irregular extrudado, altura variando por vértice com seed determinística |
| Chefes | `BossData.sides`, `radius` e as placas/espinhos de `boss.gd` | Base prismática + espinhos (tetraedros) + placas; rachaduras viram emissão |
| Projéteis | `Bullet.Shape` (RECT, CIRCLE, TRIANGLE) | Caixa, icosfera simples, tetraedro; orientados pela velocidade |
| Power-ups e orbes de XP | `power_up.gd`, `xp_orb.gd` | Octaedro girando |

Orçamento: até ~60 triângulos por inimigo comum, ~300 por chefe, ~24 por projétil. Medir FPS com o `debug_overlay.gd` existente. Meta: 60 FPS no S24.

**Efeitos que afetam a jogabilidade** (hoje feitos de `draw_arc`, `draw_line` etc.): avisos de tiro (telegraphs), feixes, escudo frontal, aura de elite, ondas de choque. Viram primitivas planas no chão via `ground_fx.gd`. O desenho 2D e o 3D devem consumir a mesma geometria calculada, para não duplicar regra.

---

## 6. Tarefas (uma branch de integração `feat/3d-render`, um commit por tarefa)

Cada tarefa só termina com os critérios da seção 7 verdes.

**Marco 1 — base (T0–T3)**
- **T0 Preparação.** Renomear para "Nucleon Squad 3D": `config/name` em `project.godot`, `package/name` e `package/unique_name` em `export_presets.cfg`. Hoje o `unique_name` é `com.example.$genname` (derivado de `config/name`, que é `nucleonSquad`); fixe explicitamente `com.example.nucleonsquad3d` em vez de depender do `$genname`. **Isso é obrigatório:** com o mesmo pacote, o APK 3D sobrescreve o app 2D no S24 e mistura os saves. Atualizar o `CLAUDE.md` da cópia: descrever o projeto como 3D, listar `scripts/render3d/` na estrutura de pastas e registrar que a regra "se algo for ambíguo, pergunte em vez de assumir" fica **suspensa nas execuções autônomas deste plano** (decidir e registrar em `docs/3D_DECISOES.md`). Rodar a linha de base (validate, testes, smoke, regressões, uma simulação de fase com seed fixa) e guardar as saídas em `docs/3D_BASELINE.md`. Falhas que já existiam são registradas, não consertadas.
- **T1 Esqueleto.** `Params.render_3d`, `renderer_3d.gd` com câmera, luz, ambiente e chão; ligar em `game.gd` e `run_game.gd`; desligar o desenho 2D das entidades. Aceite: partida abre sem erro de script e a suíte continua verde.
- **T2 Mapeamento e câmera.** Conversão 2D→3D, enquadramento automático, seguimento limitado, `project_to_screen`. Testes puros: retângulo jogável sempre cabe; deslocamento máximo respeitado.
- **T3 MeshFactory.** Geradores e cache. Testes: contagem de triângulos dentro do orçamento, normais por face, geração determinística.

**Marco 2 — jogável nos capítulos iniciais (T4–T6)**
- **T4** Jogador, auxiliar, troca de corpo e `body_fx`.
- **T5** Inimigos comuns, rochas e elites.
- **T6** Projéteis do jogador e inimigos (`MultiMesh`).

**Marco 3 — chefes e avisos (T7–T9)**
- **T7** Chefes.
- **T8** Power-ups, orbes de XP e drops.
- **T9** Efeitos de chão que afetam a jogabilidade: telegraphs de inimigos e chefes, feixes (`beam_weapon`, `giant_beam`), escudo, aura de elite, onda de choque. **Maior risco de ficar incompleto** (muitos `draw_*`). Sem isso, as lutas de chefe ficam injustas: se não terminar, registrar em destaque em `docs/3D_PENDENCIAS.md`.

**Marco 4 — acabamento (T10–T12)**
- **T10** Sobreposições 2D que dependem de posição na tela, reposicionadas com `project_to_screen`: números de dano, destaque do tutorial (`tip_spotlight`), barras de vida.
- **T11 Prova de equivalência.** Rodar `simulate_stages.gd` (capítulos 1 e 5, mesma seed da linha de base) e comparar com `docs/3D_BASELINE.md`. Diferença na simulação = bug do 3D.
- **T12 Documentação e build.** Atualizar `docs/ESTADO_ATUAL.md` e o README; criar `docs/3D_TESTE.md` (roteiro de teste no S24) e `docs/3D_RELATORIO_NOITE.md`. Exportar `builds/nucleon-squad-3d.apk`. Instalar no S24 **só se** `adb devices` listar o aparelho (o pacote é diferente do 2D, então não sobrescreve nada).

**Marco 5 — cenário e partículas (T13–T14, só se T0–T12 terminar com cota sobrando)**
- **T13 Cenário de fundo.** Planetas, rochas de fundo e camadas de paralaxe em 3D, abaixo do plano de jogo (y negativo), sem colisão e sem afetar a simulação. Dados em `data/` só se já existirem dados de cenário; senão gerar por código com seed determinística por fase. Parâmetros em `params.gd` (`scenery_*`). Deve contrastar pouco com os projéteis, para não atrapalhar a leitura.
- **T14 Partículas.** Explosões, faíscas de acerto, rastro dos propulsores e coleta de drops em 3D. Usar `GPUParticles3D` ou `CPUParticles3D` **com pool** (nada de instanciar por evento) e teto de partículas em `params.gd`. Medir FPS na tela de debug numa luta de chefe antes e depois, e registrar em `docs/3D_RELATORIO_NOITE.md`. Se o FPS cair abaixo de 55 no headless/estimativa, reduzir o teto em vez de remover.

Depois de T14 (ou se a cota acabar): parar, escrever o relatório. Não inventar tarefas além de T14.

---

## 7. Regras de execução autônoma

**Depois de cada tarefa**, nesta ordem:
1. `timeout 120 $G --headless --path . --quit` sem `SCRIPT ERROR` nem `Parse Error`.
2. `validate_project.gd`, `tests/run_tests.gd`, `tests/ui_smoke_run.gd`, `tests/match_regressions_run.gd` (comandos em `docs/ESTADO_ATUAL.md`).
3. Procurar dados sensíveis no que vai subir (chaves, keystores, senhas, tokens, APK). O repositório é público.
4. Commit em Conventional Commits, em português, escopo pela pasta (`feat(render3d): ...`; se precisar de escopo novo, registrar em `CONTRIBUTING.md`). Rodapé de coautoria conforme a instrução da sessão. `git push origin feat/3d-render`.

**Se uma tarefa falhar** após 3 tentativas diferentes: desfazer (`git reset --hard` para o último commit bom), registrar em `docs/3D_PENDENCIAS.md` (tarefa, erro, o que foi tentado) e seguir para a próxima tarefa independente. Dependências: T4–T10 e T13–T14 dependem de T1–T3. T12 (documentação e APK) roda **antes** de T13, para haver uma build boa garantida; ao fim de T14, refazer a build e atualizar os documentos. **Se T1, T2 ou T3 falharem, parar** e escrever o relatório: nada além disso funciona sem elas.

**Não fazer:** alterar lógica de simulação, `data/` ou balanceamento (se parecer necessário, registrar em vez de mudar); deixar build temporária ou `debug_*` alterado; fazer merge na `main`.

**Cota:** o limite semanal do Gabriel estava em 70% de uso. Ao fim de cada marco, deixar o repositório consistente e `docs/3D_PENDENCIAS.md` atualizado com o ponto de retomada. Se aparecer aviso de limite, terminar a tarefa atual, commitar, dar push e parar.

**Dúvidas:** decidir, registrar em `docs/3D_DECISOES.md` (decisão + alternativa descartada) e seguir. Isso substitui, só para esta execução, a regra do `CLAUDE.md` de perguntar em caso de ambiguidade, porque ninguém estará disponível para responder. Em sessões com o Gabriel presente, a regra original volta a valer.

---

## 8. Roteiro de teste manual no S24 (resumo; versão completa em `docs/3D_TESTE.md`)

- A 70°, dá para ler os projéteis inimigos vindo de longe? A escala dos modelos está boa?
- O visual bate com a colisão? (acerto "visualmente" fora do alcance é bug de escala ou altura)
- O seguimento da câmera incomoda? Algo some na borda da tela?
- Avisos de chefe e feixes aparecem a tempo de desviar?
- FPS estável em chefes e telas cheias de tiros?
- Troca de corpo, auxiliar, modo run e tutorial funcionam?

Ajustes sem mexer em código: `camera_pitch_deg`, `camera_fov_deg`, `camera_follow_*`, `world_scale_3d` em `params.gd`.

---

## 9. Prompt para colar no Claude Code

> Leia `CLAUDE.md`, `docs/ESTADO_ATUAL.md`, o GDD e `docs/PLANO_3D.md`. Execute o plano da seção 6 na ordem (T0–T12; depois T13–T14 se sobrar cota), seguindo as regras da seção 7. Trabalhe na branch `feat/3d-render`, sem subagentes em paralelo. Responda em português. Ao terminar (ou ao parar), escreva `docs/3D_RELATORIO_NOITE.md`.

---

## 10. Riscos conhecidos

- **Legibilidade:** com perspectiva, inimigos distantes ficam menores. Só o teste no aparelho confirma.
- **Headless não mostra imagem:** a validação automática prova que a simulação e os scripts estão corretos, não que o visual ou o controle estão bons.
- **Hitbox vs. visual:** a colisão é um círculo plano; modelos com altura podem parecer "passar" pelos tiros.
- **T9 é o item mais provável de ficar incompleto** (efeitos de chão).
- **Cota semanal** reduzida; plano em marcos para isso.
- **Estado da branch:** conferido em 2026-11-10. A `main` (`73a6305`) contém todas as branches locais; nenhuma tem commit fora dela.
