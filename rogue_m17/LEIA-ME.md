# rogue_m17 — a camada do Rogue no M17 (spec 035)

A receita `ports/receitas/rogue.sh` copia estes arquivos para o fonte do Rogue (`.cache/emu/src/rogue`, ramo
`modern-rogue`), aplica o patch `ports/patches/rogue-m17-01-ganchos.patch` e compila tudo junto, sem `configure` e
sem ncurses.

| Arquivo | O quê |
| :--- | :--- |
| `config.h` | o que o `configure` geraria para a glibc; placar `rogue.scr` relativo, sem trava nem *setgid* |
| `curses.h`, `m17curses.c` | a curses própria: só as funções que o Rogue usa; tela 80×24 na memória (caractere + vídeo inverso), janelas e subjanelas, `wrefresh` copia só o que mudou (plano D-02) |
| `m17video.c` | a tela: fonte misc-fixed 6×10 (domínio público) em célula 6×11, buffer RGB565 480×272, textura do SDL2 só quando muda; `M17_TELA=<bmp>` e `M17_TELA_TXT=<txt>` gravam a última tela (testes) |
| `m17entrada.c/.h` | a entrada: parte **pura** (acorde, 8 setores, giro do R1, repetição, correr com B, tradução por pergunta, `rogue.cfg`) testada no PC; parte SDL (teclado, joystick cru, roteiro `M17_ROTEIRO`) |
| `m17menus.c` | SELECT (comandos), START (o jogo) e o seletor de objeto, desenhados por cima da tela do jogo |
| `m17_ponte.c` | o que a camada lê do jogo: herói na escada, itens da mochila por tipo, salvar e sair |
| `m17.h` | o que esses arquivos dividem |
| `bdf_para_h.py` | converte o BDF da fonte (`ports/baixar_conteudo.sh fonte6x10`) em `m17_fonte.h` no build |

**Ganchos no jogo (patch, tudo atrás de `#ifdef M17`):** `md_readchar` lê da camada; a pergunta em curso
(`m17_contexto`): "qual objeto?" (`get_item`), "direção?" (`get_dir`), sim/não (`quit`, save), texto (`get_str`),
opções (`get_bool`/`get_inv_t`), `--More--`/`wait_for`; o SIGTERM salva (`md_onsignal_autosave` no `setup`), e depois
do placar (`score`) só sai; `[M17] salvo` / `[M17] fim` no log; o `!` (shell) desligado; `getpwuid` sem usuário não
derruba (qemu).

**Roteiro de teste** (`M17_ROTEIRO=<arq>`): texto que vira teclas; `\e` = Esc, `\n` = Enter; `{A}` `{B}` `{X}` `{Y}`
`{L1}` `{L2}` `{R2}` `{SELECT}` `{START}` `{cima}` `{baixo}` `{esq}` `{dir}` = o botão do controle, pela mesma tradução.
No fim escreve `[M17] roteiro: fim` e passa a esperar o teclado/controle.
