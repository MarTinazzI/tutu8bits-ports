#!/usr/bin/env bash
# ==============================================================================
# tutu8bits — completa o cartao/ com o que e compilado ou gerado (spec 028, D-08). Roda no PC.
#
# O cartao/ do repositorio e a raiz do cartao. O que esta no git ja esta no lugar; este script poe
# junto o que NAO vai para o git:
#   - do build dos emuladores (.cache/emu/out, src/emu/build.sh): RetroArch, nucleos usados por
#     dados/emuladores.lua, GameTank, PPSSPP standalone e os arquivos de sistema do PPSSPP;
#     o NXEngine-evo (Cave Story, spec 030: nx, extract e o data/ do motor em jogos/nxengine/) e as
#     libs SDL2_mixer e SDL2_image dele (em lib/, ao lado da libSDL2); o Crispy Doom (spec 031: crispy-doom e a
#     configuracao inicial em jogos/crispy/) e o Freedoom (jogos/freedoom/, do zip baixado por
#     ports/baixar_conteudo.sh freedoom); spec 033: crispy-heretic e crispy-strife (mesma receita) com a
#     configuracao inicial deles, e o Blasphemer (jogos/blasphemer/; baixar_conteudo.sh blasphemer); spec 038: o
#     crispy-hexen com a configuracao inicial dele (o Hexen e do jogador); spec 034: o
#     OpenTyrian (jogos/opentyrian/) com a configuracao inicial em jogos/opentyrian/padrao/ (os dados do Tyrian
#     NAO vao: o zip so traz a licenca comercial da Epic; o jogador copia para roms/jogos/tyrian/); spec 035: o Rogue
#     inteiro (BSD) em jogos/rogue/ (o motor e o LEIA-ME.txt); spec 037: os motores do Wolf3D em jogos/wolf4sdl/ e o
#     shareware 1.4 inteiro em jogos/wolf3d/ (baixar_conteudo.sh wolf3d); spec 040: o JFDuke3D em jogos/jfduke3d/ (com o
#     duke3d.cfg inicial e o gamecontrollerdb.txt) e o shareware 1.3d inteiro em jogos/duke3d/; spec 039: o LibreQuake
#     lite em jogos/librequake/id1/; spec 050: o TyrQuake original em jogos/tyrquake/
#     (o motor, o config.cfg inicial e o gamecontrollerdb.txt); spec 036: o NetHack inteiro (NGPL) em jogos/nethack/ (o
#     motor, o recover, os dados nhdat/license/symbols, o sysconf e o nethackrc do produto e o LEIA-ME.txt); spec 047:
#     o GNU FreeDink em jogos/dink/ (o motor, a LiberationSans e o dink/ do freedink-data, baixar_conteudo.sh
#     freedink_data), o FreePats em midi/freepats/ (a musica MIDI pelo Timidity da SDL2_mixer; baixar_conteudo.sh
#     freepats) e as libs SDL2_ttf e SDL2_gfx em lib/;
#   - gerados: retroarch.cfg.modelo, gamecontrollerdb.txt (GameTank e PSP), LICENCAS/ e
#     exemplos/.pacote (id desta montagem; o boot reinstala os temas de exemplo que faltam).
# O motor e os nativos (cartao/tutu8bits/bin, lib) sao gravados direto pelos builds deles
# (src/motor/build.sh, src/nativos/build.sh); aqui so se confere que existem.
#
# Antes: src/emu/build.sh (RetroArch, nucleos, sdl2_projeto), src/motor/build.sh, src/nativos/build.sh.
# Uso: ports/completar_cartao.sh
# Variavel: TUTU_REPOSITORIO (endereco publico do codigo, citado no LEIA-ME das licencas).
# ==============================================================================
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TUTU="$REPO/cartao/tutu8bits"
OUT="$REPO/.cache/emu/out"
FONTES="$REPO/.cache/emu/src"
TUTU_REPOSITORIO="${TUTU_REPOSITORIO:-https://github.com/MarTinazzI/tutu8bits}"
PORTS_REPOSITORIO="${PORTS_REPOSITORIO:-https://github.com/MarTinazzI/tutu8bits-ports}"
VERSAO=$(sed -n 's/^#define TUTU_VERSAO "\(.*\)"/\1/p' "$REPO/src/motor/motor.h")
[ -n "$VERSAO" ] || { echo "ERRO: versao nao encontrada em src/motor/motor.h" >&2; exit 1; }

