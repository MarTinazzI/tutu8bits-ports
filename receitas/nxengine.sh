# Cave Story (spec 030, plano D-01..D-05): o NXEngine-evo, programa proprio com SDL2 (C++11, GPL-3.0).
# Desenha so pelo renderer do SDL2 (sem OpenGL de PC): no aparelho, a libSDL2 do projeto (mali + GLES2),
# como o GameTank. Som e imagem pela SDL2_mixer e SDL2_image do projeto (receitas sdl2_mixer/sdl2_image,
# compiladas antes); a libpng16 (capturas, pngfuncs.cpp) e a da NAND, com os cabecalhos fixados em
# include/libpng16. Sem JPEG (patch nxengine-m17-03).
# PORTABLE: o motor procura o data/ dele ao lado do binario (sem -DPORTABLE o fonte da tag procura em
# ../share/nxengine/data/, ResourceManager.cpp), por isso -DPORTABLE vai tambem nas flags.
# Gera nx (o jogo) e extract (tira do Doukutsu.exe os dados que o freeware nao traz soltos); instala os
# dois e o data/ do motor em nxengine/.
RECEITA_OPCOES="cmake -DPLATFORM=pc -DPORTABLE=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 (o CMakeLists pede 3.0); CXXFLAGS -DPORTABLE -DM17"

receita_compilar() {
    local ld="$PWD/build-m17/libs"
    rm -rf build-m17; mkdir -p "$ld"
    # as duas libs do projeto, com o nome que o ligador procura (o soname continua o de runtime)
    ln -s "$OUT/sdl2_mixer/libSDL2_mixer-2.0.so.0" "$ld/libSDL2_mixer.so" || return 1
    ln -s "$OUT/sdl2_image/libSDL2_image-2.0.so.0" "$ld/libSDL2_image.so" || return 1
    cmake -S . -B build-m17 -G Ninja -DCMAKE_BUILD_TYPE=Release -DPLATFORM=pc -DPORTABLE=ON -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=arm \
        -DCMAKE_CXX_COMPILER="$CXX" -DCMAKE_CXX_FLAGS="$CXXFLAGS -DPORTABLE -DM17" \
        -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
        -DCMAKE_FIND_ROOT_PATH="$EMU_TC/$EMU_HOST/sysroot" \
        -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
        -DPKG_CONFIG_EXECUTABLE=/bin/false \
        -DSDL2_INCLUDE_DIR="$EMU_INC/SDL2" -DSDL2_LIBRARY="$EMU_LIB_CARTAO/libSDL2.so" \
        -DSDL2_MIXER_INCLUDE_DIR="$SRC/sdl2_mixer/include" -DSDL2_MIXER_LIBRARY="$ld/libSDL2_mixer.so" \
        -DSDL2_IMAGE_INCLUDE_DIR="$SRC/sdl2_image/include" -DSDL2_IMAGE_LIBRARY="$ld/libSDL2_image.so" \
        -DPNG_PNG_INCLUDE_DIR="$EMU_INC/libpng16" -DPNG_LIBRARY="$EMU_ROOTFS/usr/lib/libpng16.so" \
        -DZLIB_INCLUDE_DIR="$EMU_INC" -DZLIB_LIBRARY="$EMU_ROOTFS/usr/lib/libz.so" || return 1
    # nenhuma biblioteca ou cabecalho achado no PC; dados ao lado do binario (sem DATADIR fixo)
    if grep -E '(_LIBRARY|_LIB|_INCLUDE_DIR)[A-Z_]*:[A-Z]+=/usr/' build-m17/CMakeCache.txt; then return 1; fi
    if grep -rq 'DDATADIR' build-m17/build.ninja; then return 1; fi
    cmake --build build-m17 -j"$NPROC" || return 1
}

receita_instalar() {
    rm -rf "$OUT/nxengine"; mkdir -p "$OUT/nxengine"
    "$STRIP" -o "$OUT/nxengine/nx" build-m17/nxengine-evo
    "$STRIP" -o "$OUT/nxengine/extract" build-m17/nxextract
    cp -r data "$OUT/nxengine/data"
}
