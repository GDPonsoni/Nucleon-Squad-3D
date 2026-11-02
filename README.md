# Nucleon Squad

> Nome provisório.

![Godot](https://img.shields.io/badge/Godot-4.7-478CBF?logo=godotengine&logoColor=white)
![GDScript](https://img.shields.io/badge/linguagem-GDScript-355570)
![Android](https://img.shields.io/badge/plataforma-Android-3DDC84?logo=android&logoColor=white)
![Status](https://img.shields.io/badge/status-Marco%201-orange)

Shoot 'em up vertical (bullet hell) para celular, em 2D, feito em **Godot 4** com **GDScript**. O jogador controla a nave com toque relativo, e **soltar o dedo deixa o jogo em câmera lenta**: é nesse momento que se troca o corpo da nave.

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

| Marco | Objetivo | Status |
|---|---|---|
| **0** | Protótipo: nave com controle relativo e câmera lenta no S24 | ✅ |
| **1** | Jogável mínimo: 2 corpos, troca de corpo, 1 inimigo, 1 fase, 3 hits | 🟡 em teste (com 4 corpos) |
| **2** | Núcleo completo: 4 corpos, 4 armas com 5 níveis, especial, bomba, chefe | ⚪ |
| **3** | Conteúdo: inimigos, chefes, 1º planeta, áudio, revive por anúncio | ⚪ |
| **4** | Polimento e publicação | ⚪ |

**O que já existe:**
- **Marco 0:** retrato 1080×1920, controle relativo por toque/mouse, câmera lenta ao soltar o dedo, menu inicial, pausa, overlay de debug e textos em PT-BR/EN.
- **Marco 1 (em teste):** 4 corpos com 5 níveis de arma e troca na câmera lenta, power-ups, 4 tipos de inimigo (Drone, Mirador, Kamikaze, Tanque), 2 planetas com 3 fases cada, seletor de fases com desbloqueio e recordes salvos no aparelho, HUD com progresso e pontuação, telas de resultado e interface com tema próprio. Tudo com placeholders desenhados por código.

---

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

O overlay de FPS só aparece em builds de **debug**. Roteiros de teste: [`docs/MARCO0_TESTE.md`](docs/MARCO0_TESTE.md) e [`docs/MARCO1_TESTE.md`](docs/MARCO1_TESTE.md).

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
| `data/formations/` | formação usada na partida (lista de corpos, qualquer quantidade) |
| `data/enemies/` | inimigos: vida, pontos, movimento (descer, cruzar, mergulhar) e tiro (reto, mirado, anel) |
| `data/stages/` | fases: duração, inimigos, pesos e intervalo entre surgimentos |
| `data/planets/`, `data/campaign.tres` | planetas (nome, cores, fases) e ordem da campanha |

---

## Estrutura do projeto

```
docs/            GDD e roteiros de teste
scenes/          cenas (.tscn) pequenas: menu (inicial), stage_select e game (partida)
scripts/
  core/          params, sessão, save, partida, estado, colisão, câmera lenta, pools, fundo
  player/        nave (núcleo + corpo), toque, troca de corpo, BodyData
  weapons/       armas (raio, projéteis, órbita), projéteis, WeaponData
  enemies/       inimigos, surgimento, EnemyData e StageData
  ui/            tema, menus, seletor, pausa, resultados, HUD, transições, debug
data/            campanha, planetas, fases, inimigos, armas, corpos e formações (.tres)
  i18n/          tabela de tradução strings.csv (chave, en, pt_BR)
assets/          imagens e áudio (placeholders até o Marco 2)
builds/          APKs exportados (não versionado)
```

**Autoloads:** `Params` (tuning), `Session` (fase escolhida), `SaveGame` (progresso em `user://save.json`) e `SceneTransition` (fade entre telas).

**Princípios:** GDScript tipado, parâmetros centralizados em `Params`, dados fora do código, pooling desde o início e suporte a N corpos. Detalhes em [`CLAUDE.md`](CLAUDE.md).

---

## Contribuindo

Os commits seguem o padrão **[Conventional Commits](https://www.conventionalcommits.org/pt-br/v1.0.0/)**. Veja tipos, escopos e o fluxo de trabalho em [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Licença

© 2026 Gabriel ([@GDPonsoni](https://github.com/GDPonsoni)). Todos os direitos reservados. O código está visível para consulta, mas não há licença de uso, cópia ou redistribuição.