for f in "$TUTU/bin/tutu" "$TUTU/lib/libSDL2-2.0.so.0" "$TUTU/bin/bootscreen" "$TUTU/bin/m17atalhos" \
         "$TUTU/bin/lebateria" "$TUTU/bin/medir013" \
         "$OUT/retroarch/retroarch" "$OUT/gametank/GameTankEmulator" "$OUT/cores/ppsspp_libretro.so" \
         "$OUT/ppsspp_sdl/PPSSPPSDLTUTU" "$OUT/system/PPSSPP/compat.ini" \
         "$OUT/nxengine/nx" "$OUT/nxengine/extract" "$OUT/nxengine/data/sprites.sif" \
         "$OUT/sdl2_mixer/libSDL2_mixer-2.0.so.0" "$OUT/sdl2_image/libSDL2_image-2.0.so.0" \
         "$OUT/crispy_doom/crispy-doom" "$REPO/ports/config/crispy/default.cfg" "$REPO/ports/config/crispy/crispy-doom.cfg" \
         "$REPO/.cache/emu/conteudo/freedoom/freedoom-0.13.0.zip" \
         "$OUT/crispy_doom/crispy-heretic" "$OUT/crispy_doom/crispy-strife" "$OUT/crispy_doom/crispy-hexen" \
         "$REPO/.cache/emu/conteudo/blasphemer/blasphem-0.1.8.zip" "$REPO/.cache/emu/conteudo/blasphemer/COPYING.md" \
         "$OUT/opentyrian/opentyrian" "$REPO/ports/config/opentyrian/opentyrian.cfg" \
         "$OUT/rogue/rogue" "$REPO/ports/rogue_m17/LEIA-ME-jogo.txt" \
         "$OUT/wolf4sdl/wolf3d" "$OUT/wolf4sdl/wolf3d-sw" "$OUT/wolf4sdl/spear" "$REPO/.cache/emu/conteudo/wolf3d/wolf3d14.zip" \
         "$OUT/jfduke3d/duke3d" "$REPO/ports/config/duke3d/duke3d.cfg" "$REPO/ports/config/duke3d_controle.json" \
         "$REPO/.cache/emu/conteudo/duke3d/3dduke13_data.7z" \
         "$REPO/.cache/emu/conteudo/librequake/lite.zip" \
         "$OUT/tyrquake_sdl/tyr-quake" "$REPO/ports/config/tyrquake/config.cfg" \
         "$OUT/nethack/nethack" "$OUT/nethack/recover" "$OUT/nethack/nhdat" "$OUT/nethack/license" "$OUT/nethack/symbols" \
         "$REPO/ports/nethack_m17/LEIA-ME-jogo.txt" "$REPO/ports/nethack_m17/nethackrc" "$REPO/ports/nethack_m17/sysconf" \
         "$OUT/freedink/freedink" "$OUT/freedink/LiberationSans-Regular.ttf" "$OUT/sdl2_ttf/libSDL2_ttf-2.0.so.0" \
         "$OUT/sdl2_gfx/libSDL2_gfx-1.0.so.0" "$REPO/.cache/emu/conteudo/freedink_data/freedink-data-1.08.20190120.tar.gz" \
         "$REPO/.cache/emu/conteudo/freepats/freepats_20060219.orig.tar.gz" \
         "$REPO/ports/config/gametank_controle.json" "$REPO/ports/config/psp_controle.json"; do
    [ -f "$f" ] || { echo "ERRO: falta $f (veja 'Antes' no cabecalho)" >&2; exit 1; }
done

# Uma execucao por vez (o ports/montar.sh e o levar.sh chamam este script, inclusive em testes paralelos).
mkdir -p "$REPO/.cache"
exec 9> "$REPO/.cache/completar_cartao.trava"
flock 9
# Tudo e montado numa area propria (G) e so no fim sincronizado com o cartao/ por rsync: cada arquivo
# e trocado de uma vez (temporario + rename) e nunca ha uma pasta vazia no meio para quem estiver
# copiando o cartao/ ao mesmo tempo. --delete so dentro das pastas inteiramente geradas (um nucleo que
# saiu do emuladores.lua nao fica para tras).
G="$(mktemp -d "$REPO/.cache/completar.XXXXXX")"
trap 'rm -rf "$G"' EXIT
mkdir -p "$G/cores" "$G/gametank" "$G/ppsspp" "$G/LICENCAS" "$G/retroarch" "$G/exemplos" "$G/jogos/nxengine" "$G/lib" \
    "$G/jogos/crispy" "$G/jogos/freedoom" "$G/jogos/blasphemer" "$G/jogos/opentyrian/padrao" "$G/jogos/rogue" "$G/jogos/nethack" "$G/jogos/wolf4sdl" "$G/jogos/wolf3d" "$G/jogos/jfduke3d" "$G/jogos/duke3d" "$G/jogos/librequake" "$G/jogos/tyrquake" \
    "$G/jogos/dink" "$G/midi/freepats"

# ---------------------------------------------------------------- RetroArch e nucleos
cp "$OUT/retroarch/retroarch" "$G/retroarch/retroarch"
python3 "$REPO/ports/gerar_cfg.py" --raiz @RAIZ@ --saida "$G/retroarch/retroarch.cfg.modelo"
NUCLEOS=$(sed -n 's/.*nucleo = "\([a-z0-9_]*\)".*/\1/p' "$TUTU/dados/emuladores.lua" | sort -u)
for n in $NUCLEOS; do
    [ -f "$OUT/cores/${n}_libretro.so" ] || { echo "ERRO: nucleo $n nao compilado (src/emu/build.sh $n)" >&2; exit 1; }
    cp "$OUT/cores/${n}_libretro.so" "$G/cores/"
done

# GameTank Emulator (programa proprio com SDL2; spec 012): o binario e o mapeamento de game controller
# do i2c-keys, gerado do dado medido no aparelho (sem ele, nenhum botao chega ao jogo; KB §11k)
cp "$OUT/gametank/GameTankEmulator" "$G/gametank/GameTankEmulator"
python3 "$REPO/ports/gerar_gamecontrollerdb.py" --controle "$REPO/ports/config/gametank_controle.json" \
    --saida "$G/gametank/gamecontrollerdb.txt"

