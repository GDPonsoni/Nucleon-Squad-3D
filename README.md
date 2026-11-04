# Nucleon Squad

> Nome provisório.

![Godot](https://img.shields.io/badge/Godot-4.7-478CBF?logo=godotengine&logoColor=white)
![GDScript](https://img.shields.io/badge/linguagem-GDScript-355570)
![Android](https://img.shields.io/badge/plataforma-Android-3DDC84?logo=android&logoColor=white)
![Status](https://img.shields.io/badge/status-conte%C3%BAdo%20completo%20%C2%B7%20em%20polimento-brightgreen)

Shoot 'em up vertical (bullet hell) para celular, em 2D, feito em **Godot 4** com **GDScript**. Você comanda um **esquadrão de naves com armas diferentes** em torno de um núcleo: troca de nave no meio da luta, leva uma nave auxiliar e evolui o núcleo com os quarks ganhos nas fases. São **5 capítulos de 9 fases**, com chefes, ondas em padrões reconhecíveis e 8 naves para liberar.

O design completo está em [`docs/GDD_Nucleon_Squad_v1.md`](docs/GDD_Nucleon_Squad_v1.md).

---

## Sumário

- [Status e roadmap](#status-e-roadmap)
- [Requisitos](#requisitos)
- [Primeiros passos](#primeiros-passos)
- [Rodar no PC](#rodar-no-pc)
- [Exportar para Android](#exportar-para-android)
- [Ajustar parâmetros](#ajustar-parâmetros)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Contribuindo](#contribuindo)

---

## Status e roadmap

**Fase atual: conteúdo completo e jogável, em ajuste fino de dificuldade e polimento.** A campanha inteira roda no Galaxy S24; faltam arte final, áudio definitivo, anúncios reais e a publicação.

| Marco | Objetivo | Status |
|---|---|---|
| **0** | Protótipo: nave com controle relativo e câmera lenta no S24 | ✅ |
| **1** | Jogável mínimo: corpos, troca de corpo, inimigos, fases, 3 hits | ✅ |
| **2** | Núcleo completo: 4 corpos, armas com 5 níveis, especiais, chefes, salvamento local | ✅ |
| **3** | Conteúdo, áudio e anúncio de revive | 🟡 conteúdo e áudio prontos; anúncios ainda simulados |
| **4** | Polimento e publicação | ⚪ arte final, pacote definitivo, keystore de release, loja |

### O que já existe

| Área | Resumo |
|---|---|
| **Campanha** | 5 planetas × 9 fases (45), com chefe intermediário na fase 5 e chefe de capítulo na 9. Ondas em padrões reconhecíveis, gerada por script e balanceada com um piloto automático |
| **Esquadrão** | 8 naves com armas e especiais próprios, 5 níveis de arma por power-up, esquadrão de 4 montado numa tela própria, nave auxiliar opcional e troca de nave por toque curto numa barra fixa |
| **Inimigos e chefes** | 9 tipos de inimigo e 10 chefes (5 intermediários e 5 de capítulo, o último com 4 fases) |
| **Progressão** | quarks ganhos nas fases, árvore de evolução do núcleo (12 nós, sem limite de níveis), naves liberadas ao concluir capítulos, recordes e progresso salvos no aparelho |
| **Áudio** | 28 efeitos e uma música por capítulo, mais a do menu (geradas por síntese, sem samples), com volume geral, de música e de efeitos |
| **Interface** | menus com relevo e animações, botão Voltar no canto, configurações (vibração, efeitos reduzidos, estatísticas) e idiomas **PT-BR, EN e ES** |
| **Anúncios** | simulados (`AdService`): revive, quarks por anúncio e banner reservado no menu, prontos para trocar pelo SDK |
| **Visual** | placeholders desenhados por código, sem arte final |

### Próximos passos

- Teste de dificuldade e de desempenho (FPS com carga máxima) no S24
- Anúncios reais (AdMob) no lugar do simulador
- Arte final e músicas definitivas
- Pacote definitivo (hoje `com.example`), keystore de release e publicação

## Requisitos

| Ferramenta | Versão | Para quê |
|---|---|---|
| [Godot Engine](https://godotengine.org/download) | **4.7.x** (versão padrão, não a .NET) | editor e execução |
| Export templates do Godot | mesma versão do editor | exportar para Android |
| [Android SDK](https://developer.android.com/studio#command-tools) (command-line tools) | platform-tools, build-tools, platform 35 | build e `adb` |
| OpenJDK | **17** | assinatura e build do APK |

> O projeto usa o renderizador **Mobile**. Abra sempre com a mesma versão do Godot para evitar conversões de arquivos.

---

## Primeiros passos

```bash
git clone https://github.com/GDPonsoni/nucleon-squad.git
cd nucleon-squad
```

1. Baixe o Godot 4.7 em <https://godotengine.org/download> e extraia o executável.
2. Abra o Godot, clique em **Importar** e selecione o `project.godot` desta pasta.
   Ou pelo terminal: `godot --path . -e`
3. Na primeira abertura, o Godot cria a pasta `.godot/` (cache de importação). Ela não é versionada.

> **Linux:** se o executável não estiver no `PATH`, use o caminho completo, por exemplo `~/Godot/Godot_v4.7.2-stable_linux.x86_64`.

---

## Rodar no PC

- **No editor:** `F5` (ou o botão ▶ no canto superior direito).
- **Pelo terminal:** `godot --path .`

A janela abre em 540×960 (metade da resolução 1080×1920). O **mouse emula toque**: segurar o botão esquerdo equivale a ter o dedo na tela, e soltar ativa a câmera lenta.

**Validar scripts sem abrir janela** (útil antes de cada commit):

```bash
godot --headless --path . --quit
```

---

## Exportar para Android

### Configuração única

1. **Export templates:** no editor, `Editor → Gerenciar Modelos de Exportação → Baixar e Instalar`.
2. **Android SDK e JDK:** em `Editor → Configurações do Editor → Exportar → Android`, preencha:
   - `Java SDK Path`: por exemplo `/usr/lib/jvm/java-17-openjdk-amd64`
   - `Android SDK Path`: por exemplo `~/Android/Sdk`
3. **Keystore de debug:** o Godot gera um automaticamente na primeira exportação. Se não gerar:
   ```bash
   keytool -genkeypair -v -keystore debug.keystore -storepass android \
     -alias androiddebugkey -keypass android -keyalg RSA -validity 10000 \
     -dname "CN=Android Debug,O=Android,C=US"
   ```
   e aponte `Debug Keystore` para ele nas mesmas configurações.
4. **Celular:** ative as *Opções do desenvolvedor* e a *Depuração USB*, conecte por cabo e confirme com `adb devices`.

### Instalar no celular

**Pelo editor (mais simples):** com o celular conectado, clique no ícone do Android no canto superior direito (*Remote Debug / One-click deploy*).

**Pelo terminal:**

```bash
# exporta o APK de debug (o preset "Android" já está em export_presets.cfg)
godot --headless --path . --export-debug "Android" builds/nucleon-squad.apk

# instala e abre
adb install -r builds/nucleon-squad.apk
adb shell monkey -p com.example.nucleonsquad 1
```

O overlay de FPS só aparece em builds de **debug**. Roteiros de teste: [`docs/MARCO0_TESTE.md`](docs/MARCO0_TESTE.md), [`docs/MARCO1_TESTE.md`](docs/MARCO1_TESTE.md) e [`docs/MARCO2_TESTE.md`](docs/MARCO2_TESTE.md). Referências de design: [`docs/REFERENCIAS_ESQUADRAO.md`](docs/REFERENCIAS_ESQUADRAO.md).

### Ícone do app

O ícone é desenhado em SVG (`icon.svg` e `assets/icon/*.svg`). Depois de editar um SVG, gere os PNGs usados pelo Android (legado 192, adaptativo e monocromático) com:

```bash
godot --headless --path . -s res://scripts/tools/render_icons.gd
```

Os caminhos já estão no preset Android (`launcher_icons/*` em `export_presets.cfg`).

> Nunca versione keystores de release nem senhas. O Godot guarda credenciais em `.godot/export_credentials.cfg`, que já é ignorado.

---

## Ajustar parâmetros

Todos os valores de tuning ficam em um único arquivo, [`scripts/core/params.gd`](scripts/core/params.gd) (autoload `Params`):

| Parâmetro | Padrão | Efeito |
|---|---|---|
| `slow_time_scale` | 0.3 | velocidade do jogo com o dedo solto |
| `time_scale_smooth_seconds` | 0.1 | duração da transição da câmera lenta (tempo real) |
| `ship_speed` | 3000 | velocidade máxima da nave (px/s) |
| `drag_sensitivity` | 1.0 | quanto a nave anda por pixel de dedo |
| `nucleus_radius` | 16 | raio do núcleo, que também é a hitbox da nave |
| `body_max_hits` | 3 | hits que cada corpo aguenta |
| `switch_invulnerability_seconds` | 2.0 | invulnerabilidade ao trocar de corpo |
| `hit_invulnerability_seconds` | 1.0 | invulnerabilidade após levar hit |
| `star_layer_speeds` | 40 / 120 / 320 | velocidade de cada camada do fundo (px/s) |
| `powerup_every_kills` | 8 | inimigos destruídos por power-up |
| `debug_unlock_all` | false | libera todas as fases (testes) |

**Dados (`data/`)** definem o conteúdo, editáveis no Inspector do Godot ou em texto:

| Pasta | Conteúdo |
|---|---|
| `data/weapons/` | armas: tipo, cor e os 5 níveis (dano, cadência, leque, feixes, ondas de mísseis, orbitais) |
| `data/bodies/` | corpos: formato (pontos), cor e arma |
| `data/formations/` | esquadrão inicial (`default.tres`) e naves disponíveis (`roster.tres`) |
| `data/enemies/` | inimigos: vida, pontos, movimento (descer, cruzar, mergulhar, parar) e tiro (reto, mirado, anel, leque) |
| `data/stages/` | fases: duração, inimigos, pesos, intervalo entre surgimentos, ondas em formação e chefe |
| `data/bosses/` | chefes: vida e fases (movimento: balanço, oito, perseguir; ataques: leque, anel/espiral, convocar ondas, tiros que se dividem ou perseguem) |
| `data/planets/`, `data/campaign.tres` | planetas (nome, cores, fases) e ordem da campanha |

---

## Estrutura do projeto

```
docs/            GDD e roteiros de teste
scenes/          cenas (.tscn) pequenas: menu (inicial), stage_select, squad (esquadrão) e game (partida)
scripts/
  core/          params, sessão, save, partida, estado, colisão, câmera lenta, pools, fundo
  player/        nave (núcleo + corpo), toque, troca de corpo, BodyData
  weapons/       armas (raio, projéteis, órbita), projéteis, WeaponData
  enemies/       inimigos, surgimento, EnemyData e StageData
  ui/            tema, menus, seletor, pausa, resultados, HUD, transições, debug
data/            campanha, planetas, fases, inimigos, armas, corpos e formações (.tres)
  i18n/          tabela de tradução strings.csv (chave, en, pt_BR)
assets/          ícone, efeitos sonoros (audio/sfx) e músicas (audio/music)
builds/          APKs exportados (não versionado)
```

**Autoloads:** `Params` (tuning), `Session` (fase escolhida), `SaveGame` (progresso e configurações em `user://save.json`), `SceneTransition` (fade entre telas), `AdService` (anúncios, simulados por enquanto) e `Audio` (efeitos, músicas e volumes).

**Ferramentas** (em `scripts/tools/`): gerador da campanha, simulador de fases com piloto automático, gerador de músicas e validador do projeto. Os comandos estão no guia abaixo.

**Estado atual, pendências e guia de retomada:** [`docs/ESTADO_ATUAL.md`](docs/ESTADO_ATUAL.md).

**Princípios:** GDScript tipado, parâmetros centralizados em `Params`, dados fora do código, pooling desde o início e suporte a N corpos. Detalhes em [`CLAUDE.md`](CLAUDE.md).

---

## Contribuindo

Os commits seguem o padrão **[Conventional Commits](https://www.conventionalcommits.org/pt-br/v1.0.0/)**. Veja tipos, escopos e o fluxo de trabalho em [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Licença

© 2026 Gabriel ([@GDPonsoni](https://github.com/GDPonsoni)). Todos os direitos reservados. O código está visível para consulta, mas não há licença de uso, cópia ou redistribuição.
