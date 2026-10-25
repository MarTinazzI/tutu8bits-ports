# PSP (spec 010, plano D-01; spec 023, candidato A): nucleo libretro do PPSSPP, ARMv7 + NEON softfp,
# GLES2 (SGX540). Desde a 023 com o FFmpeg minimo do projeto (ports/receitas/_ffmpeg_ppsspp.sh,
# estatico): os videos MPEG/PMF passam a ter imagem e o ATRAC3+ pode usar o FFmpeg. O patch
# ppsspp-m17-01-fps grava a velocidade do jogo no log ("[M17] psp ..."). Sem Vulkan, X11, Wayland,
# Discord e UPnP.
. "$EMU_RAIZ/ports/receitas/_ffmpeg_ppsspp.sh"
RECEITA_OPCOES="-DLIBRETRO=ON -DARMV7=ON -DARM=ON -DARM_NO_VULKAN=ON -DUSING_GLES2=ON -DUSE_FFMPEG=ON -DUSE_SYSTEM_FFMPEG=OFF -DUSE_DISCORD=OFF -DUSE_MINIUPNPC=OFF -DUSE_SYSTEM_LIBPNG=OFF -DUSE_SYSTEM_ZSTD=OFF -DUSE_SYSTEM_LIBZIP=OFF -DUSE_SYSTEM_FREETYPE=OFF -DUSE_WAYLAND_WSI=OFF -DUSING_X11_VULKAN=OFF -DHEADLESS=OFF -DUNITTEST=OFF -DUSE_CCACHE=OFF -DCMAKE_BUILD_TYPE=Release"
receita_compilar() {
    ffmpeg_ppsspp_preparar || return 1
    cmake -S . -B build-m17 \
        -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=armv7l \
        -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
        -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
        -DCMAKE_FIND_ROOT_PATH="$EMU_TC/$EMU_HOST/sysroot" \
        -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
        -DFFMPEG_DIR="$PWD/ffmpeg/linux/armv7" \
        $RECEITA_OPCOES || return 1
    cmake --build build-m17 --target ppsspp_libretro -j"$NPROC"
}
receita_instalar() {
    "$STRIP" -o "$OUT/cores/ppsspp_libretro.so" "$(find build-m17 -name ppsspp_libretro.so | head -1)"
    # arquivos de sistema do PPSSPP (fontes da flash0, shaders, etc.): system/PPSSPP no cartao
    rm -rf "$OUT/system/PPSSPP"; mkdir -p "$OUT/system/PPSSPP"
    cp -r assets/. "$OUT/system/PPSSPP/"
    rm -rf "$OUT/system/PPSSPP/debugger" "$OUT/system/PPSSPP/lua"
}