# PSP (spec 023): os dois candidatos, o nucleo libretro (cores/) e o standalone (ppsspp/PPSSPPSDLTUTU),
# com os mesmos arquivos de sistema duas vezes (o exFAT nao tem link): ppsspp/assets/ para o
# standalone (VFS e flash0 ao lado do programa) e ppsspp/PPSSPP/ para o nucleo (<system_directory>/PPSSPP;
# o lancar.sh aponta o system_directory do PSP para tutu8bits/ppsspp, fora da bios/ do usuario).
# O gamecontrollerdb.txt do standalone ganha a linha do i2c-keys (sem ela, nenhum botao chega; KB §11k).
cp "$OUT/cores/ppsspp_libretro.so" "$G/cores/"
cp "$OUT/ppsspp_sdl/PPSSPPSDLTUTU" "$G/ppsspp/PPSSPPSDLTUTU"
cp -r "$OUT/system/PPSSPP" "$G/ppsspp/assets"
cp -r "$OUT/system/PPSSPP" "$G/ppsspp/PPSSPP"
python3 "$REPO/ports/gerar_gamecontrollerdb.py" --controle "$REPO/ports/config/psp_controle.json" \
    >> "$G/ppsspp/assets/gamecontrollerdb.txt"

# ---------------------------------------------------------------- jogos nativos (spec 030)
# Cave Story: o motor (nx), o extract (tira do Doukutsu.exe do jogador os dados que o freeware nao traz
# soltos) e o data/ do motor ao lado (PORTABLE). Os dados do jogo NAO vao: o jogador baixa (roms/jogos/).
# As libs de som e imagem do motor vao para lib/, junto da libSDL2 que elas usam.
cp "$OUT/nxengine/nx" "$OUT/nxengine/extract" "$G/jogos/nxengine/"
cp -r "$OUT/nxengine/data" "$G/jogos/nxengine/data"
cp "$OUT/sdl2_mixer/libSDL2_mixer-2.0.so.0" "$OUT/sdl2_image/libSDL2_image-2.0.so.0" "$G/lib/"
# Doom (spec 031): o motor e a configuracao inicial do produto (o lancar.sh a copia para saves/jogos/crispy-doom
# so quando falta); o Freedoom (BSD) vem no pacote, o Doom original e do jogador (roms/jogos/doom/)
cp "$OUT/crispy_doom/crispy-doom" "$REPO/ports/config/crispy/default.cfg" "$REPO/ports/config/crispy/crispy-doom.cfg" "$G/jogos/crispy/"
python3 -I -c 'import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
for n in ("freedoom1.wad", "freedoom2.wad", "COPYING.txt"):
    open(sys.argv[2] + "/" + n, "wb").write(z.read("freedoom-0.13.0/" + n))' \
    "$REPO/.cache/emu/conteudo/freedoom/freedoom-0.13.0.zip" "$G/jogos/freedoom"
# Heretic e Strife (spec 033): os motores do mesmo fonte e a configuracao inicial deles; o Blasphemer (Heretic livre,
# BSD) vem no pacote; o Heretic e o Strife sao do jogador (roms/jogos/heretic/, roms/jogos/strife/)
CRISPY_CFG="$REPO/ports/config/crispy"
cp "$OUT/crispy_doom/crispy-heretic" "$OUT/crispy_doom/crispy-strife" "$CRISPY_CFG/heretic.cfg" "$CRISPY_CFG/crispy-heretic.cfg" \
    "$CRISPY_CFG/strife.cfg" "$CRISPY_CFG/crispy-strife.cfg" "$G/jogos/crispy/"
# Hexen (spec 038): o motor e a configuracao inicial; o jogo e do jogador (roms/jogos/hexen/)
cp "$OUT/crispy_doom/crispy-hexen" "$CRISPY_CFG/hexen.cfg" "$CRISPY_CFG/crispy-hexen.cfg" "$G/jogos/crispy/"
python3 -I -c 'import sys, zipfile; open(sys.argv[2], "wb").write(zipfile.ZipFile(sys.argv[1]).read("blasphem.wad"))' \
    "$REPO/.cache/emu/conteudo/blasphemer/blasphem-0.1.8.zip" "$G/jogos/blasphemer/blasphem.wad"
cp "$REPO/.cache/emu/conteudo/blasphemer/COPYING.md" "$G/jogos/blasphemer/COPYING.md"
# Tyrian (spec 034): o motor e a configuracao inicial numa subpasta (com um opentyrian.cfg ao lado do binario o jogo
# entra em modo portatil e grava tudo na pasta dele); o lancar.sh a copia para saves/jogos/opentyrian so quando falta
cp "$OUT/opentyrian/opentyrian" "$G/jogos/opentyrian/"
cp "$REPO/ports/config/opentyrian/opentyrian.cfg" "$G/jogos/opentyrian/padrao/"
# Rogue (spec 035): o jogo inteiro vem no pacote (BSD); save e placar ficam em saves/jogos/rogue (lancar.sh)
cp "$OUT/rogue/rogue" "$G/jogos/rogue/"
cp "$REPO/ports/rogue_m17/LEIA-ME-jogo.txt" "$G/jogos/rogue/LEIA-ME.txt"
# Wolfenstein 3D (spec 037): os 3 motores; o shareware 1.4 INTEIRO e sem mudanca (os 14 arquivos do zip, como a licenca
# dele pede: READ1ST.TXT, VENDOR.DOC); o completo e o Spear sao do jogador (roms/jogos/wolf3d/)
cp "$OUT/wolf4sdl/wolf3d" "$OUT/wolf4sdl/wolf3d-sw" "$OUT/wolf4sdl/spear" "$G/jogos/wolf4sdl/"
python3 -I -c 'import sys, zipfile, os
z = zipfile.ZipFile(sys.argv[1])
for n in z.namelist():
    if not n.endswith("/"):
        open(os.path.join(sys.argv[2], os.path.basename(n)), "wb").write(z.read(n))' \
    "$REPO/.cache/emu/conteudo/wolf3d/wolf3d14.zip" "$G/jogos/wolf3d"
