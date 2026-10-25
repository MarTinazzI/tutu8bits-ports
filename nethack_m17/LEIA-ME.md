# nethack_m17 — o NetHack 3.6.7 no M17 (spec 036)

A interface de janelas **m17** do NetHack (o jogo chama as funções de `m17_procs`; plano D-02), compilada pela
receita `ports/receitas/nethack.sh`, que copia estes arquivos para `win/m17/` do fonte fixado.

- `winm17.c` — a interface: mapa, mensagens, estado, listas, perguntas, posição no mapa, texto (teclado virtual).
- `m17nh_video.c` — a tela 80×24 colorida (fonte 6×10 da spec 035, célula 6×11).
- `m17nh_entrada.c` — a tradução botão → tecla por contexto (pura) e a leitura do controle (sobre o `m17e_passo` da
  spec 035, `ports/rogue_m17/m17entrada.c`, compilado só com a parte pura).
- `m17nh.h` — o que os arquivos dividem.
- `hints-m17` — o arquivo de *hints* do build do NetHack (`sys/unix/setup.sh`).
- `nethackrc`, `sysconf` — as opções do produto e a configuração do sistema do jogo (copiadas pelo lançador).

O teclado virtual é o componente comum `src/emu/teclado_m17/`.
