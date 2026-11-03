# Estado atual e guia de retomada

Documento para retomar o projeto em uma conversa nova (Claude Code ou outra pessoa). Atualizado em **02/11/2026**, com a `main` em `079139e`.

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

**Testes de simulação:** o balanceamento foi medido com scripts headless temporários (`extends SceneTree`, rodados com `$G --headless --path . --fixed-fps 60 -s <script>.gd`). Eles montam a cena `game.tscn`, forçam nível de arma e medem DPS, abates, duração de chefe e carga nos pools. Não ficaram no repo; recrie quando precisar medir.

---

## 2. Fluxo de trabalho combinado com o Gabriel

- Conversa em **português**. Commits em **Conventional Commits** em português (ver `CONTRIBUTING.md`), um por mecânica.
- **Branch por tarefa** (`feat/...`, `fix/...`, `docs/...`). Quando o Gabriel diz "pode mesclar na main", fazer `git merge --ff-only`, `git push origin main` e apagar a branch.
- Ao terminar uma tarefa: **validar no Godot headless**, exportar e **instalar no S24** quando o celular estiver conectado, e dizer em 2–4 linhas o que testar.
- **Builds temporárias de teste** (por exemplo, com `debug_start_weapon_level` alterado) devem ser **substituídas pela build normal** logo depois. Uma build de nível 5 esquecida no celular já causou um falso relato de "power-up não muda nada".
- Ao perguntar algo ao Gabriel, oferecer opções objetivas.

---

## 3. O que existe (resumo do jogo)

**Fluxo de telas:** `menu.tscn` (Jogar / Esquadrão / Sair) → `stage_select.tscn` (capítulos com rolagem, desbloqueio e recordes) → `game.tscn`. `squad.tscn` monta o esquadrão. Caminhos em `scripts/core/scene_paths.gd`.

**Partida:**
- Controle relativo por toque/mouse. Soltar o dedo ativa a câmera lenta (0,3), com moldura própria (`SlowMotionOverlay`).
- Na câmera lenta aparece a **faixa fixa de troca** embaixo. Corpos mortos aparecem apagados com um X, e o anel dourado mostra o nível da arma.
- Esquadrão de 4 corpos (`Params.squad_size`), 3 hits cada. O núcleo é a hitbox.
- **6 naves:**

  | Nave | Arma | Especial |
  |---|---|---|
  | Raio | BEAM | raio gigante + anel que limpa tiros |
  | Leque | SPREAD | rajada de 360° + anel que limpa tiros |
  | Mísseis | HOMING | chuva de mísseis em todos os inimigos |
  | Órbita | ORBIT (apaga tiros) | anel de energia que causa dano e limpa tiros |
  | Lança | PIERCE (atravessa) | leque de lanças gigantes |
  | Artilharia | BLAST (área) | bombardeio pela tela |

  Os especiais ficam em `scripts/weapons/special_attack.gd`, e os valores, no grupo "Especial" do `WeaponData`.
- Cada arma tem **5 níveis**, que sobem com os power-ups dropados por abates. Os **kits médicos** são mais raros e devolvem 1 hit.
- **Especial:** carrega com o tempo e é ativado pelo botão no canto inferior esquerdo.
- **Revive por anúncio simulado:** oferta de 20 s no game over, uma vez por partida. O último corpo volta com vida cheia. O `AdService` é um stub, ainda sem SDK de anúncios.
- Pausa com Continuar / Reiniciar / Voltar ao menu. Tela de resultado com pontuação, abates e recorde.

**Inimigos:**
- **7 tipos:** Drone, Mirador, Kamikaze, Tanque, Atirador, Semeador (tiros que se dividem) e Caçador (tiros perseguidores por tempo limitado).
- **Movimentos:** descer, cruzar, mergulhar, parar.
- **Tiros:** reto, mirado, anel, leque.
- **Ondas em formação** (`WaveData`).

