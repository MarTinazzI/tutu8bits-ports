# NetHack 3.6.7 (spec 036, plano D-01/D-02/D-17): o jogo em C (NGPL) com uma interface de janelas PROPRIA, a "m17"
# (ports/nethack_m17/), que desenha pelo renderer do SDL2 (no aparelho, a libSDL2 do projeto: mali + GLES2) com a
# fonte misc-fixed 6x10 da spec 035 e le o controle cru; texto pelo teclado virtual (src/emu/teclado_m17/); a roda de
# opcoes no R3 (src/emu/roda_m17/, spec 048); a entrada
# em 8 direcoes e a da spec 035 (ports/rogue_m17/m17entrada.c, parte pura). Sem tty, sem compress; dados num DLB.
# Compila TUDO com o compilador do projeto: as ferramentas do build (makedefs, dgn_comp, lev_comp, dlb) rodam pelo
# qemu-arm-static (binfmt, QEMU_LD_PREFIX), entao os niveis saem com o tamanho de long do aparelho. Os analisadores
# (lev/dgn yacc/lex) sao os pre-gerados de sys/share (sem yacc/lex no PC).
# Um 2o build em build-pc/ (gcc + SDL2 do sistema) serve aos testes e para jogar no PC; nao vai para o cartao.
RECEITA_OPCOES="hints m17 (sem tty/compress, DLB, SYSCF relativo); interface m17 sobre SDL2; ferramentas pelo qemu"

nethack_preparar() {   # copia a camada, gera a fonte, analisadores pre-gerados, Makefiles pelo hints m17
    local bdf="$EMU_CACHE/conteudo/fonte6x10/6x10.bdf"
    [ -f "$bdf" ] || { echo "falta $bdf (rode ports/baixar_conteudo.sh fonte6x10)"; return 1; }
    mkdir -p win/m17
    cp "$EMU_RAIZ"/ports/nethack_m17/*.c "$EMU_RAIZ"/ports/nethack_m17/*.h win/m17/ || return 1
    cp "$EMU_RAIZ"/src/emu/teclado_m17/teclado.c "$EMU_RAIZ"/src/emu/teclado_m17/teclado_sdl.c \
       "$EMU_RAIZ"/src/emu/teclado_m17/teclado.h win/m17/ || return 1
    cp "$EMU_RAIZ"/ports/rogue_m17/m17entrada.c "$EMU_RAIZ"/ports/rogue_m17/m17entrada.h win/m17/ || return 1
    # spec 048: a roda de opcoes (R3) e a fonte com os acentos (Latin-1)
    cp "$EMU_RAIZ"/src/emu/roda_m17/roda.c "$EMU_RAIZ"/src/emu/roda_m17/roda.h "$EMU_RAIZ"/src/emu/roda_m17/roda_sdl.c \
       "$EMU_RAIZ"/src/emu/roda_m17/roda_sdl.h win/m17/ || return 1
    python3 -I "$EMU_RAIZ/ports/rogue_m17/bdf_para_h.py" "$bdf" win/m17/m17_fonte.h || return 1
    python3 -I "$EMU_RAIZ/ports/rogue_m17/bdf_para_h.py" --latin1 "$bdf" win/m17/m17_fonte_latin1.h || return 1
    cp sys/share/lev_yacc.c sys/share/lev_lex.c sys/share/dgn_yacc.c sys/share/dgn_lex.c util/ || return 1
    cp sys/share/lev_comp.h sys/share/dgn_comp.h include/ || return 1
    touch util/*_yacc.c util/*_lex.c include/lev_comp.h include/dgn_comp.h
    cp "$EMU_RAIZ/ports/nethack_m17/hints-m17" sys/unix/hints/m17 || return 1
    ( cd sys/unix && sh setup.sh hints/m17 ) > /dev/null || return 1
}

nethack_make() {   # pasta, depois as variaveis do make (CC=... M17_CFLAGS=...)
    local d=$1; shift
    ( cd "$d" && make "$@" nethack && make "$@" bogusmon data engrave epitaph oracles options quest.dat rumors \
        && make "$@" dungeon spec_levs && make "$@" check-dlb && make "$@" recover ) || return 1
    [ -f "$d/src/nethack" ] && [ -f "$d/dat/nhdat" ] || { echo "faltou src/nethack ou dat/nhdat em $d"; return 1; }
}

receita_compilar() {
    local sdlcfg="$SRC/sdl2_projeto/build-m17/include-config-release/SDL2/SDL_config.h"
    [ -f "$sdlcfg" ] || { echo "falta $sdlcfg (rode build.sh sdl2_projeto)"; return 1; }
    nethack_preparar || return 1
    rm -rf build-pc; mkdir build-pc
    tar --exclude=./build-pc -cf - . | tar -C build-pc -xf - || return 1
    # ARM: as ferramentas do build sao ARM e rodam pelo qemu (binfmt) com as bibliotecas do compilador
    export QEMU_LD_PREFIX="$EMU_TC/$EMU_HOST/sysroot"
    nethack_make . CC="$CC" M17_CFLAGS="$CFLAGS" \
        M17_SDL_CFLAGS="-include $sdlcfg -I$EMU_INC/SDL2 -D_REENTRANT -I../win/m17" \
        M17_LDFLAGS="$LDFLAGS" M17_SDL_LIBS="-L$EMU_LIB_CARTAO -lSDL2" > build-arm.log 2>&1 \
        || { tail -30 build-arm.log; return 1; }
    # PC (testes e para jogar no PC): gcc + SDL2 do sistema
    nethack_make build-pc CC=gcc M17_CFLAGS="-O1 -std=gnu99" M17_SDL_CFLAGS="-I/usr/include/SDL2 -D_REENTRANT -I../win/m17" \
        M17_LDFLAGS="" M17_SDL_LIBS="-lSDL2" > build-pc.log 2>&1 || { tail -30 build-pc.log; return 1; }
    # nenhuma funcao sem declaracao (retorno int implicito quebra ponto flutuante no aparelho; spec 034 T03)
    if grep -h 'implicit declaration' build-arm.log build-pc.log; then return 1; fi
}

receita_instalar() {
    rm -rf "$OUT/nethack"; mkdir -p "$OUT/nethack"
    "$STRIP" -o "$OUT/nethack/nethack" src/nethack || return 1
    # recover: refaz o save de uma partida interrompida sem salvar (energia cortada); o lancar.sh o roda (plano D-16)
    "$STRIP" -o "$OUT/nethack/recover" util/recover || return 1
    cp dat/nhdat dat/license dat/symbols "$OUT/nethack/" || return 1
}
