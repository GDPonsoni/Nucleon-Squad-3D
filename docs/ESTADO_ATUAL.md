# Estado atual e guia de retomada

Documento para retomar o projeto em uma conversa nova (Claude Code ou outra pessoa). Atualizado em **09/11/2026** (revisão de progressão, branch `feat/revisao-progressao`). A `main` no GitHub está em `f35ba59` (duração de 5 min).

> **Para o Claude Code:** leia este arquivo, o `CLAUDE.md` e o GDD antes de começar. Depois de cada entrega relevante, atualize as seções "O que existe" e "Pendências" daqui.

---

## 1. Ambiente nesta máquina

| Item | Onde |
|---|---|
| Projeto (repo git) | `~/Documentos/outros/PROJETOS/Nucleon Squad/nucleon-squad` |
| Godot 4.7.2 (não está no PATH) | `../Godot_v4.7.2-stable_linux.x86_64` (pasta acima do repo) |
| adb | `~/Android/Sdk/platform-tools/adb` |
| Android SDK / build-tools | `~/Android/Sdk` (build-tools 35.0.1) |
| GitHub | <https://github.com/GDPonsoni/nucleon-squad> (público), branch `main` |
| Pacote Android | `com.example.nucleonsquad` |
| Celular de teste | Galaxy S24, por USB com depuração ativa |

### Comandos do dia a dia (rodar dentro do repo)

```bash
G=../Godot_v4.7.2-stable_linux.x86_64
ADB=~/Android/Sdk/platform-tools/adb

# Validar scripts (sem SCRIPT ERROR / Parse Error)
timeout 120 $G --headless --path . --quit

# Exportar APK de debug, instalar e abrir no S24
timeout 300 $G --headless --path . --export-debug "Android" builds/nucleon-squad.apk
$ADB install -r builds/nucleon-squad.apk
$ADB shell monkey -p com.example.nucleonsquad 1

# Regerar os PNGs do ícone depois de editar os SVGs
$G --headless --path . -s res://scripts/tools/render_icons.gd
```

**Ferramentas e testes (headless, no repo):**

```bash
# Valida todos os scripts e recursos
$G --headless --path . -s res://scripts/tools/validate_project.gd
# Testes de lógica (save, migração, evolução, áudio, campanha)
$G --headless --path . -s res://tests/run_tests.gd
# Abre todas as telas e a partida em PT e EN, clicando nos botões
$G --headless --path . -s res://tests/ui_smoke_run.gd
# Regressões da partida (toques no especial, alvos liberados quando o chefe morre)
$G --headless --path . -s res://tests/match_regressions_run.gd
# Joga fases com piloto automático e mede dificuldade (hits que levaria, duração de chefe)
$G --headless --path . --fixed-fps 60 -s res://scripts/tools/simulate_stages.gd -- --chapter 5 --level 1 --seed 1
# Regera as 45 fases (sobrescreve data/stages, planets e campaign.tres)
$G --headless --path . -s res://scripts/tools/build_campaign.gd
```

O simulador aceita `--stages`, `--chapter`, `--squad a,b,c,d`, `--companion id`, `--upgrades damage=3,...`, `--expected` (Dano e Cadência no poder esperado de cada capítulo: é a medida de dificuldade "alinhada"), `--mode survival` e `--boss-only`. Depois de criar scripts ou recursos novos, rode `--import` uma vez para gerar os `.uid`. Scripts de ferramenta que usam os autoloads precisam de um arquivo `-s` mínimo que só carrega o resto no primeiro quadro (veja `simulate_stages.gd`).

---

## 2. Fluxo de trabalho combinado com o Gabriel

- Conversa em **português**. Commits em **Conventional Commits** em português (ver `CONTRIBUTING.md`), um por mecânica.
- **Antes de cada commit, procurar dados sensíveis** (chaves, keystores, senhas, tokens, APK) no que vai subir; o repositório é público. `builds/`, `.godot/` e keystores já estão no `.gitignore`.
- **Branch por tarefa** (`feat/...`, `fix/...`, `docs/...`). Quando o Gabriel diz "pode mesclar na main", fazer `git merge --ff-only`, `git push origin main` e apagar a branch.
- Ao terminar uma tarefa: **validar no Godot headless**, exportar e **instalar no S24** quando o celular estiver conectado, e dizer em 2–4 linhas o que testar.
- **Builds temporárias de teste** (por exemplo, com `debug_start_weapon_level` alterado) devem ser **substituídas pela build normal** logo depois. Uma build de nível 5 esquecida no celular já causou um falso relato de "power-up não muda nada".
- Ao perguntar algo ao Gabriel, oferecer opções objetivas.

---

## 3. O que existe (resumo do jogo)

**Interface:** botões com relevo e variação de ação principal (`PrimaryButton`); a nave auxiliar é escolhida numa fileira própria no Esquadrão (não pode repetir uma nave do esquadrão) e não tem núcleo.

**Fluxo de telas:** `menu.tscn` (Jogar / Esquadrão / Núcleo / Configurações; sair pelo Voltar do Android) → `stage_select.tscn` (mapa de um planeta por página; cabeçalho fixo; deslizar troca de planeta; depois do último planeta, uma página "novos capítulos em breve") → `game.tscn`. Também `squad.tscn`, `upgrades.tscn` e `settings.tscn`. Caminhos em `scripts/core/scene_paths.gd`.

