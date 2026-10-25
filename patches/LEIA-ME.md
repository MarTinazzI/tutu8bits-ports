# Patches do tutu8bits-ports e as licenças deles

Um patch é uma obra derivada do programa que ele modifica: só existe em cima daquele fonte e carrega trechos dele.
Por isso **cada patch segue a licença do programa onde entra**, e cada arquivo daqui diz a sua na primeira linha
(`Licença: ...`). O `src/emu/build.sh` do tutu8bits aplica os patches em ordem, depois de baixar o fonte na versão de
`ports/versoes.txt`.

| Patches | Programa | Licença |
| :--- | :--- | :--- |
| `retroarch-*` | RetroArch | GPL-3.0 |
| `ppsspp-*`, `ppsspp_sdl-*` | PPSSPP (núcleo libretro e standalone) | GPL-2.0-or-later |
| `crispy_doom-*` | Crispy Doom (Doom, Heretic, Hexen, Strife) | GPL-2.0 |
| `opentyrian-*` | OpenTyrian | GPL-2.0 |
| `tyrquake_sdl-*` | TyrQuake | GPL-2.0 |
| `wolf4sdl-*` | Wolf4SDL | GPL-2.0 ou a licença da id (as do Wolf4SDL) |
| `jfduke3d-*` | JFDuke3D e o motor Build (`jfbuild/`) | GPL-2.0 nos trechos do jogo; **licença do Build** (Ken Silverman, não comercial) nos trechos de `jfbuild/` |
| `nxengine-*` | NXEngine-evo | GPL-3.0 |
| `freedink-*` | GNU FreeDink | GPL-3.0-or-later |
| `nethack-*` | NetHack | NGPL (NetHack General Public License) |
| `rogue-*` | Rogue 5.4.4 | BSD-3-Clause |
| `glsm_m17.py`, `n64mem_m17.py`, `n64analog_diag_m17.py` | scripts que alteram o fonte do parallel-n64 | GPL-2.0 (a do que eles alteram) |

As interfaces que vivem dentro de um port seguem a mesma regra: `nethack_m17/` (compila com o `hack.h`) é NGPL, e
`rogue_m17/` vai sob a BSD-3 do Rogue. Os componentes do tutu8bits que os ports usam (o teclado virtual, a roda e o
filtro `m17_alt` da SDL2) são MIT e continuam MIT dentro dos binários dos ports.

**Quem distribuir um build** (os binários) precisa cumprir as licenças dos programas: oferecer o fonte correspondente
(`ports/fontes.sh` gera um arquivo por componente, na versão exata, com estes patches à parte), incluir os textos de
licença (`ports/completar_cartao.sh` os põe em `cartao/tutu8bits/LICENCAS/`) e respeitar as não comerciais (não vender;
pela licença do FBNeo, não pedir doação).
