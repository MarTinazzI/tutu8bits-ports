# PSP (spec 023, candidato B, plano D-03): o PPSSPP standalone (alvo PPSSPPSDL), do mesmo fonte do
# nucleo (ppsspp-*.patch tambem, via build.sh), ARMv7 + NEON softfp, GLES2 pelo contexto GL do SDL
# (o mesmo que o RetroArch usa no aparelho, KB §11g/§11i), com o FFmpeg minimo do projeto.
# Sem EGL direto (patch ppsspp_sdl-m17-01-sem-egl: o caminho EGL chama XOpenDisplay), sem X11,
# Wayland, Vulkan, Discord e UPnP. Ligado contra os cabecalhos fixados do SDL2 2.28.5 e o soname
# libSDL2-2.0.so.0 (como o GameTank); em runtime usa a libSDL2 do projeto, no cartao.
# Instala como ppsspp_sdl/PPSSPPSDLTUTU: o ports/montar.sh barra o nome de fabrica PPSSPPSDL. Os
# assets sao os mesmos do nucleo (system/PPSSPP); o montar.sh os copia para ao lado do programa.
. "$EMU_RAIZ/ports/receitas/_ffmpeg_ppsspp.sh"
RECEITA_OPCOES="-DLIBRETRO=OFF -DARMV7=ON -DARM=ON -DARM_NO_VULKAN=ON -DUSING_GLES2=ON -DUSING_EGL=OFF -DUSE_FFMPEG=ON -DUSE_SYSTEM_FFMPEG=OFF -DUSE_DISCORD=OFF -DUSE_MINIUPNPC=OFF -DUSE_SYSTEM_LIBPNG=OFF -DUSE_SYSTEM_ZSTD=OFF -DUSE_SYSTEM_LIBZIP=OFF -DUSE_SYSTEM_FREETYPE=OFF -DUSE_SYSTEM_LIBSDL2=OFF -DUSE_WAYLAND_WSI=OFF -DUSING_X11_VULKAN=OFF -DHEADLESS=OFF -DUNITTEST=OFF -DUSE_CCACHE=OFF -DCMAKE_BUILD_TYPE=Release"
receita_compilar() {
    ffmpeg_ppsspp_preparar || return 1
    # SDL2 pelo cmake/sdl/FindSDL2.cmake do PPSSPP: cabecalhos fixados + a libSDL2 do cartao (mesmo
    # soname da do projeto), passados direto
    cmake -S . -B build-m17 \
        -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=armv7l \
        -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
        -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
        -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
        -DCMAKE_FIND_ROOT_PATH="$EMU_TC/$EMU_HOST/sysroot" \
        -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH \
        -DSDL2_INCLUDE_DIR="$EMU_INC/SDL2" -DSDL2_LIBRARY="$EMU_LIB_CARTAO/libSDL2.so" \
        -DCMAKE_DISABLE_FIND_PACKAGE_SDL2_ttf=ON \
        -DCMAKE_DISABLE_FIND_PACKAGE_Fontconfig=ON -DCMAKE_DISABLE_FIND_PACKAGE_X11=ON \
        -DCMAKE_DISABLE_FIND_PACKAGE_PkgConfig=ON \
        -DFFMPEG_DIR="$PWD/ffmpeg/linux/armv7" \
        $RECEITA_OPCOES || return 1
    # nada de X11/EGL direto na configuracao (D-03)
    grep -q '^USING_EGL:BOOL=OFF' build-m17/CMakeCache.txt || return 1
    cmake --build build-m17 --target PPSSPPSDL -j"$NPROC"
}
receita_instalar() {
    mkdir -p "$OUT/ppsspp_sdl"
    "$STRIP" -o "$OUT/ppsspp_sdl/PPSSPPSDLTUTU" build-m17/PPSSPPSDL
}