**Partida:**
- Controle relativo por toque/mouse. Soltar o dedo ativa a câmera lenta (0,3) com moldura azul. **Custo:** na lenta voluntária as armas seguram o tiro (`CombatContext.weapons_hold`, `Weapon.holding()`) e a energia (`TimeController.energy`, tempo real) esvazia em `slowmo_energy_seconds` (3 s) e recarrega com o dedo na tela em `slowmo_recharge_seconds` (6 s); abaixo de `slowmo_min_energy` (15%) não ativa; vazia volta ao normal. Barra em `SlowMotionOverlay`. Lenta forçada e a do começo da fase não gastam.
- **Barra de troca de nave** fixa na base, translúcida enquanto o dedo move a nave e nítida na câmera lenta. A troca é um **toque curto** num corpo; se o dedo andar ou demorar mais que 0,35 s, vira arraste normal (evita trocas sem querer). A nave não desce além da barra. Hits e nível de cada corpo aparecem na própria barra. **Recarga entre trocas** voluntárias (`switch_cooldown_seconds`, 4 s) com setor escuro nos ícones; invulnerabilidade da troca de 1,0 s. As duas contam em tempo de jogo (escalam com a câmera lenta).
- Esquadrão de 1 a 4 corpos (`Params.squad_size` = máximo; `SaveGame.set_squad` guarda só as escolhidas), 3 hits cada (mais com o Casco da evolução). O núcleo é a hitbox.
- **Nave auxiliar** (opcional, espaço liberado ao concluir o capítulo 2, quando já há 2 naves fora do esquadrão): versão pequena de uma nave que acompanha a principal ao lado, não leva dano e atira uma versão fraca da arma (`WeaponData.companion_levels`, 3 níveis). Cada arma tem um papel como auxiliar: Raio foco, Leque flancos, Mísseis caça-grandões, Órbita escudo em volta da nave principal, Lança perfuração, Artilharia área, Tesla defesa próxima (360°), Ricochete enxame. Power-up raro lilás (2 por fase, por tempo, só enquanto ela pode subir) sobe o nível dela na partida, com aviso na tela.
- **Tela de esquadrão:** 4 vagas + vaga da auxiliar no topo e grade de naves (ícone, nome e ⓘ). Tocar põe na 1ª vaga livre; com o esquadrão cheio, vira a auxiliar; tocar de novo (ou na vaga) tira. A nave voa animada entre grade e vaga. O ⓘ abre a inspeção (`ShipInspect`): nave grande, demo ao vivo da arma (`WeaponDemo`, alvos `TrainingTarget`) na versão principal (níveis 1–5) ou auxiliar (1–3), descrição curta e botões de esquadrão/auxiliar.
- **8 naves:**

  | Nave | Arma | Especial | Liberada |
  |---|---|---|---|
  | Raio | BEAM | raio gigante + anel que limpa tiros | início |
  | Leque | SPREAD | rajada 360° + anel | início |
  | Mísseis | HOMING | chuva de mísseis em todos | início |
  | Órbita | ORBIT | anel de energia | início |
  | Lança | PIERCE | leque de lanças gigantes | cap. 1 |
  | Artilharia | BLAST | bombardeio | cap. 2 |
  | Tesla | CHAIN | tempestade de raios em todos | cap. 3 |
  | Ricochete | BOUNCE | 16 orbes que ricocheteiam | cap. 4 |

  "Liberada" = concluir o capítulo (fase 9). Está em `BodyData.unlock_chapter`; a auxiliar em `Params.companion_unlock_chapter` (2). O cap. 5 não libera nada até virem novos capítulos.
- 5 níveis de arma por power-up, kits médicos (poucos, por tempo), excedente vira pontos (`powerup_overflow_points`, `medkit_overflow_points`), especial que carrega com o tempo (`special_charge_multiplier`, hoje 1,5), revive por anúncio simulado (`AdService`).
- **Quarks:** a renda vem de concluir fases (`quarks_stage_clear` por capítulo, dobrado na 1ª vez), de estrelas novas (`quarks_per_new_star`) e de vagas vazias no esquadrão (+25% cada, `quarks_empty_slot_bonus`); abates dão só 1% da pontuação (`quarks_per_point`). Cálculo em `SaveGame.clear_bonus`. Guardados ao fim da partida, mesmo ao perder ou sair. Meta: árvore com limite completa por volta do fim do cap. 4 (`test_quark_economy`).
- **Evolução do núcleo** (`upgrades.tscn`, `data/upgrade_tree.tres`, `data/upgrades/*.tres`): 12 nós com limite de níveis em 3 ramos (Ataque, Defesa, Suporte) + **Sobrecarga**, a única sem limite (custo linear). Árvore com limite: 16.515 quarks. Reparo e Arsenal encurtam o intervalo de kits e power-ups (em %). Bônus calculados em `UpgradeTreeData.boosts_for` → `PlayerBoosts` (no `CombatContext` e no `MatchState`).
- **Áudio** (`Audio`, autoload): 28 efeitos em `assets/audio/sfx`, com ganho por som em `Params.sfx_gain_db` e intervalo mínimo em `Params.sfx_min_gap`. **Músicas** em `assets/audio/music` (menu e um tema por capítulo, em laço, com troca suave), geradas por `python3 scripts/tools/gen_music.py` (Python puro). Barramentos SFX e Música.
- **Anúncios (simulados, `AdService`):** janela "Ganhar quarks" (`AdOfferPopup`) ao tocar no saldo (menu inicial e Núcleo) ou ao tentar comprar sem saldo (5 por dia, 80 + 40 por capítulo concluído). Banner reservado no rodapé do menu inicial com 90 dp de altura (cabe o padrão de 50 dp e o adaptativo do AdMob), em `make_banner_placeholder`, a trocar pelo SDK.
- **Configurações** (menu e pausa): volume geral/música/efeitos, vibração, efeitos visuais reduzidos, estatísticas na tela (FPS e contadores, para esconder ao mostrar a demo), idioma (lista: automático, português, inglês, espanhol). Salvas em `SaveGame.settings`.

