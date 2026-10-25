# Tyrian (spec 034, plano D-01/D-02): o OpenTyrian, programa proprio com SDL2 (C99, GPL-2.0). Desenha em 320x200
# por software e mostra pelo renderer do SDL2 (no aparelho, a libSDL2 do projeto: mali + GLES2). Som proprio (OPL
# emulado + amostras) pela API de audio do SDL: sem SDL2_mixer. Sem rede (SDL2_net): WITH_NETWORK=false.
# O Makefile do jogo usa pkg-config para o SDL2; aqui os caminhos vao direto (PKG_CONFIG=/bin/false).
# SDL_config.h configurado: o jogo usa malloc/free/roundf/sinf... sem incluir <stdlib.h>/<math.h> (conta com o
# SDL_stdinc.h, que so os inclui com os HAVE_* de um SDL_config.h configurado; o de $EMU_INC e o generico do tarball).
# Sem isso as funcoes ficam implicitas (retorno int) e os valores de ponto flutuante saem errados (spec 034, T03).
# Vem do build da libSDL2 do projeto (receita sdl2_projeto, compilada antes), a mesma que vai no cartao; entra por
# -include (o SDL_stdinc.h acha o generico pelo #include "SDL_config.h" da propria pasta, antes do -I).
RECEITA_OPCOES="make WITH_NETWORK=false; SDL_config.h do sdl2_projeto; CFLAGS -DM17; teclado virtual (teclado_m17)"

receita_compilar() {
    local sdlcfg="$SRC/sdl2_projeto/build-m17/include-config-release/SDL2"
    [ -f "$sdlcfg/SDL_config.h" ] || { echo "falta $sdlcfg/SDL_config.h (rode build.sh sdl2_projeto)"; return 1; }
    # spec 042 (D-12): o teclado virtual da spec 036 e a fonte dele, junto do fonte do jogo (o Makefile pega src/*.c)
    local bdf="$EMU_CACHE/conteudo/fonte6x10/6x10.bdf"
    [ -f "$bdf" ] || { echo "falta $bdf (rode ports/baixar_conteudo.sh fonte6x10)"; return 1; }
    cp "$EMU_RAIZ"/src/emu/teclado_m17/teclado.c "$EMU_RAIZ"/src/emu/teclado_m17/teclado_sdl.c \
       "$EMU_RAIZ"/src/emu/teclado_m17/teclado.h src/ || return 1
    python3 -I "$EMU_RAIZ/ports/rogue_m17/bdf_para_h.py" "$bdf" src/m17_fonte.h || return 1
    make clean >/dev/null 2>&1
    make -j"$NPROC" CC="$CC" PKG_CONFIG=/bin/false WITH_NETWORK=false \
        CFLAGS="$CFLAGS -DM17" LDFLAGS="$LDFLAGS" \
        SDL_CPPFLAGS="-include $sdlcfg/SDL_config.h -I$EMU_INC/SDL2 -D_REENTRANT" SDL_LDFLAGS="-L$EMU_LIB_CARTAO" SDL_LDLIBS="-lSDL2" \
        VCS_IDREV="echo v2.1.20260913" > build-m17.log 2>&1 || { tail -20 build-m17.log; return 1; }
    # sem rede e sem nada do sistema do PC no comando
    # nenhuma funcao sem declaracao (ver SDL_config.h acima)
    if grep -q 'implicit declaration' build-m17.log; then grep 'implicit declaration' build-m17.log | head; return 1; fi
    if grep -q -- '-DWITH_NETWORK' build-m17.log || grep -qE '(-I|-L)/usr/' build-m17.log; then return 1; fi
}

receita_instalar() {
    rm -rf "$OUT/opentyrian"; mkdir -p "$OUT/opentyrian"
    "$STRIP" -o "$OUT/opentyrian/opentyrian" opentyrian || return 1
}
