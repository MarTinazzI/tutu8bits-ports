# GNU FreeDink 109.6 (spec 047, plano D-02): o motor do Dink Smallwood e dos D-Mods, C++ com SDL2 (GPL-3.0+). Fonte
# de release em tarball (traz o configure pronto; build.sh, obter_tarball). Liga contra a libSDL2 do projeto e as
# SDL2_mixer (WAV, Ogg, MIDI pelo Timidity), SDL2_image (BMP, PNG, XPM), SDL2_ttf e SDL2_gfx do projeto (compiladas
# antes), e os cabecalhos da glm 0.9.9.8 (baixar_conteudo.sh glm). So o jogo (sem o editor freedinkedit).
# -D_FILE_OFFSET_BITS=64: sem ele o readdir de 32 bits falha no qemu sobre o ext4 e o motor nao acha os arquivos
# (spike). -DM17 liga os patches freedink-m17-*. A roda de opcoes (src/emu/roda_m17/, spec 048; patch 04) entra como
# uma biblioteca estatica (libm17roda.a, com a fonte 6x10 Latin-1 de baixar_conteudo.sh fonte6x10). Instala o freedink
# e a LiberationSans 1.05 (share/freedink/; GPL-2.0 com as excecoes da Red Hat, share/README.fonts) em freedink/.
RECEITA_OPCOES="configure --host=$EMU_HOST --disable-tests; CFLAGS/CXXFLAGS -D_FILE_OFFSET_BITS=64 -DM17; sem fontconfig"

receita_compilar() {
    local b="$PWD/build-m17" glm="$EMU_CACHE/conteudo/glm/glm-0.9.9.8.tar.gz"
    local sdlcfg="$EMU_CACHE/src/sdl2_projeto/build-m17/include-config-release/SDL2/SDL_config.h"
    [ -f "$glm" ] || { echo "falta o glm: ports/baixar_conteudo.sh glm"; return 1; }
    mkdir -p "$b/inc/SDL2" "$b/lib" "$b/glm"
    tar -xzf "$glm" -C "$b/glm" --strip-components=1 || return 1
    # spec 047 (D-05): a roda (048), compilada em C pelo compilador do projeto, numa biblioteca estatica
    local bdf="$EMU_CACHE/conteudo/fonte6x10/6x10.bdf" r="$EMU_RAIZ/src/emu/roda_m17"
    [ -f "$bdf" ] || { echo "falta a fonte 6x10: ports/baixar_conteudo.sh fonte6x10"; return 1; }
    python3 -I "$EMU_RAIZ/ports/rogue_m17/bdf_para_h.py" --latin1 "$bdf" "$b/inc/m17_fonte_latin1.h" || return 1
    "$CC" $CFLAGS -std=gnu99 -Wall -Werror -include "$sdlcfg" -I"$EMU_INC/SDL2" -I"$r" -I"$b/inc" -D_REENTRANT \
        -c "$r/roda.c" -o "$b/roda.o" || return 1
    "$CC" $CFLAGS -std=gnu99 -Wall -Werror -include "$sdlcfg" -I"$EMU_INC/SDL2" -I"$r" -I"$b/inc" -D_REENTRANT \
        -c "$r/roda_sdl.c" -o "$b/roda_sdl.o" || return 1
    "$AR" rcs "$b/lib/libm17roda.a" "$b/roda.o" "$b/roda_sdl.o" || return 1
    # cabecalhos e bibliotecas do projeto, com os nomes que o ligador procura (o soname continua o de runtime)
    cp "$SRC/sdl2_mixer/include/SDL_mixer.h" "$SRC/sdl2_image/include/SDL_image.h" "$SRC/sdl2_ttf/SDL_ttf.h" \
        "$SRC"/sdl2_gfx/SDL2_framerate.h "$SRC"/sdl2_gfx/SDL2_gfxPrimitives.h "$SRC"/sdl2_gfx/SDL2_imageFilter.h \
        "$SRC"/sdl2_gfx/SDL2_rotozoom.h "$b/inc/SDL2/" || return 1
    ln -s "$EMU_LIB_CARTAO/libSDL2.so" "$b/lib/libSDL2.so"
    ln -s "$OUT/sdl2_mixer/libSDL2_mixer-2.0.so.0" "$b/lib/libSDL2_mixer.so"
    ln -s "$OUT/sdl2_image/libSDL2_image-2.0.so.0" "$b/lib/libSDL2_image.so"
    ln -s "$OUT/sdl2_ttf/libSDL2_ttf-2.0.so.0" "$b/lib/libSDL2_ttf.so"
    ln -s "$OUT/sdl2_gfx/libSDL2_gfx-1.0.so.0" "$b/lib/libSDL2_gfx.so"
    # sem "-include config.h" aqui: o configure poe o SDL2_CFLAGS nos testes dele antes de gerar o config.h, e cada
    # teste falharia (no spike, um config.h de uma rodada anterior escondia isso)
    export SDL2_CFLAGS="-include $sdlcfg -I$EMU_INC/SDL2 -I$b/inc/SDL2 -I$b/glm -I$r -D_REENTRANT"
    export SDL2_LIBS="-L$b/lib -lm17roda -lSDL2_image -lSDL2_mixer -lSDL2_ttf -lSDL2_gfx -lSDL2 -lm"
    ./configure --host="$EMU_HOST" --disable-tests --prefix=/usr \
        CC="$CC" CXX="$CXX" PKG_CONFIG=/bin/false \
        CFLAGS="$CFLAGS -D_FILE_OFFSET_BITS=64 -DM17" CXXFLAGS="$CXXFLAGS -D_FILE_OFFSET_BITS=64 -DM17" \
        LDFLAGS="$LDFLAGS -L$b/lib -Wl,-rpath-link=$b/lib:$EMU_LIB_CARTAO" || return 1
    make -j"$NPROC" -C gnulib/lib || return 1
    # alguns .cpp (ImageLoader.cpp) incluem os cabecalhos da gnulib sem o config.h antes ("Please include config.h
    # first"): o config.h vai pelo compilador, so no src/
    make -j"$NPROC" -C src freedink CXX="$CXX -include $PWD/config.h" || return 1
}

receita_instalar() {
    mkdir -p "$OUT/freedink"
    "$STRIP" -o "$OUT/freedink/freedink" src/freedink
    cp share/freedink/LiberationSans-Regular.ttf "$OUT/freedink/"
}