**Contador de dano:** `DamageNumbers` (`scripts/weapons/damage_numbers.gd`, em `CombatContext.damage_numbers`) mostra números que sobem onde o inimigo foi atingido (`DamageNumber`, pooled). Acertos no mesmo alvo em `damage_number_window` (0,2 s) viram um número com a soma (Raio e rajadas não enchem a tela). Cor: branco normal, dourado fraqueza, cinza resistência. Configurações: ícone de estrela "Dano" (`SaveGame.settings.damage_numbers`, ligado por padrão). Params `damage_number_*`.

**Balanceamento v2 (06/11/2026, branch `feat/balanceamento-v2`):**
- **Drops por tempo:** `PowerUpDropper` segue o relógio da fase para tudo: power-ups de arma (`powerups_per_stage` 15 em 75% da duração), kits (`medkits_per_stage` 2 em 90%) e auxiliar (`companion_powerups_per_stage` 2 em 70%), caindo no próximo abate (acumula até 2). Arsenal e Reparo encurtam o intervalo, com piso `drop_interval_floor` (40%).
- **Armas:** `WeaponData.damage_scale` (só armas, não especiais). Raio 0,7, Lança 0,65, Leque 1,15, Artilharia 1,25, Ricochete 1,4, Mísseis 2,0, Órbita 1,2, Tesla 1,0. Medido com `--boss-only` (nível 5, 3-9): chefe cai em 77 a 112 s nas armas que o piloto automático usa bem (Órbita e Tesla ele não mede, ficam de fora).
- **Chefes** (`Boss._tuned`, `BalanceData`): vida ×1,6 (intermediários ×1,5), ataques com intervalo ≥ 1 s mais rápidos por capítulo (`boss_interval_by_chapter`) e uma fase final de fúria (últimos 25% da vida: ataques ×0,7 de intervalo, tiros ×1,12, balanço ×1,2, sem rearmar o momento de especial).
- **Duração (alvo 5 min por partida):** fases comuns 300 s, intermediário 210 s e chefe 200 − 25·capítulo s de ondas; a luta do chefe completa (medido: 1-9 ≈ 4,1 min, 3-9 ≈ 4,7, 5-9 ≈ 6,5 no piloto automático). `SAFETY_SECONDS` do simulador subiu para 1000.
- **Camada de ação** (`_add_action_waves` no `campaign_builder`): ondas que não atiram (kamikazes, faíscas, enxames, serpentes, conforme o capítulo) a cada ~3,4 a 4,4 s entre os motivos, e um surto de 3 ondas a cada 60 s. Mais movimento e abates sem mais tiros. Medido (piloto automático): abates por fase 2 a 4× maiores (ex.: 3-4 de ~190 para ~790); hits/min subiram pouco (3-4: 8,8 → 12,2; 1-3: 2,9 → 4,3). A 5-8 já era a mais pesada (≈ 24 → 29 hits/min, tiros inimigos 354 em média, pool de inimigos cheio): revisar se o teste no aparelho pedir.
- Os números de dificuldade desse bloco ficaram defasados: veja "Revisão de progressão" abaixo.

