# Pendências da versão 3D e ponto de retomada

Atualizado em 2026-11-10.

## Onde está

- **Feito e commitado (branch `feat/3d-render`):** T0 a T12. APK em `builds/nucleon-squad-3d.apk` (fora do git).
- **Não instalado no S24:** `adb devices` não listou aparelho. Instalar: `~/Android/Sdk/platform-tools/adb install -r builds/nucleon-squad-3d.apk`.
- **Em seguida (se houver cota):** T13 (cenário) e T14 (partículas). Ver o fim deste arquivo.
- **Sem merge na `main`:** fica para o Gabriel, depois do teste.

## Limitações conhecidas

- **Nada foi testado no S24.** O visual foi conferido só por fotos no PC (`scripts/tools/shot_3d.gd`), em janela de 540 px de largura. Roteiro: `docs/3D_TESTE.md`.
- **FPS no aparelho não medido.** Custos novos: uma textura do tamanho da tela por quadro (`ground_fx_resolution`) e a atualização por script de cada projétil. No PC (Radeon integrada) ficou em 58 a 60 FPS, inclusive em chefe.
- **Controle:** o arraste do dedo continua em px do jogo; com a perspectiva, a nave anda um pouco menos que o dedo no fundo da tela e um pouco mais perto da base.
- **Efeitos ainda planos** (deitados no plano de jogo, sem volume): explosões, faíscas, raio, Tesla, órbita, especiais, avisos, escudos e auras.
- **Transparência por retícula:** nave invulnerável, auxiliar recolhida e anel do núcleo ficam "pontilhados" em vez de translúcidos (mais barato e sem problema de ordenação). Em 1080 px deve ficar mais fino que nas fotos.
- **Seguimento da câmera** em 60 px, não 120 (D3 em `docs/3D_DECISOES.md`).
- **Sombra das naves:** não há (o plano permitia "no máximo uma sombra-mancha").
- **Falhas antigas:** `pager_regressions` segue com as 4 falhas que já existiam na versão 2D.

## Ideias para depois do teste

- Converter o toque pela projeção inversa, para a nave ficar sempre embaixo do dedo.
- Dar volume aos tiros da Órbita e ao raio.
- Projéteis: preencher o `MultiMesh` com um buffer só (`multimesh.buffer`) se o custo por tiro pesar no S24.
