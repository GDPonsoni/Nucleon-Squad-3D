# Pendências da versão 3D e ponto de retomada

Atualizado em 2026-11-10.

## Onde está

- **Feito e commitado (branch `feat/3d-render`):** T0 a T14, o plano inteiro. APK em `builds/nucleon-squad-3d.apk` (fora do git), gerado depois da T14.
- **Não instalado no S24:** `adb devices` não listou aparelho. Instalar: `~/Android/Sdk/platform-tools/adb install -r builds/nucleon-squad-3d.apk`.
- **Próximo passo:** teste do Gabriel no S24 (`docs/3D_TESTE.md`). Nenhuma tarefa do plano ficou para trás.
- **Sem merge na `main`:** fica para o Gabriel, depois do teste.

## Limitações conhecidas

- **Nada foi testado no S24.** O visual foi conferido só por fotos no PC (`scripts/tools/shot_3d.gd`), em janela de 540 px de largura. Roteiro: `docs/3D_TESTE.md`.
- **FPS no aparelho não medido.** Custos novos: uma textura do tamanho da tela por quadro (`ground_fx_resolution`) e a atualização por script de cada projétil. No PC (Radeon integrada) ficou em 58 a 60 FPS, inclusive em chefe.
- **Controle:** o arraste do dedo continua em px do jogo; com a perspectiva, a nave anda um pouco menos que o dedo no fundo da tela e um pouco mais perto da base.
- **Efeitos ainda planos** (deitados no plano de jogo, sem volume): clarão e anel das explosões, raio, Tesla, órbita, especiais, avisos, escudos e auras. Estilhaços e fagulhas já são partículas 3D.
- **Partículas no aparelho:** são atualizadas em script, uma a uma (até 420). Se pesarem no S24, baixar `particle_budget_3d` ou `particles_enabled_3d = false` (devolve os estilhaços 2D no plano).
- **FPS no PC, não no S24:** fase 5-8 a 143 quadros/s em 3D contra 174 em 2D (cerca de 18% mais caro), numa janela de 540 px. No S24 a tela tem 4 vezes mais pixels.
- **Transparência por retícula:** nave invulnerável, auxiliar recolhida e anel do núcleo ficam "pontilhados" em vez de translúcidos (mais barato e sem problema de ordenação). Em 1080 px deve ficar mais fino que nas fotos.
- **Seguimento da câmera** em 60 px, não 120 (D3 em `docs/3D_DECISOES.md`).
- **Sombra das naves:** não há (o plano permitia "no máximo uma sombra-mancha").
- **Falhas antigas:** `pager_regressions` segue com as 4 falhas que já existiam na versão 2D.

## Ideias para depois do teste

- Converter o toque pela projeção inversa, para a nave ficar sempre embaixo do dedo.
- Dar volume aos tiros da Órbita e ao raio.
- Projéteis: preencher o `MultiMesh` com um buffer só (`multimesh.buffer`) se o custo por tiro pesar no S24.
