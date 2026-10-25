# Wolfenstein 3D (spec 037, plano D-01..D-03): o Wolf4SDL, programa proprio com SDL2 (C, renderer do SDL, joystick
# cru), SDL2_mixer do projeto. A versao dos dados e escolhida na compilacao (version.h com VERSIONALREADYCHOSEN):
# tres binarios — wolf3d (completo 1.4 GT/ID/Activision: CARMACIZED GOODTIMES), wolf3d-sw (shareware 1.4: CARMACIZED
# UPLOAD) e spear (Spear of Destiny e as missoes pelo --mission: CARMACIZED SPEAR GOODTIMES). Musica pelo OPL do MAME
# (o GPL=1, OPL do DOSBox, nao compila neste fonte: dbopl.h e C++ e o id_sd.c e C). O Makefile pede o sdl2-config:
# os caminhos vao direto (SDL_CONFIG=/bin/false). SDL_config.h configurado do sdl2_projeto por -include (B-50).
# O teclado virtual da spec 036 (src/emu/teclado_m17/) entra pelo patch wolf4sdl-m17-03 (nome do save e do placar).
RECEITA_OPCOES="make (OPL do MAME); 3 binarios: wolf3d (CARMACIZED GOODTIMES), wolf3d-sw (CARMACIZED UPLOAD), spear (CARMACIZED SPEAR GOODTIMES); SDL_config.h do sdl2_projeto; CFLAGS -DM17"

wolf_defs() {   # binario -> definicoes do version.h
    case "$1" in
        wolf3d)    echo "-DCARMACIZED -DGOODTIMES" ;;
        wolf3d-sw) echo "-DCARMACIZED -DUPLOAD" ;;
        spear)     echo "-DCARMACIZED -DSPEAR -DGOODTIMES" ;;
    esac
}

receita_compilar() {
    local sdlcfg="$SRC/sdl2_projeto/build-m17/include-config-release/SDL2/SDL_config.h"
    [ -f "$sdlcfg" ] || { echo "falta $sdlcfg (rode build.sh sdl2_projeto)"; return 1; }
    local ld="$PWD/build-m17/libs" v defs
    rm -rf build-m17; mkdir -p "$ld"
    ln -s "$OUT/sdl2_mixer/libSDL2_mixer-2.0.so.0" "$ld/libSDL2_mixer.so" || return 1
    # o teclado virtual (spec 036) e a fonte dele, junto do fonte do jogo
    local bdf="$EMU_CACHE/conteudo/fonte6x10/6x10.bdf"
    [ -f "$bdf" ] || { echo "falta $bdf (rode ports/baixar_conteudo.sh fonte6x10)"; return 1; }
    cp "$EMU_RAIZ"/src/emu/teclado_m17/teclado.c "$EMU_RAIZ"/src/emu/teclado_m17/teclado_sdl.c \
       "$EMU_RAIZ"/src/emu/teclado_m17/teclado.h . || return 1
    python3 -I "$EMU_RAIZ/ports/rogue_m17/bdf_para_h.py" "$bdf" m17_fonte.h || return 1
    for v in wolf3d wolf3d-sw spear; do
        defs=$(wolf_defs "$v")
        make clean > /dev/null 2>&1
        make -j"$NPROC" CC="$CC" CXX="$CXX" SDL_CONFIG=/bin/false M17_SRCS="teclado.c teclado_sdl.c" \
            CFLAGS_SDL="$CFLAGS -DM17 -DVERSIONALREADYCHOSEN $defs -include $sdlcfg -I$EMU_INC/SDL2 -I$SRC/sdl2_mixer/include -D_REENTRANT" \
            LDFLAGS_SDL="$LDFLAGS -L$EMU_LIB_CARTAO -L$ld -lSDL2" > "build-m17/$v.log" 2>&1 \
            || { tail -20 "build-m17/$v.log"; return 1; }
        if grep 'implicit declaration' "build-m17/$v.log"; then return 1; fi
        cp wolf4sdl "build-m17/$v" || return 1
        echo "$v: $defs" >> build-m17/variantes.txt
    done
}

receita_instalar() {
    rm -rf "$OUT/wolf4sdl"; mkdir -p "$OUT/wolf4sdl"
    local v
    for v in wolf3d wolf3d-sw spear; do
        "$STRIP" -o "$OUT/wolf4sdl/$v" "build-m17/$v" || return 1
    done
}
