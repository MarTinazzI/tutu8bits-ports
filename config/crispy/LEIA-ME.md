# Configuração inicial do Crispy Doom (spec 031, plano D-05/D-06)

Só as chaves que o produto muda; o motor preenche o resto e regrava os dois arquivos completos ao sair. O
lançador copia estes arquivos para `saves/jogos/crispy-doom/` **só se não existirem** (o que o jogador mudar no
menu do jogo fica). Os nomes das chaves saíram dos `.cfg` que o próprio motor grava (T04, qemu).

- **Joystick `i2c-keys`** (KB §11k): `use_joystick 1`, `joystick_guid` do aparelho, `joystick_index 0`, joystick
  cru (`use_gamepad 0`). Os botões virtuais são iguais aos físicos (padrão do motor: `joystick_physical_buttonN = N`),
  então cada `joyb_*` recebe o índice do botão do aparelho.
- **Dois analógicos** (controles "modernos", pedido do mantenedor na T12; o lançador põe o `key_mode` 6, KB §11:
  eixos reais, esquerdo = SDL 0/1, direito = SDL 2/3): `joystick_y_axis 1` e `joystick_strafe_axis 0` = o
  esquerdo anda e vai de lado; `joystick_x_axis 2` = o direito gira. Proporcionais (`use_analog 1`, padrão).
- **D-pad junto:** o Crispy lê uma fonte por eixo; o patch `crispy_doom-m17-02-controles` faz o D-pad (13–16)
  girar e andar quando o analógico está parado — não há chave para isso.
- **Botões (spec 043, esquema comum aos jogos de tiro; `ports/config/controles_fps.csv`):** R2 10 atira (`joyb_fire`), X 9
  usa/abre (`joyb_use`), A 6 pula (`joyb_jump`; no Doom com `crispy_jump 1`, o pulo opcional do Crispy), L3 1 anda
  devagar, liga/desliga (`joyb_speed`; o patch 02 deixa sempre correndo e o L3 alterna), SELECT 12 mapa
  (`joyb_toggle_automap`), L1 7 / R1 3 arma anterior / próxima, START 5 menu (`joyb_menu_activate`). B e L2 livres;
  `joyb_strafe` e o "de lado" por botão desligados (-1). **Olhar** com o analógico direito vertical
  (`joystick_look_axis 3`; no Doom com `crispy_freelook 1`). A sensibilidade e a inversão são gravadas pelo
  `lancar.sh` a cada partida (menu do jogo do tutu8bits, spec 044). **No menu do jogo**, A escolhe e B volta (patch
  02, fixo no motor). L3 (1) e R3 (2) são índices deduzidos (KB §11k, H).
- **Vídeo:** tela cheia; widescreen que acompanha a tela; **alta resolução desligada** (D-06: a sessão mede ligada);
  sem desenho livre (`crispy_uncapped 0`: 35 quadros/s, o vsync não limita no aparelho, KB §11i).

## Heretic e Strife (spec 033, plano D-04)

Mesmos motores do Crispy, mesmo fonte e mesma base do Doom: `heretic.cfg` + `crispy-heretic.cfg` e `strife.cfg` +
`crispy-strife.cfg`, copiados para `saves/jogos/crispy-doom/` só quando faltam. Os eixos e os botões comuns são os do
Doom (acima). A mais:

- **Heretic:** Y 4 usa o item do inventário (`joyb_useartifact`); D-pad ← 14 / → 15 item anterior/próximo
  (`joyb_invleft`/`joyb_invright`); D-pad ↑ 13 / ↓ 16 voar sobe/desce (`joyb_flyup`/`joyb_flydown`); R3 2 centraliza
  o voo (`joyb_flycenter`). Não pula (o Crispy Heretic não tem pulo). Como o D-pad inteiro tem ação, ele não anda nem
  gira (patch 02: o D-pad só vira eixo nos botões sem ação).
- **Strife:** Y 4 usa o item; D-pad ←/→ inventário; A 6 pula; D-pad ↑/↓ continuam andando; o olhar é por limiar (o
  Strife não tem olhar proporcional). **`show_endoom 0`:** o Strife vem com a tela de texto de saída ligada
  (`show_endoom 1`, fonte `strife/d_main.c`), que espera uma tecla dentro do `I_Quit` — a saida (SIGTERM) travava (V,
  qemu). O Doom e o Heretic já vêm com 0.

## Hexen (spec 038, plano D-03)

`hexen.cfg` + `crispy-hexen.cfg`, na mesma pasta e do mesmo jeito (copiados só quando faltam). Os botões do Heretic
(acima), mais o pulo (A 6, `joyb_jump`). O patch `crispy_doom-m17-04-hexen` faz no
menu do Hexen o que os patches 01 e 02 fazem nos outros: fechar direto, sempre correndo, A/B no menu. O Hexen
preenche sozinho o nome do save ("HUB n.m, classe") e não tem a tela de texto de saída.