**Chefes:**

| Chefe | Planeta |
|---|---|
| Sentinela | Aurora |
| Forja | Vulcânia |
| Umbra | Abismo |
| Hidra | Singularidade |

- Cada chefe tem fases por % de vida, com movimentos SWAY / FIGURE8 / CHASE.
- **Ataques:** FAN, RING, SUMMON e tiros que se dividem ou perseguem.

**Campanha:**
- 4 planetas e 13 fases (`p1_s1`…`p4_s4`, de até 5 min). O chefe aparece na última fase de cada planeta.
- A 1ª fase de cada capítulo está sempre liberada. As outras liberam ao completar a anterior do mesmo capítulo.
- **Save:** `user://save.json` versão 2, com fases completas, recordes, esquadrão e "liberar tudo". Para liberar tudo, toque 5× no título do seletor (build de debug) ou ligue `Params.debug_unlock_all`.

---

## 4. Arquitetura (onde mexer)

| Quero mudar… | Arquivo |
|---|---|
| Qualquer número de tuning | `scripts/core/params.gd` (autoload `Params`) |
| Montagem da partida, chefe, revive, especial, kits | `scripts/core/game.gd` |
| Estado da partida (hits, níveis, carga, pontuação) | `scripts/core/match_state.gd` |
| Colisão (círculos) | `scripts/core/combat_system.gd`, `combat_context.gd` |
| Pools | `scripts/core/node_pool.gd`, `pool_item.gd` (o item se desativa no `_ready`) |
| Save / desbloqueio | `scripts/core/save_game.gd` |
| Armas | `scripts/weapons/*` + `data/weapons/*.tres` (`WeaponData` com 5 `WeaponLevel`) |
| Especiais | `special_attack.gd`, `giant_beam.gd`, `shockwave.gd`, `bombardment.gd` |
| Inimigos / ondas / fases | `scripts/enemies/*` + `data/enemies`, `data/stages` |
| Chefes | `boss.gd`, `boss_phase.gd`, `boss_attack.gd` + `data/bosses` |
| Planetas / campanha | `data/planets/*.tres`, `data/campaign.tres` |
| Naves e esquadrão | `data/bodies`, `data/formations/{default,roster}.tres` |
| Textos (PT-BR / EN) | `data/i18n/strings.csv`. Campos com vírgula vão entre aspas |
| UI | `scripts/ui/*`. Tema em `ui_theme.gd` / `ui_factory.gd` |

**Autoloads:** `Params`, `Session`, `SaveGame`, `SceneTransition`, `AdService`.

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
- **Arquivos `.uid`:** versione-os junto com os scripts.

---

## 6. Pendências e ideias

**A testar no S24 (última build instalada = `main` atual):**
- capítulo 4 e a Hidra
- tiros que se dividem e perseguidores
- Lança e Artilharia
- faixa de troca
- FPS com muitos tiros na tela (overlay de debug)

**Ofertas feitas e ainda não confirmadas pelo Gabriel:**
- trocar a tela de boot (splash) do Godot
- encurtar a luta da Hidra: ~95 s com Raio nv. 5 e ~165 s com Leque nv. 3
- medir o FPS no aparelho com carga máxima

**Ainda não feito (marcos 2–4 do GDD):**
- bomba global
- áudio
- anúncio real (SDK)
- arte final (hoje tudo são placeholders desenhados por código)
- pacote definitivo (`com.example` ainda)
- keystore de release
- publicação

**Itens [EM ABERTO] do GDD:**
- limite da câmera lenta
- núcleo rachando como mecânica
- itens de escudo/moedas

**Documentos relacionados:**
- `docs/GDD_Nucleon_Squad_v1.md`: design
- `docs/MARCO0_TESTE.md` e `docs/MARCO1_TESTE.md`: roteiros de teste
- `docs/REFERENCIAS_ESQUADRAO.md`: pesquisa de referências