**Modo roguelike "Incursão" (nome provisório, branch `feat/modo-roguelike`), etapas (a) e (b):**
- Cena `scenes/run.tscn` → `scripts/run/run_game.gd`, que **estende** `game.gd` pelos ganchos "Modo" do fim do arquivo (`_formation`, `_stage`, `_uses_switcher`, `_special_weapon`, `_on_enemy_killed`, `_spawn_boss`, `_after_boss_killed`, `_on_boss_sequence_done`...). A campanha usa os padrões.
- Regras em `data/run/run_mode.tres` (`RunModeData`, gerado à mão por script; editar os campos direto): nave branca `white_body` (ataque frontal `pulse_weapon`, fixo, fora dos espaços), 5 hits + Casco, 3 espaços, 4 opções por nível, XP por tabela, orbes, diretor, elites, chefes e itens.
- **Fluxo:** começa só com o ataque frontal; a 1ª arma vem no 1º nível. Arma repetida sobe de nível; com 3 armas, só as próprias; faltando opções, "+15 quarks". Especial = arma de maior nível. Armas disponíveis = naves liberadas na campanha.
- **Diretor** (`RunDirector`): ondas sorteadas por peso entre as ativas no minuto (`RunWaveEntry`: inimigo, formação, tamanho, janela de minutos, horda), intervalo de 2,4 s a 0,6 s, tamanho +8%/min, surto de hordas a cada 60 s. Vida dos inimigos = 0,45 × 1,15^minuto (sobre o cap. 1) e cadência 0,85 → 1,6.
- **Trajetórias** (`MoveStep` em `WaveData.path`, também usáveis na campanha): passos com giro (meia-volta 180, laço 360, curva fechada = muito giro em pouco tempo), velocidade (0 = para), perseguição da nave (`home_degrees`), mira e rajada com aviso (`fire`: a onda inteira atira junto). Espelho por lado (lateral pela direita, metade da pinça, `mirror`). Formação nova `RISE` (fileira subindo da base). 35 padrões com nome em `run_mode.tres` (gancho, laço, V que para e atira, ascensão, diagonal, serpente fechada, curva aberta, grampo, kamikaze persistente, kamikaze em curva aberta, enxame giratório, pinça com tiro, cortina, círculo que fecha, zigue-zague, grade que volta, laço duplo...). Gerados por um script Python de rascunho; editar o `.tres` direto.
- **XP:** tabela `xp_table` (15, 25, 35, 50... até 1500; depois ×1,25 por nível). Ataque frontal 7 tiros/s.
- **Elites** a cada 40 s (Semeador, Escudeiro, Fissor, Pulsar, que flutuam): vida ×14, maiores, com aura e barra de vida; dão XP ×6 e 50% de kit.
- **Chefes** a cada 2,5 min (intermediários e de capítulo alternados, vida pelo minuto), com ondas 3× mais espaçadas na luta; dão orbe grande de XP, 2 kits e, nos de capítulo (a cada 2), um **baú** (`PowerUp.Kind.CHEST`: escolha extra).
- **Kits** a cada 75 s (`dropper.set_interval`). Sobreviver até 30:00 = vitória ("Incursão concluída!").
- **HUD:** a barra fina do topo é o XP, "Nv N" embaixo da pontuação, tempo embaixo do pausar; na câmera lenta, os espaços e a barra de energia aparecem na faixa da base (sem nave). O botão do especial mostra a arma dona dele (a de maior nível). Pausa mostra "Armas 2/3".
- **Menu inicial:** botão "Incursão", travado até concluir o cap. 1. O conteúdo do menu agora começa abaixo da nave decorativa (`menu_title_gap`).
- **Simulador:** `$G --headless --path . --fixed-fps 60 -s res://scripts/tools/simulate_run.gd -- --minutes 30 --pick focus|spread --seed N` (uma linha por minuto: nível, XP/min, abates, hits que levaria, inimigos, tiros, chefe, armas). Leva ~25 min reais para 30 min; rode sementes em paralelo.
- Testes: `tests/run_regressions_run.gd` e `test_run_progress`/`test_run_director` em `run_tests`.
- **Próximas etapas:** (c) eventos e combo, calibrar no aparelho; (d) árvore (ímã de drops, XP) e recompensa nova do modo; (e) guardar o conquistado ao sair, morrer ou o app fechar (sem retomar a partida).

**Chefes arrojados (campanha e Incursão):** `BossData` ganhou entrada (`entry`: DESCEND, WARP = surge do espaço crescendo com anéis convergindo, DROP = despenca e freia com onda de impacto; nome grande na tela ao terminar, `Hud.show_boss_title`), visual por dados (`accent_color`, `plates` girando, `spikes`, `turrets` que miram, olho que segue a nave e fica vermelho na fúria, rachaduras pela vida) e ataques únicos (`signature`, somados às fases a partir de `signature_from_phase`). Padrões novos em `BossAttack`: CHARGE (investida avisada por faixa, anel de tiros no impacto), SWEEP (raio que gira a partir do chefe, conta em `hazard_hits`) e TROOPS (tropas saem do corpo com `troop_path`, via `Game._spawn_troops`). Os 10 chefes têm combinações próprias (tabela no histórico do commit). Teste: `tests/boss_regressions_run.gd` (cada chefe entra e usa os ataques únicos).

**Recordes:** `SaveGame.best_runs` (por fase: tempo, abates, hits levados e kits da partida do recorde; aparece na ficha da fase concluída) e `SaveGame.run_record` (Incursão: maior tempo, empate pela pontuação; nível, abates, armas, vitória; aparece no card do modo e como "Novo recorde!" no resultado). Gravado ao morrer, vencer ou sair da partida. `MatchState.hits_taken` conta os hits que tiraram vida.

**Dicas da Incursão:** `tip_run_start` (ao entrar no modo) e `tip_run_special` (ao ganhar a 2ª arma, destaca a faixa de baixo: `highlight` `run_slots`). As dicas gerais da partida (câmera lenta, especial, kits) também valem no modo.