# Duke Nukem 3D (spec 040): o motor, o duke3d.cfg inicial e o mapeamento de game controller do i2c-keys; o shareware
# 1.3d INTEIRO e sem mudanca (os arquivos do 7z, como o LICENSE.TXT dele pede; precisa do 7z do PC)
cp "$OUT/jfduke3d/duke3d" "$REPO/ports/config/duke3d/duke3d.cfg" "$G/jogos/jfduke3d/"
python3 "$REPO/ports/gerar_gamecontrollerdb.py" --controle "$REPO/ports/config/duke3d_controle.json" \
    --saida "$G/jogos/jfduke3d/gamecontrollerdb.txt"
command -v 7z > /dev/null || { echo "ERRO: falta o 7z (para o shareware do Duke Nukem 3D)" >&2; exit 1; }
( cd "$G/jogos/duke3d" && 7z x -y "$REPO/.cache/emu/conteudo/duke3d/3dduke13_data.7z" > /dev/null ) \
    || { echo "ERRO: shareware do Duke Nukem 3D" >&2; exit 1; }
# Quake (spec 039; o motor desde a spec 050 e o TyrQuake original, logo abaixo): o LibreQuake lite (livre) em
# jogos/librequake/id1/ (os .pak, a musica e os docs com as licencas)
python3 -I -c 'import sys, zipfile, os
z = zipfile.ZipFile(sys.argv[1])
for n in z.namelist():
    if n.startswith("lite/id1/") and not n.endswith("/"):
        d = os.path.join(sys.argv[2], n[len("lite/"):])
        os.makedirs(os.path.dirname(d), exist_ok=True)
        open(d, "wb").write(z.read(n))' "$REPO/.cache/emu/conteudo/librequake/lite.zip" "$G/jogos/librequake"
# Quake nativo (spec 050): o TyrQuake original, o config.cfg inicial (botoes) e o mapeamento de game controller do
# i2c-keys (o mesmo do Duke: os mesmos botoes fisicos, KB 11k)
cp "$OUT/tyrquake_sdl/tyr-quake" "$REPO/ports/config/tyrquake/config.cfg" "$G/jogos/tyrquake/"
python3 "$REPO/ports/gerar_gamecontrollerdb.py" --controle "$REPO/ports/config/duke3d_controle.json" \
    --saida "$G/jogos/tyrquake/gamecontrollerdb.txt"
# NetHack (spec 036): o jogo inteiro vem no pacote (NGPL); o lancar.sh monta a pasta do jogo em saves/jogos/nethack
cp "$OUT/nethack/nethack" "$OUT/nethack/recover" "$OUT/nethack/nhdat" "$OUT/nethack/license" "$OUT/nethack/symbols" \
    "$REPO/ports/nethack_m17/nethackrc" "$REPO/ports/nethack_m17/sysconf" "$G/jogos/nethack/"
cp "$REPO/ports/nethack_m17/LEIA-ME-jogo.txt" "$G/jogos/nethack/LEIA-ME.txt"
# Dink Smallwood (spec 047): o motor, a fonte dos dialogos (LiberationSans 1.05, do fonte do FreeDink) e os dados
# livres do Dink (o dink/ do freedink-data, inteiro); os D-Mods sao do jogador (roms/jogos/dink/, cada pasta um jogo)
cp "$OUT/freedink/freedink" "$OUT/freedink/LiberationSans-Regular.ttf" "$G/jogos/dink/"
tar -xzf "$REPO/.cache/emu/conteudo/freedink_data/freedink-data-1.08.20190120.tar.gz" -C "$G/jogos/dink" \
    --strip-components=1 freedink-data-1.08.20190120/dink
[ -f "$G/jogos/dink/dink/Dink.dat" ] || { echo "ERRO: dados do Dink (freedink-data)" >&2; exit 1; }
# a musica MIDI (spec 047, D-10): o FreePats inteiro (os instrumentos, o crude.cfg da escolha do mantenedor, o
# freepats.cfg, o README com a licenca e o COPYING); o tarball do Debian traz o do upstream dentro
tar -xzf "$REPO/.cache/emu/conteudo/freepats/freepats_20060219.orig.tar.gz" -O \
    freepats-20060219/upstream/freepats-20060219.tar.bz2 | tar -xjf - -C "$G/midi/freepats" --strip-components=1
[ -f "$G/midi/freepats/crude.cfg" ] && [ -d "$G/midi/freepats/Tone_000" ] || { echo "ERRO: FreePats" >&2; exit 1; }
cp "$OUT/sdl2_ttf/libSDL2_ttf-2.0.so.0" "$OUT/sdl2_gfx/libSDL2_gfx-1.0.so.0" "$G/lib/"

# ---------------------------------------------------------------- exemplos: id desta montagem
# spec 024 (D-07): o boot copia os temas de exemplo para home/temas/ so quando o .pacote muda
echo "$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo semgit)-$(date +%Y%m%d%H%M%S)" > "$G/exemplos/.pacote"

