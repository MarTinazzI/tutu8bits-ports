# Rogue 5.4.4 (spec 035, plano D-01..D-03, D-10): o jogo em C (BSD) com uma curses PROPRIA (ports/rogue_m17/) que
# guarda a tela 80x24 na memoria e a desenha pelo renderer do SDL2 (no aparelho, a libSDL2 do projeto: mali + GLES2),
# com a fonte misc-fixed 6x10 (dominio publico) em celula 6x11. Sem configure (ele procura a ncurses): config.h
# proprio. Os ganchos no jogo sao o patch rogue-m17-01. A fonte vem de ports/baixar_conteudo.sh fonte6x10.
# SDL_config.h configurado do sdl2_projeto por -include (como o opentyrian, spec 034 T03): sem ele o SDL_stdinc.h nao
# inclui os cabecalhos da libc e funcoes ficam implicitas.
RECEITA_OPCOES="cc *.c + rogue_m17/*.c; config.h proprio; SDL_config.h do sdl2_projeto; CFLAGS -DM17 -DHAVE_CONFIG_H"

receita_compilar() {
    local sdlcfg="$SRC/sdl2_projeto/build-m17/include-config-release/SDL2"
    local bdf="$EMU_CACHE/conteudo/fonte6x10/6x10.bdf"
    [ -f "$sdlcfg/SDL_config.h" ] || { echo "falta $sdlcfg/SDL_config.h (rode build.sh sdl2_projeto)"; return 1; }
    [ -f "$bdf" ] || { echo "falta $bdf (rode ports/baixar_conteudo.sh fonte6x10)"; return 1; }
    cp "$EMU_RAIZ"/ports/rogue_m17/*.h "$EMU_RAIZ"/ports/rogue_m17/*.c . 2>/dev/null
    cp "$EMU_RAIZ"/ports/rogue_m17/config.h "$EMU_RAIZ"/ports/rogue_m17/curses.h . || return 1
    python3 -I "$EMU_RAIZ/ports/rogue_m17/bdf_para_h.py" "$bdf" m17_fonte.h || return 1
    rm -rf build-m17; mkdir -p build-m17
    local f o objs=""
    for f in *.c; do
        o="build-m17/${f%.c}.o"
        "$CC" $CFLAGS -DM17 -DHAVE_CONFIG_H -include "$sdlcfg/SDL_config.h" -I. -I"$EMU_INC/SDL2" -D_REENTRANT \
            -c "$f" -o "$o" 2>> build-m17/avisos.txt || { cat build-m17/avisos.txt; return 1; }
        objs="$objs $o"
    done
    # nenhuma funcao sem declaracao (retorno int implicito quebra ponto flutuante no aparelho; spec 034 T03)
    if grep -q 'implicit declaration' build-m17/avisos.txt; then grep 'implicit declaration' build-m17/avisos.txt; return 1; fi
    # shellcheck disable=SC2086
    "$CC" $CFLAGS $LDFLAGS -o build-m17/rogue $objs -L"$EMU_LIB_CARTAO" -lSDL2 -lm || return 1
}

receita_instalar() {
    rm -rf "$OUT/rogue"; mkdir -p "$OUT/rogue"
    "$STRIP" -o "$OUT/rogue/rogue" build-m17/rogue || return 1
}
