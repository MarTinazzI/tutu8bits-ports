# SDL2_gfx do projeto (spec 047, plano D-01): para o GNU FreeDink, que usa o controle de quadros por segundo
# (SDL2_framerate) e a escala de superficies (SDL2_rotozoom). Os quatro .c direto numa .so, sem o autotools do
# pacote e sem MMX (e ARM), como no spike. O fonte e o upstream 1.0.4 guardado no git do Debian (tag
# upstream/1.0.4+dfsg): os .c e .h sao identicos byte a byte aos do tarball do autor (ferzkopp.net), conferido na T02.
# Ligada contra os cabecalhos fixados do SDL2 2.28.5 e o soname libSDL2-2.0.so.0.
RECEITA_OPCOES="cc -shared SDL2_framerate.c SDL2_gfxPrimitives.c SDL2_imageFilter.c SDL2_rotozoom.c (sem MMX)"

receita_compilar() {
    rm -rf build-m17; mkdir -p build-m17
    "$CC" $CFLAGS -fPIC -shared -I"$EMU_INC/SDL2" -I. \
        SDL2_framerate.c SDL2_gfxPrimitives.c SDL2_imageFilter.c SDL2_rotozoom.c \
        -Wl,-soname,libSDL2_gfx-1.0.so.0 $LDFLAGS -L"$EMU_LIB_CARTAO" -lSDL2 -lm -o build-m17/libSDL2_gfx-1.0.so.0
}

receita_instalar() {
    mkdir -p "$OUT/sdl2_gfx"
    "$STRIP" -o "$OUT/sdl2_gfx/libSDL2_gfx-1.0.so.0" build-m17/libSDL2_gfx-1.0.so.0
}