**Outras mudanças desta rodada:**
- Jogar abre `mode_select.tscn` (cards ilustrados `ModeCard`: Campanha e Incursão, esta travada até o cap. 1). O seletor de fases volta para essa tela.
- Campanha: dificuldade cresce ao longo da fase (`BalanceData.stage_ramp_hp` 0,35 e `stage_ramp_fire` 0,3 no fim; `StageData.difficulty_ramp`).
- Incursão: especial escolhido tocando num espaço na câmera lenta (`RunProgress.choose_special`, anel no escolhido); entradas por lateral e por baixo (cerco, cruzado, rasante, subidas; `RunWaveEntry.both_sides`), entradas por cima em arrancada; vida inicial 0,65 × 1,14^min; kits a cada 120 s, 25% nas elites, 1 por chefe; sem aviso de elite.

**Revisão de progressão (09/11/2026, branch `feat/revisao-progressao`):**
- **Drops por tempo para tudo:** 2 kits e 2 power-ups da auxiliar por fase (antes: 1 kit a cada 30 abates e 1,2% por abate, o que dava ~20 kits e ~7 power-ups por fase com a camada de ação). Excedente (arma no máximo, corpo sem dano) vira 50 pontos, com o número na tela.
- **Quarks:** a 1-1 rendia ~825 (metade da árvore saía no cap. 1). Agora ~250 na 1ª vez (bônus 2×60 + estrelas + 1% da pontuação). Anúncio: 80 + 40 por capítulo. `test_quark_economy` confere a meta (cap. 1 ≤ 15% da árvore; caps. 1 a 4 entre 70% e 105%).
- **Desbloqueios:** Lança no cap. 1, Artilharia e auxiliar no cap. 2, Tesla no 3, Ricochete no 4. O cap. 5 não libera nada; o seletor tem uma página "novos capítulos em breve" depois do último planeta (`StageSelect._build_soon_page`).
- **Esquadrão menor:** cada vaga vazia dá +25% no bônus de conclusão.
- **Vida dos inimigos:** uma escala só, `BalanceData.expected_power_by_chapter` (1,0 a 2,4) × `toughness_by_chapter` (1,4 a 1,8), mais 5% por fase. O `HP_SCALE` do gerador saiu (empilhava). `test_hp_follows_player_power` confere que o poder esperado cabe no que a renda compra em Dano e Cadência.
- **Curva:** `DIFFICULTY_BOOST` [0,5; 0,8; 0,35; 0,2; 0], `DIFFICULTY_PER_STAGE` 0,2, `CYCLE_LEVEL_CAP_BY_STAGE` (ondas crescem menos nas primeiras fases do capítulo), `DANGER_MAX` 17 e no máximo 2 motivos pesados.
- **Estrelas:** 2 = 75% e 3 = 100% da pontuação possível (`STAR2_RATIO`, `STAR3_RATIO`).
- **Dificuldade medida** (`--expected`, média de 3 sementes, hits/min nas fases 1, 4 e 8): cap. 1: 2,6 · 2,9 · 5,2; cap. 2: 3,3 · 3,5 · 5,3; cap. 3: 4,8 · 6,5 · 9,4; cap. 4: 5,5 · 8,7 · 9,1; cap. 5: 7,5 · 9,3 · 12,4 (5-6: 12,6). A 2-1 foi medida antes de subir o `DIFFICULTY_BOOST` do cap. 2 de 0,5 para 0,8, e a 4-8 antes do `DANGER_MAX`. Uma semente só varia muito (a 1-1 deu de 1,2 a 3,0): meça com 3 ou mais.
- **Pool de inimigos cheio** (64) nas fases finais do cap. 5: os inimigos que não cabem não entram. Medir o FPS no aparelho antes de aumentar.
- **Testes:** `pager_regressions` tem 4 falhas que já existiam na `main` (gesto rápido, página acompanha o dedo, cancelar, toque no botão da fase). Os outros testes passam.

**Tutorial (refeito em 09/11/2026):** `Tutorial` (autoload, `scripts/tutorial/tutorial.gd`) lê `data/tutorial/tips.json`. Na partida, cada dica dispara **na primeira vez que o evento acontece**, depois de um atraso (`Params.tip_event_delay_seconds` 1,5 s, ou `delay` na dica; aviso de ataque 0,35 s, itens 1 s), com 4 s sem dicas no início e 10 s entre dicas. Dicas `intro` (abertura: mover e trocar na 1-1, modo na Incursão) aparecem já, em sequência; `gap` por dica encurta o intervalo seguinte (energia e aviso de ataque logo depois) (`Tutorial.notify(evento, fase, alvo)`: `powerup_spawned`, `medkit_spawned`, `xp_orb_spawned`, `chest_spawned`, `enemy_telegraph`, `rock_spawned`, `weakness_hit`, `elite_spawned`, `player_hit`, `touch_released`, `special_ready`, `special_moment`, `match_start`, `run_second_weapon`...). O apresentador `TipSpotlight` pausa o jogo, escurece a tela com um recorte iluminado em volta do alvo (o nó do evento ou o `highlight` fixo da dica: `player`, `energy`, `special`, `switcher`, `run_slots`), anel pulsando, seta e card ("Entendi" / "Não mostrar mais"). Dica mostrada = vista (`SaveGame.tips_seen`); "Rever tutorial" nas Configurações religa. Telas (seletor, esquadrão, evolução) e fim de fase seguem com janelas (`TipDialog`). O balão antigo (`TipBalloon`) saiu. Avisos de desbloqueio (`UnlockNotice`) como antes.

