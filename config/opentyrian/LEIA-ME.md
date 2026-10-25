# Configuração inicial do OpenTyrian (spec 034, plano D-07)

`opentyrian.cfg` vai para `tutu8bits/jogos/opentyrian/padrao/` e o `lancar.sh` o copia para
`saves/jogos/opentyrian/` **só quando falta** (o que o jogador muda no menu do jogo fica). Ele **não** pode ficar ao
lado do binário: com um `opentyrian.cfg` na pasta do executável, o OpenTyrian entra em modo "portátil" e grava
configuração e saves ali (fonte `file.c`).

Só as seções que mudam; o resto o jogo preenche com o padrão e regrava na saída.

- **`video`:** `fullscreen 0` (tela inteira no display 0), `scaler None` (320×200 direto para o renderer; o padrão
  `Scale2x` gasta CPU para depois reduzir), `scaling_mode Fit 4:3` (≈ 363×272; spec §8).
- **`joystick 'i2c-keys'`** (nome do joystick cru do aparelho, KB §11k). Os códigos do jogo contam a partir de 1:
  `BTN n` = índice `n-1` do SDL, `AX n±` = eixo `n-1`. Cada direção tem o analógico esquerdo (eixos 0/1 no
  `key_mode` 6, KB §11z) **e** o D-pad (botões 13–16):

  | Ação | Botão | Código |
  | :--- | :--- | :--- |
  | cima / direita / baixo / esquerda | analógico + D-pad | `AX 2-`+`BTN 14` / `AX 1+`+`BTN 16` / `AX 2+`+`BTN 17` / `AX 1-`+`BTN 15` |
  | atirar | A (6) | `BTN 7` |
  | trocar o modo de tiro | B (11) | `BTN 12` |
  | *sidekick* esquerdo / direito | L1 (7) / R1 (3) | `BTN 8` / `BTN 4` |
  | menu | START (5) | `BTN 6` |
  | pausa | Y (4) | `BTN 5` |

  Nos menus o jogo confirma com atirar ou menu (A/START) e volta com trocar tiro ou pausa (B/Y) (`joystick.c`).