# ---------------------------------------------------------------- licencas
L="$G/LICENCAS"
cp "$REPO/LICENSE" "$L/tutu8bits-MIT.txt"
cp "$FONTES/retroarch/COPYING" "$L/RetroArch-GPL-3.0.txt"
cp "$FONTES/sdl2_projeto/LICENSE.txt" "$L/SDL2-Zlib.txt"
cp "$TUTU/temas/padrao/fontes/OFL-AtkinsonHyperlegible.txt" "$TUTU/temas/padrao/fontes/OFL-PressStart2P.txt" "$L/"
lic() { [ -f "$FONTES/$1/$2" ] && cp "$FONTES/$1/$2" "$L/$3" || { echo "ERRO: licenca de $1 ($2)" >&2; exit 1; }; }
lic pcsx_rearmed COPYING pcsx_rearmed-GPL-2.0.txt
lic gpsp COPYING gpsp-GPL-2.0.txt
lic mgba LICENSE mgba-MPL-2.0.txt
lic snes9x2005_plus copyright snes9x2005_plus-nao-comercial.txt
lic snes9x LICENSE snes9x-nao-comercial.txt
lic picodrive COPYING picodrive-nao-comercial.txt
lic fceumm Copying fceumm-GPL-2.0.txt
lic gambatte COPYING gambatte-GPL-2.0.txt
lic stella2014 stella/license.txt stella2014-GPL-2.0.txt
lic a5200 License.txt a5200-GPL-2.0.txt
lic prosystem License.txt prosystem-GPL-2.0.txt
lic handy lynx/license.txt handy-Zlib.txt
lic mednafen_pce_fast COPYING mednafen_pce_fast-GPL-2.0.txt
lic race license.txt race-GPL-2.0.txt
lic mednafen_ngp COPYING mednafen_ngp-GPL-2.0.txt
lic mame2003_plus LICENSE.md mame2003_plus-nao-comercial.md
lic fbneo src/license.txt fbneo-nao-comercial.txt
lic fake08 LICENSE.MD fake08-MIT.md
lic gametank LICENSE gametank-MIT.txt
lic gametank src/imgui/LICENSE.txt gametank-imgui-MIT.txt
lic gametank src/mos6502/LICENSE.txt gametank-mos6502-MIT.txt
lic ppsspp LICENSE.TXT ppsspp-GPL-2.0.txt
lic ppsspp ffmpeg/COPYING.LGPLv2.1 ffmpeg-LGPL-2.1.txt
lic nxengine LICENSE NXEngine-evo-GPL-3.0.txt
lic sdl2_mixer LICENSE.txt SDL2_mixer-Zlib.txt
lic sdl2_image LICENSE.txt SDL2_image-Zlib.txt
lic sdl2_mixer src/codecs/timidity/COPYING Timidity-Artistic.txt
lic sdl2_ttf LICENSE.txt SDL2_ttf-Zlib.txt
lic sdl2_ttf external/freetype/docs/FTL.TXT FreeType-FTL.txt
lic sdl2_gfx COPYING SDL2_gfx-Zlib.txt
lic freedink COPYING FreeDink-GPL-3.0.txt
lic freedink share/README.fonts LiberationSans-1.05-GPL-2.0-excecoes.txt
for _fd in COPYING README.txt README-REPLACEMENTS.txt; do
    tar -xzf "$REPO/.cache/emu/conteudo/freedink_data/freedink-data-1.08.20190120.tar.gz" -O "freedink-data-1.08.20190120/$_fd" \
        > "$L/freedink-data-$_fd" || { echo "ERRO: licenca do freedink-data ($_fd)" >&2; exit 1; }
done
cp "$G/midi/freepats/README" "$L/FreePats-GPL-2.0-README.txt"
cp "$G/midi/freepats/COPYING" "$L/FreePats-GPL-2.0.txt"
lic crispy_doom COPYING.md Crispy-Doom-GPL-2.0.md
lic opentyrian COPYING OpenTyrian-GPL-2.0.txt
lic rogue LICENSE.TXT Rogue-BSD.txt
lic nethack dat/license NetHack-NGPL.txt
lic wolf4sdl license-gpl.txt Wolf4SDL-GPL-2.0.txt
lic jfduke3d GPL.TXT JFDuke3D-GPL-2.0.txt
lic tyrquake_sdl gnu.txt TyrQuake-GPL-2.0.txt
cp "$G/jogos/librequake/id1/docs/COPYING" "$L/LibreQuake-BSD-3.txt"
lic jfduke3d jfbuild/buildlic.txt Build-licenca-Ken-Silverman.txt
lic wolf4sdl license-id.txt Wolf4SDL-licenca-id.txt
lic wolf4sdl license-mame.txt Wolf4SDL-OPL-MAME-nao-comercial.txt
# spec 053 (D-07): o parallel_n64 e as bibliotecas embutidas no NXEngine e no GameTank. Quando o texto so existe no
# cabecalho do fonte, cab() recorta o trecho (por padrao de linha, nao por numero) e falha se sair vazio.
cab() {   # destino comp arquivo sed-expr [linha extra antes]
    { [ -n "${5:-}" ] && printf '%s\n\n' "$5"; sed -n "$4" "$FONTES/$2/$3"; } > "$L/$1"
    grep -q '[[:alnum:]]' "$L/$1" && [ "$(wc -l < "$L/$1")" -ge 3 ] || { echo "ERRO: licenca de $2 ($3) vazia" >&2; exit 1; }
}
MIT_CORPO=$(sed -n '/^Permission is hereby granted/,$p' "$REPO/LICENSE")
lic parallel_n64 mupen64plus-video-gliden64/src/GLideNHQ/gpl-2.0.txt parallel_n64-GPL-2.0.txt
lic parallel_n64 mupen64plus-core/LICENSES parallel_n64-mupen64plus-core-LICENSES.txt
lic parallel_n64 mupen64plus-rsp-hle/LICENSES parallel_n64-rsp-hle-LICENSES.txt
lic parallel_n64 mupen64plus-rsp-cxd4/COPYING parallel_n64-rsp-cxd4-CC0.txt
lic parallel_n64 gles2n64/src/COPYING parallel_n64-gles2n64-COPYING.txt
cp "$REPO/ports/licencas/angrylion-MAME.txt" "$L/parallel_n64-angrylion-MAME-nao-comercial.txt"
cab parallel_n64-angrylion-cen64-BSD-3.txt parallel_n64 mupen64plus-video-angrylion/n64video/rdp/dps.c \
    '/Copyright (c) 2015, Tyler/,/POSSIBILITY OF SUCH DAMAGE\./{s/^ \* \{0,1\}//;p}' \
    "cen64 (trechos em mupen64plus-video-angrylion/n64video/rdp/dps.c e fill_tri.c do parallel-n64), BSD-3:"