**Animações (05/11/2026, branch `feat/animacoes-nave`):** parâmetros em `Params` (`anim_intensity`, `entry_*`, `exit_*`, `break_*`, `weapon_spawn_*`, `impact_*`, `tilt_*`, `companion_retreat_*`). O corpo nasce do núcleo (entrada) e recolhe nele (troca voluntária); a perda quebra em pedaços (`BodyFx`, pool). A auxiliar recolhe junto do núcleo sem nave principal e volta animada. Armas têm surgimento (`Weapon.play_spawn`, carga, órbita se formando, mísseis nascendo), faíscas de acerto (`HitSpark`, pool), clarão de tiro, rastro da órbita e chama dos mísseis. Pseudo-3D no movimento: `Player.bank/pitch`, sombra deslocada. Tudo em tempo de jogo (acompanha a câmera lenta).

**Vibração (`Haptics`, autoload):** padrões nomeados em `Params.haptic_patterns` (passos `[ms, intensidade]`), usando `Input.vibrate_handheld(ms, amplitude)`. Prioridade, intervalo por padrão, intervalo global e orçamento de motor ligado por segundo (`haptic_budget_*`). Dano ao chefe acumula numa janela de 0,25 s e vira 3 faixas. Configurações: ligar/desligar e intensidade baixa/média/alta (`haptic_level`). Se a amplitude não funcionar no aparelho, `haptic_amplitude_supported = false` simula com pulsos.

**Inimigos (9):** Drone, Mirador, Kamikaze, Tanque, Atirador, Semeador, Caçador, **Pulsar** (anéis finos em espiral) e **Fissor** (parte-se em 3 ao morrer). Ondas em formação: LINE, V, COLUMN, SIDE, DIAGONAL, GRID, PINCER, CIRCLE, com balanço, curva e escala de velocidade por onda (`WaveData`).

**Counters, telegrafia, rochas e momentos de especial (05/11/2026, branch `feat/counters-telegrafia`):**
- **Telegrafia:** todo ataque tem aviso (`EnemyData.telegraph_seconds`, `BossAttack.telegraph_seconds`; desenhos em `scripts/enemies/telegraph.gd`). A mira trava no começo do aviso. `validate_project` e `run_tests` acusam ataque sem aviso.
- **Fraquezas por arma:** `EnemyData.weapon_multipliers` (`WeaponData.Kind` -> multiplicador). O acerto pisca dourado (fraco contra a arma) ou cinza (resistente). Especiais ignoram multiplicadores. `take_damage(amount, source, from)`: `source` = arma ou `Enemy.SOURCE_SPECIAL`; `from` = de onde veio (escudo frontal).
- **Inimigos counter:** Faísca (`spark`, atravessa rápida pela lateral), Enxame (`swarm`, formação `SWARM`), Colosso (`colossus`, regenera sem dano contínuo, orbe lento), Escudeiro (`shielder`, escudo frontal que encara a nave, tem vida e volta), Serpente (`serpent`, fila ondulante). Entram nos capítulos 2, 3 e 4.
- **Matriz inimigo × arma:** `$G --headless --path . --fixed-fps 60 -s res://scripts/tools/counter_matrix.gd -- [--levels 1,3,5] [--weapon beam]`. Mostra % e tempo e um índice relativo (✔ > 1,3, ✖ < 0,7) e avisa se alguma arma ficou sem ✔ ou ✖.
- **Rochas:** `rock_large/medium/small` (`look = ROCK`, `targetable = false`): bloqueiam tiros, machucam ao encostar e se dividem (não ao bater na nave). `StageData.rocks` e `rock_interval_*`. Esparsas a partir da 1-7; a fase 7 de cada capítulo é um campo de meteoros.
- **Padrões de chefe novos:** `BIG_SLOW`, `LASER` (perigo fora dos tiros: `Boss.hazard_hits`), `CURTAIN` (brecha verde), `RAIN` (marcadores), `MINES` (`Bullet.drag` + divisão). Em camadas nas fases dos 10 chefes.
- **Momentos de especial:** `WaveData.special_moment` (clímax da fase 8 de cada capítulo) e `BossPhase.special_moment` (última fase dos chefes de capítulo). Alvos blindados levam 10% do dano normal (`special_moment_armor`) até um especial; ao começar, a carga do especial enche, aparece "USE O ESPECIAL!" e o botão pulsa.
- **Dificuldade (piloto automático, que não troca de nave nem lê avisos):** subiu, sobretudo nos capítulos 3 a 5 (cap. 3 ≈ 3,3 hits/min, cap. 5 ≈ 4,5) e nos chefes (≈ 1,4×). Falta confirmar no aparelho.

**Chefes:**

