# SDL2_ttf do projeto (spec 047, plano D-01): para o GNU FreeDink, que desenha o texto dos dialogos numa fonte TTF
# (a LiberationSans que vem no fonte do motor; tamanho 24, escolha do mantenedor). Freetype embutido (submodulo
# external/freetype, SDL2TTF_VENDORED), sem harfbuzz (o Dink so escreve Latin-1). Nenhuma biblioteca externa. Ligada
# contra os cabecalhos fixados do SDL2 2.28.5 e o soname libSDL2-2.0.so.0, como a SDL2_mixer e a SDL2_image.
# O CMake do freetype pede 3.5 como minimo de politica (CMAKE_POLICY_VERSION_MINIMUM), como no spike.
TTF_CMAKE="-DSDL2TTF_VENDORED=ON -DSDL2TTF_HARFBUZZ=OFF -DSDL2TTF_SAMPLES=OFF -DSDL2TTF_INSTALL=OFF -DBUILD_SHARED_LIBS=ON -DCMAKE_POLICY_VERSION_MINIMUM=3.5"
RECEITA_OPCOES="cmake $TTF_CMAKE"

receita_compilar() {
    rm -rf build-m17
    cmake -S . -B build-m17 -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=arm \
        -DCMAKE_C_COMPILER="$CC" -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS" \
        -DCMAKE_FIND_ROOT_PATH="$EMU_TC/$EMU_HOST/sysroot" \
        -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
        -DPKG_CONFIG_EXECUTABLE=/bin/false \
        -DSDL2_INCLUDE_DIR="$EMU_INC/SDL2" -DSDL2_LIBRARY="$EMU_LIB_CARTAO/libSDL2.so" \
        $TTF_CMAKE || return 1
    # nenhuma biblioteca ou cabecalho achado no PC
    if grep -E '(_LIBRARY|_LIB|_INCLUDE_DIR)[A-Z_]*:[A-Z]+=/usr/' build-m17/CMakeCache.txt; then return 1; fi
    cmake --build build-m17 -j"$NPROC" || return 1
}

receita_instalar() {
    mkdir -p "$OUT/sdl2_ttf"
    "$STRIP" -o "$OUT/sdl2_ttf/libSDL2_ttf-2.0.so.0" build-m17/libSDL2_ttf-2.0.so.0.*
}
