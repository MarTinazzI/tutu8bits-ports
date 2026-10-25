# Quake nativo (spec 050, plano D-01): o TyrQuake original (cliente NetQuake de software, bin/tyr-quake) com os alvos
# SDL2 do Makefile (USE_SDL=Y; o vid_sdl.c desenha os 8 bits numa textura do SDL_Renderer). Sem assembly x86, sem GL,
# sem o CD de verdade (CD_TARGET=null). Som pelo snd_sdl.c (uma abertura do audio); a musica (music/trackNN.ogg, .mp3,
# .flac, .wav) e do proprio motor (snd_music.c, decodificadores embutidos em external/; plano D-06). O Makefile pede o
# sdl2-config: o do projeto (src/emu/receitas/sdl2-config).
RECEITA_OPCOES="make bin/tyr-quake LOCALBASE= USE_SDL=Y USE_X86_ASM=N CD_TARGET=null; sdl2-config do projeto (SDL_config.h); CFLAGS -DM17"

receita_compilar() {
    local sc="$EMU_RAIZ/src/emu/receitas/sdl2-config"
    make -j"$NPROC" CC="$CC" STRIP="" LOCALBASE= TARGET_OS=UNIX TARGET_UNIX=linux USE_SDL=Y USE_X86_ASM=N CD_TARGET=null \
        CFLAGS="$CFLAGS -DM17" SDL_CFLAGS="$("$sc" --cflags)" SDL_LFLAGS="$LDFLAGS $("$sc" --libs)" \
        bin/tyr-quake > build-m17.log 2>&1 || { tail -30 build-m17.log; return 1; }
    # nenhuma funcao sem declaracao (B-50)
    if grep 'implicit declaration' build-m17.log; then return 1; fi
    [ -f bin/tyr-quake ] || { echo "faltou o bin/tyr-quake"; return 1; }
}

receita_instalar() {
    rm -rf "$OUT/tyrquake_sdl"; mkdir -p "$OUT/tyrquake_sdl"
    "$STRIP" -o "$OUT/tyrquake_sdl/tyr-quake" bin/tyr-quake || return 1
}
