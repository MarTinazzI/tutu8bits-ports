# SDL2_image do projeto (spec 030, plano D-02): para o NXEngine-evo, que exige PNG no IMG_Init
# (fontes e efeitos de luz). PNG pelo stb_image embutido (sem libpng); sem gravar PNG (o motor
# grava as capturas pela libpng, pngfuncs.cpp). Spec 047 (plano D-01): tambem BMP (os graficos do FreeDink)
# e XPM (o icone da janela dele), decodificadores proprios da SDL2_image. Nenhuma biblioteca externa. Ligada contra os
# cabecalhos fixados do SDL2 2.28.5 e o soname libSDL2-2.0.so.0, como a SDL2_mixer.
IMG_CMAKE="-DSDL2IMAGE_VENDORED=OFF -DSDL2IMAGE_SAMPLES=OFF -DSDL2IMAGE_TESTS=OFF -DSDL2IMAGE_INSTALL=OFF -DSDL2IMAGE_DEPS_SHARED=OFF -DSDL2IMAGE_STRICT=ON -DSDL2IMAGE_BACKEND_STB=ON -DSDL2IMAGE_PNG=ON -DSDL2IMAGE_PNG_SAVE=OFF -DSDL2IMAGE_AVIF=OFF -DSDL2IMAGE_BMP=ON -DSDL2IMAGE_GIF=OFF -DSDL2IMAGE_JPG=OFF -DSDL2IMAGE_JXL=OFF -DSDL2IMAGE_LBM=OFF -DSDL2IMAGE_PCX=OFF -DSDL2IMAGE_PNM=OFF -DSDL2IMAGE_QOI=OFF -DSDL2IMAGE_SVG=OFF -DSDL2IMAGE_TGA=OFF -DSDL2IMAGE_TIF=OFF -DSDL2IMAGE_WEBP=OFF -DSDL2IMAGE_XCF=OFF -DSDL2IMAGE_XPM=ON -DSDL2IMAGE_XV=OFF"
RECEITA_OPCOES="cmake $IMG_CMAKE"

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
        $IMG_CMAKE || return 1
    if grep -E '(_LIBRARY|_LIB|_INCLUDE_DIR)[A-Z_]*:[A-Z]+=/usr/' build-m17/CMakeCache.txt; then return 1; fi
    cmake --build build-m17 -j"$NPROC" || return 1
}

receita_instalar() {
    mkdir -p "$OUT/sdl2_image"
    "$STRIP" -o "$OUT/sdl2_image/libSDL2_image-2.0.so.0" build-m17/libSDL2_image-2.0.so.0.*
}
