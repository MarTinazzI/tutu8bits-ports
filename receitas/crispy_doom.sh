# Doom (spec 031, plano D-01/D-02): o Crispy Doom, programa proprio com SDL2 (C, GPL-2.0). Desenha por software
# e mostra pelo renderer do SDL2 (textura alvo): no aparelho, a libSDL2 do projeto (mali + GLES2). Som pela
# SDL2_mixer do projeto (030); musica pelo OPL embutido. Sem SDL2_net, libsamplerate, libpng e FluidSynth.
# Compila os alvos crispy-doom, crispy-heretic e crispy-strife (spec 033, D-01: o mesmo fonte e o mesmo build) e o
# crispy-hexen (spec 038, D-01); o setup fica de fora.
# SDL_config.h configurado do sdl2_projeto por -include (spec 038, D-02; B-50): sem ele o SDL_stdinc.h nao inclui os
# cabecalhos da libc e funcoes ficam implicitas (o pow da tabela de gama saia errado); a receita falha se sobrar alguma.
RECEITA_OPCOES="cmake -DENABLE_SDL2_NET=OFF -DENABLE_SDL2_MIXER=ON -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=OFF -DCMAKE_DISABLE_FIND_PACKAGE_SampleRate=ON -DCMAKE_DISABLE_FIND_PACKAGE_PNG=ON -DCMAKE_DISABLE_FIND_PACKAGE_FluidSynth=ON -DCMAKE_BUILD_TYPE=Release; alvos crispy-doom crispy-heretic crispy-strife crispy-hexen; SDL_config.h do sdl2_projeto; CFLAGS -DM17; teclado virtual (teclado_m17)"

receita_compilar() {
    local ld="$PWD/build-m17/libs"
    local sdlcfg="$SRC/sdl2_projeto/build-m17/include-config-release/SDL2/SDL_config.h"
    [ -f "$sdlcfg" ] || { echo "falta $sdlcfg (rode build.sh sdl2_projeto)"; return 1; }
    rm -rf build-m17; mkdir -p "$ld"
    # spec 042 (D-13): o teclado virtual da spec 036 e a fonte dele, no src/ (o patch 05 os poe no CMakeLists)
    local bdf="$EMU_CACHE/conteudo/fonte6x10/6x10.bdf"
    [ -f "$bdf" ] || { echo "falta $bdf (rode ports/baixar_conteudo.sh fonte6x10)"; return 1; }
    cp "$EMU_RAIZ"/src/emu/teclado_m17/teclado.c "$EMU_RAIZ"/src/emu/teclado_m17/teclado_sdl.c \
       "$EMU_RAIZ"/src/emu/teclado_m17/teclado.h src/ || return 1
    python3 -I "$EMU_RAIZ/ports/rogue_m17/bdf_para_h.py" "$bdf" src/m17_fonte.h || return 1
    ln -s "$OUT/sdl2_mixer/libSDL2_mixer-2.0.so.0" "$ld/libSDL2_mixer.so" || return 1
    # SDL2main: o CMake do Crispy liga sempre; no Linux ela nao troca o main (SDL_MAIN_NEEDED nao vale aqui),
    # entao uma biblioteca vazia basta (a nossa SDL2 nao gera a libSDL2main.a)
    echo 'void m17_sdl2main_vazio(void) {}' > "$ld/sdl2main.c"
    "$CC" $CFLAGS -c "$ld/sdl2main.c" -o "$ld/sdl2main.o" && "${CC%gcc}ar" rcs "$ld/libSDL2main.a" "$ld/sdl2main.o" || return 1
    cmake -S . -B build-m17 -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=arm \
        -DCMAKE_C_COMPILER="$CC" -DCMAKE_C_FLAGS="$CFLAGS -DM17 -I$EMU_INC/SDL2 -include $sdlcfg" \
        -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
        -DCMAKE_FIND_ROOT_PATH="$EMU_TC/$EMU_HOST/sysroot" \
        -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
        -DPKG_CONFIG_EXECUTABLE=/bin/false \
        -DENABLE_SDL2_NET=OFF -DENABLE_SDL2_MIXER=ON -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=OFF \
        -DCMAKE_DISABLE_FIND_PACKAGE_SampleRate=ON -DCMAKE_DISABLE_FIND_PACKAGE_PNG=ON \
        -DCMAKE_DISABLE_FIND_PACKAGE_FluidSynth=ON \
        -DSDL2_INCLUDE_DIR="$EMU_INC/SDL2" -DSDL2_LIBRARY="$EMU_LIB_CARTAO/libSDL2.so" -DSDL2_MAIN_LIBRARY="$ld/libSDL2main.a" \
        -DSDL2_MIXER_INCLUDE_DIR="$SRC/sdl2_mixer/include" -DSDL2_MIXER_LIBRARY="$ld/libSDL2_mixer.so" || return 1
    if grep -E '(_LIBRARY|_LIB|_INCLUDE_DIR)[A-Z_]*:[A-Z]+=/usr/' build-m17/CMakeCache.txt; then return 1; fi
    # opcionais desligados de verdade (config.h gerado)
    if grep -E '#define HAVE_(LIBPNG|LIBSAMPLERATE|FLUIDSYNTH) 1' build-m17/config.h; then return 1; fi
    cmake --build build-m17 --target crispy-doom crispy-heretic crispy-strife crispy-hexen -j"$NPROC" \
        > build-m17/compilar.log 2>&1 || { tail -30 build-m17/compilar.log; return 1; }
    # nenhuma funcao sem declaracao (B-50)
    if grep 'implicit declaration' build-m17/compilar.log; then return 1; fi
}

receita_instalar() {
    rm -rf "$OUT/crispy_doom"; mkdir -p "$OUT/crispy_doom"
    local b
    for b in crispy-doom crispy-heretic crispy-strife crispy-hexen; do
        "$STRIP" -o "$OUT/crispy_doom/$b" "build-m17/src/$b" || return 1
    done
}
