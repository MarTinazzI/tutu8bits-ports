# Duke Nukem 3D (spec 040, plano D-01/D-02): o JFDuke3D (C, SDL2) com o motor Build classico de software (sem Polymost
# nem OpenGL: USE_POLYMOST=0 USE_OPENGL=0, sem assembly x86: USE_ASM=0). A saida de 8 bits vai pelo renderer do SDL
# (jfbuild/src/sdlayer2.c). Som pelo jfaudiolib, sem Vorbis/FluidSynth (PKGCONFIG=/bin/false), sem GTK. O Makefile pede o
# sdl2-config: o do projeto (src/emu/receitas/sdl2-config). As ferramentas do build (bin2c, ARM) rodam pelo
# qemu-arm-static (binfmt) com as bibliotecas do compilador (QEMU_LD_PREFIX).
# O teclado virtual da spec 036 entra pelo patch jfduke3d-m17-02 (nome do save).
RECEITA_OPCOES="make USE_POLYMOST=0 USE_OPENGL=0 USE_ASM=0; sdl2-config do projeto (SDL_config.h); sem Vorbis/FluidSynth/GTK; CFLAGS -DM17"

receita_compilar() {
    local bdf="$EMU_CACHE/conteudo/fonte6x10/6x10.bdf"
    [ -f "$bdf" ] || { echo "falta $bdf (rode ports/baixar_conteudo.sh fonte6x10)"; return 1; }
    # o teclado virtual (spec 036) e a fonte dele, junto do fonte do jogo (o patch 02 os poe no Makefile)
    cp "$EMU_RAIZ"/src/emu/teclado_m17/teclado.c "$EMU_RAIZ"/src/emu/teclado_m17/teclado_sdl.c \
       "$EMU_RAIZ"/src/emu/teclado_m17/teclado.h src/ || return 1
    python3 -I "$EMU_RAIZ/ports/rogue_m17/bdf_para_h.py" "$bdf" src/m17_fonte.h || return 1
    export QEMU_LD_PREFIX="$EMU_TC/$EMU_HOST/sysroot"
    make -j"$NPROC" CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB" CFLAGS="$CFLAGS -DM17" CXXFLAGS="$CXXFLAGS -DM17" \
        LDFLAGS="$LDFLAGS" USE_POLYMOST=0 USE_OPENGL=0 USE_ASM=0 RELEASE=1 M17=1 \
        SDL2CONFIG="$EMU_RAIZ/src/emu/receitas/sdl2-config" PKGCONFIG=/bin/false duke3d > build-m17.log 2>&1 \
        || { tail -30 build-m17.log; return 1; }
    # nenhuma funcao sem declaracao (B-50)
    if grep 'implicit declaration' build-m17.log; then return 1; fi
    [ -f duke3d ] || { echo "faltou o duke3d"; return 1; }
}

receita_instalar() {
    rm -rf "$OUT/jfduke3d"; mkdir -p "$OUT/jfduke3d"
    "$STRIP" -o "$OUT/jfduke3d/duke3d" duke3d || return 1
}