| Fase | Chefe |
|---|---|
| 1-5 / 2-5 / 3-5 / 4-5 / 5-5 | Vigia / Bigorna / Espectro / Vórtice / Labareda (intermediários) |
| 1-9 | Sentinela |
| 2-9 | Forja |
| 3-9 | Umbra (1200 de vida) |
| 4-9 | Hidra (1800 de vida) |
| 5-9 | Corona (2600 de vida, 4 fases) |

**Campanha:** 5 planetas (Aurora, Vulcânia, Abismo, Singularidade, Eclipse) × 9 fases = 45, ids `p1_s1`…`p5_s9`. Fases comuns com 300 s de ondas, intermediário 210 s, chefe 200 − 25·capítulo s mais a luta. Gerada por `scripts/tools/build_campaign.gd`. Cada fase usa 3 ou 4 padrões de onda (motivos) repetidos em ritmo fixo, com orçamento de perigo crescente. A 1ª fase de cada capítulo está sempre liberada; as outras liberam ao concluir a anterior.

**Save** (`user://save.json`, versão 3): fases concluídas, recordes, esquadrão, auxiliar, quarks, evolução, capítulos concluídos e configurações. Saves 1 e 2 são migrados: o avanço vira fases concluídas e cada chefe antigo vencido conta como capítulo concluído (libera nave e auxiliar). Para liberar tudo, toque 5× no título do seletor (build de debug).

---

## 4. Arquitetura (onde mexer)

| Quero mudar… | Arquivo |
|---|---|
| Qualquer número de tuning, sons e configurações padrão | `scripts/core/params.gd` (autoload `Params`) |
| Ritmo e economia (vida dos inimigos, drops, duração da fase, carga do especial) | `data/balance.tres` (`BalanceData`, em `Params.balance`) |
| Montagem da partida, chefe, revive, especial, kits | `scripts/core/game.gd` |
| Estado da partida (hits, níveis, carga, pontuação) | `scripts/core/match_state.gd` |
| Colisão (círculos) | `scripts/core/combat_system.gd`, `combat_context.gd` |
| Pools | `scripts/core/node_pool.gd`, `pool_item.gd` (o item se desativa no `_ready`) |
| Save / desbloqueio / configurações | `scripts/core/save_game.gd` |
| Evolução do núcleo | `upgrade_data.gd`, `upgrade_tree_data.gd`, `player_boosts.gd`, `data/upgrades/*.tres`, `scripts/ui/upgrade_*.gd` |
| Sons | `scripts/core/audio.gd`, `assets/audio/sfx/` |
| Nave auxiliar | `scripts/player/companion.gd` |
| Barra de troca e toque curto | `body_switcher.gd`, `touch_input.gd` |
| Seletor de fases (mapa do planeta, cabeçalho fixo, estrelas) | `stage_select.gd`, `stage_map.gd`, `stage_node.gd`, `star_row.gd`. Estrelas: `StageData.star_scores` (2 e 3 estrelas, geradas por `campaign_builder` em % da pontuação possível: `STAR2_RATIO`, `STAR3_RATIO`); 1 estrela = concluir. Tocar numa fase concluída abre a ficha |
| Pausa e configurações (ícones, quase sem texto) | `pause_menu.gd`, `settings_panel.gd`, `icon_button.gd` (`IconButton`) |
| Paginação lateral (página acompanha o dedo, snap por distância/velocidade) | `scripts/ui/paged_view.gd` (`PagedView`), params `pager_*`; usada no seletor de fases |
| Fim de fase (pausa, limpeza, nave sai, música `clear.wav`) | `Game._play_clear_sequence`, params `clear_*`, `Player.begin_scripted` |
| Campanha (gerador) | `scripts/tools/campaign_builder.gd` |
| Armas | `scripts/weapons/*` + `data/weapons/*.tres` (`WeaponData` com 5 `WeaponLevel` e 3 da auxiliar). Cada portador (nave e auxiliar) tem um `WeaponMount` que guarda as armas (hoje 1; pronto para várias) |
| Especiais | `special_attack.gd`, `giant_beam.gd`, `shockwave.gd`, `bombardment.gd` |
| Inimigos / ondas / fases | `scripts/enemies/*` + `data/enemies`, `data/stages` |
| Chefes | `boss.gd`, `boss_phase.gd`, `boss_attack.gd` + `data/bosses` |
| Planetas / campanha | `data/planets/*.tres`, `data/campaign.tres` (geradas) |
| Naves e esquadrão | `data/bodies`, `data/formations/{default,roster}.tres` |
| Textos (PT-BR / EN) | `data/i18n/strings.csv`. Campos com vírgula vão entre aspas |
| Diálogos (pausa, revive, resultado, ganhar quarks, configurações na pausa) | `scripts/ui/dialog.gd` (`Dialog`): X de 144 px, Voltar/Esc fecham só o do topo da pilha, corpo com quebra de linha e rolagem. Params `dialog_*` |
| UI | `scripts/ui/*`. Tema em `ui_theme.gd` / `ui_factory.gd` |

**Autoloads:** `Params`, `Session`, `SaveGame`, `SceneTransition`, `AdService`, `Audio`, `Haptics`, `Tutorial`.

**Camadas de CanvasLayer:**

