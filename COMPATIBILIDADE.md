# O que roda no M17 com o tutu8bits

Os emuladores e jogos nativos que o tutu8bits-ports compila, como rodam no **M17** (placa `W12D-V02`, RK3168, 2×
Cortex-A9 a 1,2 GHz, 256 MB; o aparelho está descrito no
[`docs/APARELHO.md`](https://github.com/MarTinazzI/tutu8bits/blob/main/docs/APARELHO.md) do tutu8bits) e como se joga
cada tipo.

As notas são **V/S/C** (velocidade, som, controles), de 1 a 5, dadas jogando no aparelho. CPU em % de **um** núcleo.

**Atualizado em:** 2026-10-25.

---

## 1. Emuladores (21 sistemas)

| Sistema | Emulador padrão (alternativa) | Resultado |
| :--- | :--- | :--- |
| PlayStation | `pcsx_rearmed` | 5/5/5 (CTR, Vagrant Story, BoF III); 3D preso em ~25–27 fps pela renderização |
| PSP | PPSSPP **1.20.4** standalone (núcleo libretro de reserva) | Yggdra 5/5/5, PSP2 4/4/4, GTA VCS 4/4/4; RAM no limite (~2 MB livres) |
| Nintendo 64 | `parallel_n64` com dieta de memória + plugin `gln64` | Bomberman 64, Mario Kart 64 4/3/4, Quest 64 4/4/4; Smash 2/2/2; Conker não abre |
| Game Boy Advance | `gpsp` (`mgba`) | 5/5/5 |
| Super Nintendo | `snes9x2005_plus` (`snes9x`) | 4–5 (Star Fox, Kirby); Tales of Phantasia só no `snes9x` |
| Mega Drive, Master System, Game Gear | `picodrive` | 4–5 (inclusive o SVP do Virtua Racing) |
| Nintendo (NES) | `fceumm` | 5/5/5 |
| Game Boy / Color | `gambatte` | 5/5/5 |
| Arcade | `mame2003_plus` (`fbneo`) | 5/5/5 quando o *romset* bate |
| Neo Geo | `fbneo` | 3–4, RAM no limite |
| PICO-8 | `fake08` | 5/5/5 (Celeste) |
| GameTank | GameTank Emulator | 3/3/3 a 4/4/4 |
| Atari 2600, 5200, 7800, Lynx (um cartão "Atari" no menu) | `stella2014`, `a5200`, `prosystem`, `handy` | 60 fps, 25–42 %; sem BIOS |
| PC Engine | `mednafen_pce_fast` | 60 fps, 30–37 % |
| Neo Geo Pocket Color | `race` (`mednafen_ngp`) | 60 fps, ~32 % |

- RetroArch **1.22.2** (vídeo pelo contexto SDL GL; o `fbdev_mali` não abre), preso ao núcleo 1.
- Nos sistemas pesados, ROMs **sempre descompactadas**: o `.zip` vai inteiro para a RAM, e um N64 de 64 MB nem carrega.
- N64, PSP e os ports usam os analógicos de verdade (`key_mode` 6, ver o `APARELHO.md` §2.2).

## 2. Jogos nativos (sistema "Jogos")

| Jogo | Motor | Dados | CPU |
| :--- | :--- | :--- | :---: |
| Cave Story | NXEngine-evo | freeware: o jogador copia | 13 % |
| Freedoom 1 e 2; Doom, Doom II, TNT, Plutonia, NRFTL, Master Levels, Sigil, Sigil II | Crispy Doom 7.2 | Freedoom baixado pelo build; os WADs comerciais, o jogador copia | 38–49 % |
| Blasphemer; Heretic | Crispy Heretic | Blasphemer baixado pelo build | 45–51 % |
| Hexen (e Deathkings) | Crispy Hexen | o jogador copia | 45 % |
| Strife | Crispy Strife | o jogador copia | até 70–83 % |
| Wolfenstein 3D (shareware), completo, Spear of Destiny e missões | Wolf4SDL | shareware baixado pelo build | 9–18 % |
| Duke Nukem 3D (shareware) e completo | JFDuke3D (software, 320×240) | shareware baixado pelo build | 76 % |
| LibreQuake; Quake e as duas expansões | TyrQuake original, nativo (480×272, 59 fps; 320×240 na configuração do jogo) | LibreQuake baixado pelo build | 83 % |
| Tyrian 2.1 | OpenTyrian | freeware: o jogador copia | 17 % |
| Rogue 5.4.4 | curses própria sobre o SDL2 | o jogo inteiro (BSD) | ~3 % |
| NetHack 3.6.7 | interface `m17` própria + teclado virtual | o jogo inteiro (NGPL) | ~3 % |
| Dink Smallwood; os D-Mods do jogador | GNU FreeDink 109.6 (software, 640×480 com tarjas; MIDI pelo Timidity) | os dados do Dink baixados pelo build; os D-Mods, o jogador copia | 70–79 % |

Todos os ports: joystick cru, `key_mode` 6, ALT filtrado pela `libSDL2` do tutu8bits, saída pelo VOL+ segurado,
captura pelo ALT+Y e menu do jogo (X na lista) com escolhas por jogo. O **Abuse** foi testado e descartado (cai no
aparelho).

## 3. Controles por tipo de jogo

Os botões do aparelho e os atalhos do sistema (ALT = VOL−, VOL+ = menu e sair) estão no `APARELHO.md` §2.

- **Emuladores (RetroArch):** botões gerados de [`config/keymap.json`](config/keymap.json) pelo `gerar_cfg.py`, por
  posição no RetroPad; o remap por jogo (Controls) fica em `home/config/remaps/`. N64: analógico esquerdo = stick,
  direito = botões C.
- **Jogos de tiro (Doom, Heretic, Hexen, Strife, Wolf3D, Duke, Quake):** um esquema só,
  [`config/controles_fps.csv`](config/controles_fps.csv): analógico esquerdo anda e vai de lado, o direito gira e
  olha, R2 atira, L1/R1 trocam a arma, L3 liga e desliga o andar devagar, SELECT mapa, START ou VOL+ menu.
- **Dink e D-Mods (FreeDink):** A ataca e clica, B fala, X magia, Y inventário, START menu, SELECT mapa, L1–R2 os
  botões 7–10 do D-Mod; nos menus de cursor o D-pad salta entre os botões e o analógico direito move o cursor; R3 abre
  a roda com as teclas do D-Mod.
- **Rogue e NetHack:** só com o controle; diagonais por acorde, analógico em 8 setores; texto pelo teclado virtual.
- **Teclado virtual** (componente do tutu8bits): grade 4×10; A digita, B apaga, START confirma. Nos ports que pedem
  texto (nomes de save, NetHack).
- **Roda de opções** (componente do tutu8bits): R3 abre, o analógico direito escolhe a fatia, A confirma; até 8 fatias
  por página (L1/R1 trocam). Para os comandos que não cabem nos botões (no NetHack e nos D-Mods).
