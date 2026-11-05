# Estado atual e guia de retomada

Documento para retomar o projeto em uma conversa nova (Claude Code ou outra pessoa). Atualizado em **04/11/2026**, com a `main` publicada no GitHub.

> **Para o Claude Code:** leia este arquivo, o `CLAUDE.md` e o GDD antes de começar. Depois de cada entrega relevante, atualize as seções "O que existe" e "Pendências" daqui.

---

## 1. Ambiente nesta máquina

| Item | Onde |
|---|---|
| Projeto (repo git) | `~/Documentos/outros/Nucleon Squad/nucleon-squad` |
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
# Joga fases com piloto automático e mede dificuldade (hits que levaria, duração de chefe)
$G --headless --path . --fixed-fps 60 -s res://scripts/tools/simulate_stages.gd -- --chapter 5 --level 1 --seed 1
# Regera as 45 fases (sobrescreve data/stages, planets e campaign.tres)
$G --headless --path . -s res://scripts/tools/build_campaign.gd
```

O simulador aceita `--stages`, `--chapter`, `--squad a,b,c,d`, `--companion id`, `--upgrades dano=3,...`, `--mode survival` e `--boss-only`. Depois de criar scripts ou recursos novos, rode `--import` uma vez para gerar os `.uid`. Scripts de ferramenta que usam os autoloads precisam de um arquivo `-s` mínimo que só carrega o resto no primeiro quadro (veja `simulate_stages.gd`).

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

**Fluxo de telas:** `menu.tscn` (Jogar / Esquadrão / Núcleo / Configurações; sair pelo Voltar do Android) → `stage_select.tscn` (um capítulo por página, com setas) → `game.tscn`. Também `squad.tscn`, `upgrades.tscn` e `settings.tscn`. Caminhos em `scripts/core/scene_paths.gd`.

**Partida:**
- Controle relativo por toque/mouse. Soltar o dedo ativa a câmera lenta (0,3) com moldura azul.
- **Barra de troca de nave** fixa na base, translúcida enquanto o dedo move a nave e nítida na câmera lenta. A troca é um **toque curto** num corpo; se o dedo andar ou demorar mais que 0,35 s, vira arraste normal (evita trocas sem querer). A nave não desce além da barra. Hits e nível de cada corpo aparecem na própria barra. **Recarga entre trocas** voluntárias (`switch_cooldown_seconds`, 4 s) com setor escuro nos ícones; invulnerabilidade da troca de 1,0 s. As duas contam em tempo de jogo (escalam com a câmera lenta).
- Esquadrão de 4 corpos (`Params.squad_size`), 3 hits cada (mais com o Casco da evolução). O núcleo é a hitbox.
- **Nave auxiliar** (opcional, espaço liberado ao concluir o capítulo 1): versão pequena de uma nave que acompanha a principal ao lado, não leva dano e atira uma versão fraca da arma (`WeaponData.companion_levels`, 3 níveis). Cada arma tem um papel como auxiliar: Raio foco, Leque flancos, Mísseis caça-grandões, Órbita escudo em volta da nave principal, Lança perfuração, Artilharia área, Tesla defesa próxima (360°), Ricochete enxame. Power-up raro lilás (`companion_powerup_chance`) sobe o nível dela na partida, com aviso na tela.
- **Tela de esquadrão:** 4 vagas + vaga da auxiliar no topo e grade de naves (ícone, nome e ⓘ). Tocar põe na 1ª vaga livre; com o esquadrão cheio, vira a auxiliar; tocar de novo (ou na vaga) tira. A nave voa animada entre grade e vaga. O ⓘ abre a inspeção (`ShipInspect`): nave grande, demo ao vivo da arma (`WeaponDemo`, alvos `TrainingTarget`) na versão principal (níveis 1–5) ou auxiliar (1–3), descrição curta e botões de esquadrão/auxiliar.
- **8 naves:**

  | Nave | Arma | Especial | Liberada |
  |---|---|---|---|
  | Raio | BEAM | raio gigante + anel que limpa tiros | início |
  | Leque | SPREAD | rajada 360° + anel | início |
  | Mísseis | HOMING | chuva de mísseis em todos | início |
  | Órbita | ORBIT | anel de energia | início |
  | Lança | PIERCE | leque de lanças gigantes | cap. 2 |
  | Artilharia | BLAST | bombardeio | cap. 3 |
  | Tesla | CHAIN | tempestade de raios em todos | cap. 4 |
  | Ricochete | BOUNCE | 16 orbes que ricocheteiam | cap. 5 |

  "Liberada" = concluir o capítulo (fase 9). Está em `BodyData.unlock_chapter`.
- 5 níveis de arma por power-up, kits médicos, especial que carrega com o tempo (`special_charge_multiplier`, hoje 1,5), revive por anúncio simulado (`AdService`).
- **Quarks:** 10% da pontuação de cada inimigo/chefe, mais bônus ao concluir a fase (dobrado na 1ª vez). Guardados ao fim da partida, mesmo ao perder ou sair.
- **Evolução do núcleo** (`upgrades.tscn`, `data/upgrade_tree.tres`, `data/upgrades/*.tres`): 12 nós em 3 ramos (Ataque, Defesa, Suporte) + **Sobrecarga**, sem limite de níveis (custo linear). Bônus calculados em `UpgradeTreeData.boosts_for` → `PlayerBoosts` (no `CombatContext` e no `MatchState`).
- **Áudio** (`Audio`, autoload): 28 efeitos em `assets/audio/sfx`, com ganho por som em `Params.sfx_gain_db` e intervalo mínimo em `Params.sfx_min_gap`. **Músicas** em `assets/audio/music` (menu e um tema por capítulo, em laço, com troca suave), geradas por `python3 scripts/tools/gen_music.py` (Python puro). Barramentos SFX e Música.
- **Anúncios (simulados, `AdService`):** janela "Ganhar quarks" (`AdOfferPopup`) ao tocar no saldo (menu inicial e Núcleo) ou ao tentar comprar sem saldo (5 por dia, 120 + 60 por capítulo concluído). Banner reservado no rodapé do menu inicial com 90 dp de altura (cabe o padrão de 50 dp e o adaptativo do AdMob), em `make_banner_placeholder`, a trocar pelo SDK.
- **Configurações** (menu e pausa): volume geral/música/efeitos, vibração, efeitos visuais reduzidos, estatísticas na tela (FPS e contadores, para esconder ao mostrar a demo), idioma (lista: automático, português, inglês, espanhol). Salvas em `SaveGame.settings`.

**Inimigos (9):** Drone, Mirador, Kamikaze, Tanque, Atirador, Semeador, Caçador, **Pulsar** (anéis finos em espiral) e **Fissor** (parte-se em 3 ao morrer). Ondas em formação: LINE, V, COLUMN, SIDE, DIAGONAL, GRID, PINCER, CIRCLE, com balanço, curva e escala de velocidade por onda (`WaveData`).

**Chefes:**

| Fase | Chefe |
|---|---|
| 1-5 / 2-5 / 3-5 / 4-5 / 5-5 | Vigia / Bigorna / Espectro / Vórtice / Labareda (intermediários) |
| 1-9 | Sentinela |
| 2-9 | Forja |
| 3-9 | Umbra (1200 de vida) |
| 4-9 | Hidra (1800 de vida) |
| 5-9 | Corona (2600 de vida, 4 fases) |

**Campanha:** 5 planetas (Aurora, Vulcânia, Abismo, Singularidade, Eclipse) × 9 fases = 45, ids `p1_s1`…`p5_s9`, de 1:15 a 3:15. Gerada por `scripts/tools/build_campaign.gd`. Cada fase usa 3 ou 4 padrões de onda (motivos) repetidos em ritmo fixo, com orçamento de perigo crescente. A 1ª fase de cada capítulo está sempre liberada; as outras liberam ao concluir a anterior.

**Save** (`user://save.json`, versão 3): fases concluídas, recordes, esquadrão, auxiliar, quarks, evolução, capítulos concluídos e configurações. Saves 1 e 2 são migrados: o avanço vira fases concluídas e cada chefe antigo vencido conta como capítulo concluído (libera nave e auxiliar). Para liberar tudo, toque 5× no título do seletor (build de debug).

---

## 4. Arquitetura (onde mexer)

| Quero mudar… | Arquivo |
|---|---|
| Qualquer número de tuning, sons e configurações padrão | `scripts/core/params.gd` (autoload `Params`) |
| Montagem da partida, chefe, revive, especial, kits | `scripts/core/game.gd` |
| Estado da partida (hits, níveis, carga, pontuação) | `scripts/core/match_state.gd` |
| Colisão (círculos) | `scripts/core/combat_system.gd`, `combat_context.gd` |
| Pools | `scripts/core/node_pool.gd`, `pool_item.gd` (o item se desativa no `_ready`) |
| Save / desbloqueio / configurações | `scripts/core/save_game.gd` |
| Evolução do núcleo | `upgrade_data.gd`, `upgrade_tree_data.gd`, `player_boosts.gd`, `data/upgrades/*.tres`, `scripts/ui/upgrade_*.gd` |
| Sons | `scripts/core/audio.gd`, `assets/audio/sfx/` |
| Nave auxiliar | `scripts/player/companion.gd` |
| Barra de troca e toque curto | `body_switcher.gd`, `touch_input.gd` |
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

**Autoloads:** `Params`, `Session`, `SaveGame`, `SceneTransition`, `AdService`, `Audio`.

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

---

## 6. Pendências e ideias

**A testar no S24 (última build instalada = branch `feat/capitulo-5-e-progressao`):** veja `docs/MARCO2_TESTE.md`.

**Balanceamento (04/11/2026):** a dificuldade dos capítulos 1 a 3 subiu (`DIFFICULTY_BOOST` em `campaign_builder.gd`, mais vida dos chefes dos capítulos 1 a 3). Piloto automático, média de 3 sementes, hits/min: cap. 1 ≈ 1,3; cap. 2 ≈ 2,0; cap. 3 ≈ 2,2; cap. 4 ≈ 2,0; cap. 5 ≈ 3,1. Falta confirmar no aparelho. Músicas de batalha refeitas (mais rápidas) e `music_volume_db` em -14. O botão Voltar fica no canto superior esquerdo (`UiFactory.add_corner_back`, agora uma seta desenhada por código). O `ui_smoke` confere textos apertados ou cortados em botões e rótulos (PT, EN e ES); `UiFactory.fit_button_text` reduz a fonte de botões com texto dinâmico longo.

**Observações de balanceamento (piloto automático, sem troca de nave):**
- Mísseis sofre muito no capítulo 5 (muito mais hits que Raio e Leque). Vale revisar se o teste no aparelho confirmar.
- 4-8, 3-8 e 5-8 são as fases mais pesadas de cada capítulo.
- Os quarks começam em 0 mesmo para quem já jogou (sem retroativo).

**Ofertas feitas e ainda não confirmadas pelo Gabriel:**
- trocar a tela de boot (splash) do Godot
- medir o FPS no aparelho com carga máxima
- mesclar a branch na `main` e dar `push` (depende do "pode mesclar na main")

**Diálogos (05/11/2026):** todos usam `Dialog`. Telas que tratam o Voltar (menu, seletor, esquadrão, evolução, configurações) ignoram o Voltar enquanto `Dialog.is_open()`. A janela de ganhar quarks não fecha durante o anúncio (senão a recompensa se perde). Revive: X e Voltar recusam. Resultado: sem X; o Voltar vai ao seletor de fases. O `ui_smoke` confere os diálogos em 20:9, 19,5:9 e 16:9.

**Ainda não feito:**
- músicas definitivas (as atuais são sintetizadas)
- `bomb_global.wav` não usado (a bomba global do GDD ainda não existe)
- especial global carregável por tempo: engavetado pelo Gabriel (05/11/2026)
- meteoros e obstáculos: o Gabriel vai pedir num próximo prompt
- anúncio real (SDK)
- arte final (hoje tudo são placeholders desenhados por código)
- pacote definitivo (`com.example` ainda)
- keystore de release
- publicação

**Itens [EM ABERTO] do GDD:**
- limite da câmera lenta
- núcleo rachando como mecânica
- itens de escudo/moedas (parte coberta pelos quarks e pelo Escudo da evolução)

**Documentos relacionados:**
- `docs/PUBLICACAO.md`: plano de anúncios reais (AdMob) e de publicação na Play Store (deixado para depois)
- `docs/GDD_Nucleon_Squad_v1.md`: design
- `docs/MARCO0_TESTE.md`, `docs/MARCO1_TESTE.md` e `docs/MARCO2_TESTE.md`: roteiros de teste
- `docs/REFERENCIAS_ESQUADRAO.md`: pesquisa de referências