cab NXEngine-nlohmann-json-MIT.txt nxengine deps/json.hpp '/^Licensed under the MIT License/,/^\*\//{/^\*\//d;p}' \
    "nlohmann/json, embutido no NXEngine-evo (deps/json.hpp):"
lic nxengine deps/spdlog/fmt/bundled/LICENSE.rst NXEngine-fmt-BSD-2.rst
cab NXEngine-spdlog-MIT.txt nxengine deps/spdlog/spdlog.h '/^\/\/ Copyright/{s/^\/\/ //;p}' \
    "spdlog, embutido no NXEngine-evo (deps/spdlog/); a licenca MIT citada no cabecalho:"
printf '\n%s\n' "$MIT_CORPO" >> "$L/NXEngine-spdlog-MIT.txt"
cab NXEngine-utfcpp-Boost-1.0.txt nxengine deps/utf8.h '1,/^\*\//{/^\/\*$/d;/^\*\//d;s/^\/\/ //;p}' \
    "utfcpp, embutido no NXEngine-evo (deps/utf8.h, deps/utf8/), Boost Software License 1.0:"
cab gametank-tomlplusplus-MIT.txt gametank src/toml/toml.hpp '/^\/\/ MIT License/,/OTHER DEALINGS IN THE SOFTWARE\./{s/^\/\/ \{0,1\}//;p}' \
    "toml++, embutido no GameTank Emulator (src/toml/toml.hpp):"
cab gametank-tinyfiledialogs-Zlib.txt gametank src/tinyfd/tinyfiledialogs.h '/Copyright (c) 2014/{s/^ *| dialogs | //;p};/^- License -/,/^3\. This notice/p' \
    "tinyfiledialogs, embutido no GameTank Emulator (src/tinyfd/):"
cab gametank-whereami-MIT.txt gametank src/whereami/whereami.h '1,4{s/^\/\/ \{0,1\}//;p}' \
    "whereami, embutido no GameTank Emulator (src/whereami/), dual WTFPL v2 / MIT; vale aqui a MIT:"
printf '\nCopyright (c) Gregory Pakosz\n\n%s\n' "$MIT_CORPO" >> "$L/gametank-whereami-MIT.txt"
lic gametank src/imgui/ext/implot/LICENSE gametank-implot-MIT.txt
printf '%s\n' "misc-fixed 6x10 (xorg/font/misc-misc, 6x10.bdf), a fonte da tela do Rogue (spec 035):" \
    "COPYRIGHT \"Public domain terminal emulator font.  Share and enjoy.\"" > "$L/misc-fixed-6x10-dominio-publico.txt"
cp "$G/jogos/freedoom/COPYING.txt" "$L/Freedoom-BSD.txt"
cp "$G/jogos/blasphemer/COPYING.md" "$L/Blasphemer-BSD.md"
LUAV=$(awk -F'|' '$1=="lua" {print $4}' "$REPO/src/emu/versoes.txt")
sed -n '/^\* Copyright (C) 1994/,/^\*\*\*\*/p' "$REPO/.cache/motor/lua-$LUAV/src/lua.h" > "$L/Lua-MIT.txt"
sed -n '/^This software is available under 2 licenses/,$p' "$REPO/.cache/motor/stb/stb_image.h" > "$L/stb-MIT-ou-dominio-publico.txt"
cat > "$L/LEIA-ME.md" <<EOF
# Licenças do tutu8bits $VERSAO

