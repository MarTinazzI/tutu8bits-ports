#!/usr/bin/env bash
# Spec 036 (T01; CA-02): o teclado virtual (src/emu/teclado_m17/) no PC.
#   1. arnes da parte pura (teclado.c, gcc do PC, -Werror): grade, maiusculas, paginas, apagar, cursor, maximo,
#      cancelar (o ALT+X saiu na spec 042);
#   2. a parte modal (teclado_sdl.c) num programa de teste, no PC (gcc + SDL2 do sistema) e ARM no qemu-arm-static
#      (SDL2 do projeto), video dummy: roteiro de botoes -> texto devolvido, cancelar, X sem efeito de nome, nome
#      pronto da lista M17_NOMES (m17_teclado_nome, spec 042), o
#      tamanho logico do renderer do "jogo" restaurado; captura da tela do teclado (BMP).
# Nada e gravado fora de .cache/emu/testes/teclado.
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
. "$D/../../src/emu/ambiente.sh"
K="$EMU_RAIZ/src/emu/teclado_m17"
T="$EMU_CACHE/testes/teclado"
F=0
conta() { if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FALHA $2"; F=$((F + 1)); fi; }

rm -rf "$T"; mkdir -p "$T"

# --- 1. parte pura
gcc -std=c99 -Wall -Wextra -Werror -DM17T_TESTE -I"$K" -o "$T/arnes" "$D/fontes/arnes_teclado.c" "$K/teclado.c" \
    > "$T/arnes_cc.log" 2>&1
r=$?; [ $r -eq 0 ] || cat "$T/arnes_cc.log"
conta $r "arnes do teclado compilado (gcc do PC, -Werror)"
"$T/arnes" > "$T/arnes.log" 2>&1; r=$?
sed 's/^/      /' "$T/arnes.log" | grep -v 'falhas:'
conta $r "arnes do teclado ($(grep -c '^ok' "$T/arnes.log") casos verdes)"

# --- 2. parte modal: programa de teste no PC e no qemu
BDF="$EMU_CACHE/conteudo/fonte6x10/6x10.bdf"
python3 -I "$EMU_RAIZ/ports/rogue_m17/bdf_para_h.py" "$BDF" "$T/m17_fonte.h" > /dev/null 2>&1
conta $? "fonte 6x10 gerada (baixar_conteudo.sh fonte6x10)"
gcc -std=gnu99 -Wall -Wextra -Werror -I"$K" -I"$T" -I/usr/include/SDL2 -D_REENTRANT -o "$T/prog_pc" \
    "$D/fontes/prog_teclado.c" "$K/teclado.c" "$K/teclado_sdl.c" -lSDL2 > "$T/pc_cc.log" 2>&1
r=$?; [ $r -eq 0 ] || cat "$T/pc_cc.log"
conta $r "programa de teste no PC (gcc + SDL2 do sistema, -Werror)"
SDLCFG="$EMU_CACHE/src/sdl2_projeto/build-m17/include-config-release/SDL2/SDL_config.h"
mkdir -p "$T/libs"; cp "$EMU_CACHE/out/sdl2_projeto/libSDL2-2.0.so.0" "$T/libs/"
"$CC" $CFLAGS -std=gnu99 -Wall -Werror -include "$SDLCFG" -I"$K" -I"$T" -I"$EMU_INC/SDL2" -D_REENTRANT \
    -o "$T/prog_arm" "$D/fontes/prog_teclado.c" "$K/teclado.c" "$K/teclado_sdl.c" $LDFLAGS -L"$EMU_LIB_CARTAO" -lSDL2 \
    > "$T/arm_cc.log" 2>&1
r=$?; [ $r -eq 0 ] || cat "$T/arm_cc.log"
conta $r "programa de teste ARM (compilador do projeto, -Werror, sem funcao implicita)"

printf 'Valquiria\n\n\tlixo\nTyr\n' > "$T/nomes.txt"
# teclado NOME ROTEIRO TITULO INICIAL MAX [qemu]
teclado() {
    local n=$1 rot=$2 tit=$3 ini=$4 max=$5 q=${6:-}
    printf '%s' "$rot" > "$T/$n.rot"
    local exe=("$T/prog_pc")
    [ -n "$q" ] && exe=(qemu-arm-static -L "$EMU_ROOTFS" "$T/prog_arm")
    env SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software SDL_AUDIODRIVER=dummy LD_LIBRARY_PATH="$T/libs" \
        M17_TECLADO_ROTEIRO="$T/$n.rot" M17_TECLADO_TELA="$T/$n.bmp" M17_NOMES="$T/nomes.txt" \
        timeout -k 5 60 "${exe[@]}" "$tit" "$ini" "$max" > "$T/$n.out" 2> "$T/$n.err"
}
for q in "" qemu; do
    rot=${q:-pc}
    teclado "${rot}_ok" 'BBAvA>>AS' "Nome do save" "E1 F1" 20 $q
    grep -qx 'resultado=1 texto=\[E1 AKM\] logico=320x240' "$T/${rot}_ok.out" && grep -q '\[M17\] teclado: ok \[E1 AKM\]' "$T/${rot}_ok.err"
    conta $? "$rot: roteiro -> texto devolvido, tamanho logico do jogo restaurado ($(cat "$T/${rot}_ok.out"))"
    teclado "${rot}_cancela" 'AAs' "Nome" "abc" 20 $q
    grep -qx 'resultado=0 texto=\[abc\] logico=320x240' "$T/${rot}_cancela.out"
    conta $? "$rot: SELECT cancela e o texto do jogo fica como estava"
    teclado "${rot}_x" 'XAS' "Nome" "Tutu" 20 $q
    grep -qx 'resultado=1 texto=\[Tutua\] logico=320x240' "$T/${rot}_x.out"
    conta $? "$rot: X so troca maiusculas (sem ALT+X; spec 042) ($(cat "$T/${rot}_x.out"))"
    teclado "${rot}_lista" 'S' "Nome" "@lista" 5 $q
    grep -qx 'lista=1' "$T/${rot}_lista.out" && grep -qxE 'resultado=1 texto=\[(Valqu|Tyr)\] logico=320x240' "$T/${rot}_lista.out"
    conta $? "$rot: m17_teclado_nome abre o teclado com um nome da lista (sem as linhas vazias/com lixo, cortado no maximo)"
    [ -s "$T/${rot}_ok.bmp" ] && [ "$(od -An -tu4 -j18 -N8 "$T/${rot}_ok.bmp" | tr -s ' ')" = " 480 272" ]
    conta $? "$rot: captura da tela do teclado em 480x272"
done

echo "falhas: $F"
[ "$F" -eq 0 ]