| Camada | Conteúdo |
|---|---|
| 5 | moldura da câmera lenta |
| 8 | faixa de troca |
| 10 | HUD |
| 40 | debug |
| 50 | pausa |
| 60 | resultado/revive |
| 150 | anúncio |
| 200 | transição |

**Tamanho dos pools:**
- inimigos: 64
- tiros inimigos: 500

---

## 5. Armadilhas já conhecidas

- **Export Android:** `editor/export/convert_text_resources_to_binary=false` no `project.godot` **precisa ficar assim**. Com a conversão, os `PackedFloat32Array` dos sub-recursos `WeaponLevel` se perdem no APK, e o Raio deixa de evoluir só no celular.
- **Nomes de enum ou método que colidem** com globais do Godot ou com a classe-pai quebram em silêncio. Já aconteceu com `Side` (virou `EntrySide`) e com `Boss._shoot` (virou `_shoot_bullet`).
- **CSV de tradução:** uma vírgula num texto sem aspas desloca as colunas. Já aconteceu com "Não, obrigado".
- **Inimigos e tiros** são pooled. O chefe não é: ele é instanciado e liberado.
- **Godot 4.7.2 trava (sinal 11)** ao ler uma constante tipada com listas aninhadas (`const X: Array[PackedStringArray]`) dentro de laços. Use função que devolve `Array` simples (aconteceu na migração do save).
- **Scripts `-s` e autoloads:** os nomes de autoload não existem ao compilar um script rodado com `-s`. Carregue o código real no primeiro quadro (`simulate_stages.gd`, `run_tests.gd`).
- **`pkill -f`** com o nome do script mata o próprio shell que o contém.
- **Intervalo mínimo de som:** tiros e acertos disparam muitas vezes por segundo; novos sons de alta frequência precisam entrar em `sfx_min_gap`.
- **Campanha gerada:** editar `data/stages/*.tres` à mão se perde ao rodar o gerador de novo.
- **Arquivos `.uid`:** versione-os junto com os scripts.
- **O chefe é liberado da memória ao morrer** (não é pooled). Qualquer lista ou dicionário que guarde inimigos precisa checar `is_instance_valid` e não usar laço tipado (`for e: Enemy in ...`), senão dá "previously freed instance" a cada quadro (aconteceu na Órbita).
- **Floats de 32 bits:** `PackedFloat32Array` guarda menos precisão que um `float` do GDScript (64 bits). Comparar um valor guardado nela com um calculado (`>=`) pode falhar por 0,0000001; foi o que travava o especial de algumas naves. Compare com folga (`special_ready_epsilon`).
- **Erros no celular:** `adb logcat -d -s godot:*` mostra os SCRIPT ERROR da última partida.

---

## 6. Pendências e ideias

**A testar no S24:** a build da branch `feat/revisao-progressao` (ver "Revisão de progressão" na seção 3).

**Observações de balanceamento (piloto automático, sem troca de nave):**
- Mísseis sofre muito no capítulo 5 (muito mais hits que Raio e Leque). Vale revisar se o teste no aparelho confirmar.
- A fase 8 de cada capítulo é a mais pesada (clímax).
- O piloto automático não lê avisos nem usa a câmera lenta: os hits/min servem para comparar fases, não como dificuldade absoluta.
- Saves antigos: quem já tinha concluído o cap. 1 perde o acesso à auxiliar até concluir o cap. 2 (a escolha fica guardada e volta sozinha).

**Ofertas feitas e ainda não confirmadas pelo Gabriel:**
- trocar a tela de boot (splash) do Godot
- medir o FPS no aparelho com carga máxima

**Diálogos (05/11/2026):** todos usam `Dialog`. Telas que tratam o Voltar (menu, seletor, esquadrão, evolução, configurações) ignoram o Voltar enquanto `Dialog.is_open()`. A janela de ganhar quarks não fecha durante o anúncio (senão a recompensa se perde). Revive: X e Voltar recusam. Resultado: sem X; o Voltar vai ao seletor de fases. O `ui_smoke` confere os diálogos em 20:9, 19,5:9 e 16:9.

**Ainda não feito:**
- músicas definitivas (as atuais são sintetizadas)
- bomba global do GDD (não implementada; `bomb_global.wav` guardado): decidir se fica ou sai
- especial global carregável por tempo: engavetado pelo Gabriel (05/11/2026)
- anúncio real (SDK)
- arte final (hoje tudo são placeholders desenhados por código)
- pacote definitivo (`com.example` ainda)
- keystore de release
- publicação

**Itens [EM ABERTO] do GDD:**
- calibrar a energia da câmera lenta no aparelho
- núcleo rachando como mecânica
- itens de escudo/moedas (parte coberta pelos quarks e pelo Escudo da evolução)

**Documentos relacionados:**
- `docs/PUBLICACAO.md`: plano de anúncios reais (AdMob) e de publicação na Play Store (deixado para depois)
- `docs/GDD_Nucleon_Squad_v1.md`: design
- `docs/MARCO0_TESTE.md`, `docs/MARCO1_TESTE.md` e `docs/MARCO2_TESTE.md`: roteiros de teste
- `docs/REFERENCIAS_ESQUADRAO.md`: pesquisa de referências