- **tutu8bits** (motor, frontend, temas, scripts): MIT — \`tutu8bits-MIT.txt\`. Exceção: os patches de
  \`ports/patches/\` e as interfaces que o projeto compila dentro de um programa de terceiros (como a
  \`ports/nethack_m17/\`, dentro do NetHack) seguem a licença do programa onde entram.
- **Código-fonte:** o do tutu8bits está em $TUTU_REPOSITORIO; as versões fixadas (\`ports/versoes.txt\`), as
  receitas e os patches dos emuladores e ports, em $PORTS_REPOSITORIO (a licença de cada patch: \`ports/patches/LEIA-ME.md\`).
  Estes binários foram compilados a partir do fonte de cada projeto. **Quem distribuir este pacote** precisa oferecer o
  fonte correspondente (a GPL, a licença do MAME 2003-Plus e do angrylion, a do PicoDrive e a do FBNeo pedem):
  \`ports/fontes.sh\` gera um arquivo por componente, na versão exata, com os patches à parte.
- **GPL** (RetroArch, pcsx_rearmed, gpsp, fceumm, gambatte, stella2014, a5200, prosystem, Beetle PCE Fast, RACE, Beetle NeoPop, parallel-n64, PPSSPP, NXEngine-evo, Crispy Doom, OpenTyrian, Wolf4SDL, JFDuke3D, TyrQuake, GNU FreeDink, FreePats): o fonte está onde diz o item acima.
- **Não comercial** (snes9x, snes9x2005_plus, picodrive, mame2003_plus, fbneo, o angrylion no parallel-n64, o OPL do MAME no Wolf4SDL, o motor Build no JFDuke3D): este pacote é gratuito e
  **não pode ser vendido**, nem vir junto com aparelho vendido. Veja "Restrições e riscos" no fim.
- **parallel-n64** (GPL-2, \`parallel_n64-GPL-2.0.txt\`), o núcleo do N64: o mupen64plus-core e o RSP HLE (GPL-2,
  \`parallel_n64-mupen64plus-core-LICENSES.txt\`, \`parallel_n64-rsp-hle-LICENSES.txt\`), os plugins de vídeo gln64,
  Glide64 e Rice (GPL-2, \`parallel_n64-gles2n64-COPYING.txt\`), o RSP cxd4 (CC0, \`parallel_n64-rsp-cxd4-CC0.txt\`) e
  o renderizador **angrylion** (licença não comercial do MAME, \`parallel_n64-angrylion-MAME-nao-comercial.txt\`, com
  trechos do cen64 em BSD-3, \`parallel_n64-angrylion-cen64-BSD-3.txt\`).
- **Handy** (Zlib, \`handy-Zlib.txt\`), o núcleo do Atari Lynx.
- **SDL2** (Zlib), com o backend de vídeo "mali" da comunidade (Zlib; patch do gist
  Mercotui/c58b0da9f194e41e3dc24a99f84879b9, para o SDL 2.30.6) adaptado pelo projeto; **SDL2_mixer** e
  **SDL2_image** (Zlib), com o stb_vorbis e o stb_image embutidos (MIT ou domínio público).
- **NXEngine-evo** (GPL-3.0), o motor do Cave Story, com **nlohmann/json** (MIT), **spdlog** e **fmt** (MIT) e
  **utfcpp** (Boost 1.0) embutidos (\`NXEngine-nlohmann-json-MIT.txt\`, \`NXEngine-spdlog-MIT.txt\`,
  \`NXEngine-fmt-BSD-2.rst\`, \`NXEngine-utfcpp-Boost-1.0.txt\`). O **jogo** (Studio Pixel, freeware) não vem no pacote: o
  jogador baixa e copia para \`roms/jogos/cavestory/\` (ver o LEIA-ME.txt de lá).
- **Crispy Doom** (GPL-2.0), o motor do Doom, e do mesmo projeto o **Crispy Heretic**, o **Crispy Strife** e o
  **Crispy Hexen**.
  **Freedoom** (BSD, \`Freedoom-BSD.txt\`): os dois jogos que vêm no pacote (\`tutu8bits/jogos/freedoom/\`).
  **Blasphemer** (BSD, \`Blasphemer-BSD.md\`): um Heretic livre que vem no pacote (\`tutu8bits/jogos/blasphemer/\`). O
  Doom, o Heretic, o Strife e o Hexen originais não vêm: quem tiver copia o WAD para \`roms/jogos/doom/\`,
  \`roms/jogos/heretic/\`, \`roms/jogos/strife/\` ou \`roms/jogos/hexen/\`.
- **Rogue 5.4.4** (BSD, \`Rogue-BSD.txt\`; Toy, Arnold e Wichman, com partes de N. J. Kisseberth), inteiro no pacote
  (\`tutu8bits/jogos/rogue/\`), com a tela e o controle do projeto; a fonte da tela é a **misc-fixed 6×10** (domínio
  público, "Public domain terminal emulator font. Share and enjoy.").
- **NetHack 3.6.7** (NetHack General Public License, \`NetHack-NGPL.txt\`; DevTeam), inteiro no pacote
  (\`tutu8bits/jogos/nethack/\`), com a interface, o controle e o teclado virtual do projeto (o fonte e os patches estão
  no repositório, como os dos programas GPL).
- **Wolf4SDL** (o código do Wolfenstein 3D da id, à escolha GPL-2.0 \`Wolf4SDL-GPL-2.0.txt\` ou a licença da id
  \`Wolf4SDL-licenca-id.txt\`; a música pelo OPL do MAME, não comercial, \`Wolf4SDL-OPL-MAME-nao-comercial.txt\`), o motor
  do Wolfenstein 3D. O **Wolfenstein 3D shareware 1.4** (id Software / Apogee) vem no pacote inteiro e sem mudança, como
  pedem o \`READ1ST.TXT\` e o \`VENDOR.DOC\` dele (\`tutu8bits/jogos/wolf3d/\`); o jogo completo e o Spear of Destiny
  não vêm.
- **JFDuke3D** (GPL-2.0, \`JFDuke3D-GPL-2.0.txt\`; Jonathon Fowler e outros) sobre o motor **Build** do Ken Silverman
  (licença própria, \`Build-licenca-Ken-Silverman.txt\`: uso e distribuição gratuitos, sem exploração comercial), o motor
  do Duke Nukem 3D. O **Duke Nukem 3D shareware 1.3d** (3D Realms) vem no pacote inteiro e sem mudança, como pede o
  \`LICENSE.TXT\` dele (\`tutu8bits/jogos/duke3d/\`); o jogo completo não vem.
- **TyrQuake original** (GPL-2.0, \`TyrQuake-GPL-2.0.txt\`), o motor do Quake (\`tutu8bits/jogos/tyrquake/\`, spec
  050), com os patches do projeto. A música usa os decodificadores que vêm na fonte dele (stb_vorbis, dr_mp3, dr_flac e
  dr_wav, domínio público ou MIT-0). O **LibreQuake** (BSD-3 nos modelos, texturas e sons, \`LibreQuake-BSD-3.txt\`;
  GPL-2 no QuakeC — licenças em \`tutu8bits/jogos/librequake/id1/docs/\`) vem no pacote. O Quake (e o shareware) não
  vêm.
- **GNU FreeDink 109.6** (GPL-3.0+, \`FreeDink-GPL-3.0.txt\`), o motor do Dink Smallwood, com os patches do projeto. Os
  **dados do Dink** (\`freedink-data\` 1.08: os originais da RTsoft numa licença no estilo zlib, \`freedink-data-README.txt\`;
  os sons trocados por livres com as licenças de \`freedink-data-README-REPLACEMENTS.txt\`) vêm no pacote
  (\`tutu8bits/jogos/dink/\`). A fonte dos diálogos é a **Liberation Sans 1.05** (GPL-2.0 com as exceções da Red Hat,
  \`LiberationSans-1.05-GPL-2.0-excecoes.txt\`). Os **D-Mods** não vêm: cada um tem a licença do autor, e o jogador
  copia para \`roms/jogos/dink/\` (ver o LEIA-ME.txt de lá). Bibliotecas: **SDL2_ttf** (Zlib) com o **FreeType**
  (FreeType License, \`FreeType-FTL.txt\`; FreeType 2.12.1: "Portions of this software are copyright © 2022 The
  FreeType Project (www.freetype.org). All rights reserved.") e **SDL2_gfx** (Zlib).
- **Música MIDI**: o **Timidity** embutido na SDL2_mixer (Perl Artistic License, \`Timidity-Artistic.txt\`) com os
  instrumentos do **FreePats** (GPL-2.0 ou posterior, com a exceção para composições, \`FreePats-GPL-2.0-README.txt\`;
  \`tutu8bits/midi/freepats/\`).
- **OpenTyrian** (GPL-2.0), o motor do Tyrian. O **jogo** (Tyrian 2.1, freeware) não vem no pacote: o jogador
  baixa e copia para \`roms/jogos/tyrian/\` (ver o LEIA-ME.txt de lá).
- **Lua** (MIT), **stb_image / stb_truetype** (MIT ou domínio público), **mGBA** (MPL-2.0), **FAKE-08** (MIT).
- **FFmpeg** (LGPL-2.1, sem partes GPL), mínimo, embutido no PPSSPP; o fonte é o submódulo \`ffmpeg/\` do PPSSPP
  e a configuração está em \`ports/receitas/_ffmpeg_ppsspp.sh\`.
- **GameTank Emulator** (MIT), com **Dear ImGui** (MIT), **ImPlot** (MIT), **mos6502** (MIT), **toml++** (MIT),
  **tinyfiledialogs** (zlib) e **whereami** (MIT ou WTFPL) embutidos (\`gametank-*.txt\`).
- **Fontes**: Atkinson Hyperlegible e Press Start 2P (SIL Open Font License 1.1).
- Nada do sistema de fábrica do aparelho vai neste pacote, nem ROMs ou BIOS; dos jogos comerciais, só os shareware citados acima.

## Restrições e riscos

- **Gratuito, não pode ser vendido** nem vir junto com aparelho vendido: snes9x, snes9x2005_plus, picodrive,
  mame2003_plus, fbneo, o angrylion, o OPL do MAME e o motor Build são de licença não comercial.
- **Sem pedido de doação:** a licença do FBNeo proíbe pedir doações em projeto que use o código dele.
- **Wolf4SDL:** com o OPL do MAME (não comercial) dentro, vale a licença da id (\`Wolf4SDL-licenca-id.txt\`), não a GPL.
- **JFDuke3D e parallel-n64:** o código GPL-2 deles vai linkado com código de licença não comercial (o motor Build no
  JFDuke3D, o angrylion no parallel-n64). É assim que os próprios projetos distribuem; as duas licenças estão aqui, e o
  pacote segue gratuito.
EOF
# ---------------------------------------------------------------- para o cartao/
for d in cores gametank ppsspp jogos midi LICENCAS; do
    rsync -r -c -p --delete "$G/$d/" "$TUTU/$d/"
done
mkdir -p "$TUTU/retroarch"
rsync -c -p "$G/retroarch/retroarch" "$G/retroarch/retroarch.cfg.modelo" "$TUTU/retroarch/"
rsync -c -p "$G/exemplos/.pacote" "$TUTU/exemplos/.pacote"
# lib/ tem tambem a libSDL2 (do build do motor): sem --delete
rsync -c -p "$G/lib/libSDL2_mixer-2.0.so.0" "$G/lib/libSDL2_image-2.0.so.0" "$G/lib/libSDL2_ttf-2.0.so.0" \
    "$G/lib/libSDL2_gfx-1.0.so.0" "$TUTU/lib/"
echo "  ok  cartao/ completo (tutu8bits $VERSAO)"
