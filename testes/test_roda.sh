#!/usr/bin/env bash
# Spec 048 (T02; CA-01, CA-03): a roda de opcoes (src/emu/roda_m17/) no PC.
#   1. arnes da parte pura (roda.c, gcc do PC, -Werror): setores, zona morta, paginas, os dois modos de confirmar,
#      UTF-8 -> Latin-1, a notacao das acoes e cada erro do arquivo com a sua linha;
#   2. a parte modal (roda_sdl.c, T03) num programa de teste, no PC (gcc + SDL2 do sistema) e ARM no qemu-arm-static
#      (SDL2 do projeto), video dummy: roteiro -> acao escolhida, pagina, cancelar (B e R3), gatilho rapido ligado e
#      desligado, SDL_QUIT devolvido para a fila, tamanho logico do "jogo" restaurado, o injetor (Ctrl, maiuscula,
#      <F5>) e a captura da roda (BMP 480x272);
#   3. as rodas do produto (cartao/tutu8bits/dados/rodas/) e o exemplo do guia do usuario leem sem erro.
# Nada e gravado fora de .cache/emu/testes/roda.
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
. "$D/../../src/emu/ambiente.sh"
R="$EMU_RAIZ/src/emu/roda_m17"
T="$EMU_CACHE/testes/roda"
F=0
conta() { if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FALHA $2"; F=$((F + 1)); fi; }

rm -rf "$T"; mkdir -p "$T"

# --- 1. parte pura
gcc -std=c99 -Wall -Wextra -Werror -I"$R" -o "$T/arnes" "$D/fontes/arnes_roda.c" "$R/roda.c" -lm \
    > "$T/arnes_cc.log" 2>&1
r=$?; [ $r -eq 0 ] || cat "$T/arnes_cc.log"
conta $r "arnes da roda compilado (gcc do PC, -Werror)"
"$T/arnes" > "$T/arnes.log" 2>&1; r=$?
sed 's/^/      /' "$T/arnes.log" | grep -v 'falhas:'
conta $r "arnes da roda ($(grep -c '^ok' "$T/arnes.log") casos verdes)"

# --- 2. parte modal: programa de teste no PC e no qemu
BDF="$EMU_CACHE/conteudo/fonte6x10/6x10.bdf"
python3 -I "$EMU_RAIZ/ports/rogue_m17/bdf_para_h.py" --latin1 "$BDF" "$T/m17_fonte_latin1.h" > /dev/null 2>&1
conta $? "fonte 6x10 com Latin-1 gerada (baixar_conteudo.sh fonte6x10)"
gcc -std=gnu99 -Wall -Wextra -Werror -I"$R" -I"$T" -I/usr/include/SDL2 -D_REENTRANT -o "$T/prog_pc" \
    "$D/fontes/prog_roda.c" "$R/roda.c" "$R/roda_sdl.c" -lSDL2 -lm > "$T/pc_cc.log" 2>&1
r=$?; [ $r -eq 0 ] || cat "$T/pc_cc.log"
conta $r "programa de teste no PC (gcc + SDL2 do sistema, -Werror)"
SDLCFG="$EMU_CACHE/src/sdl2_projeto/build-m17/include-config-release/SDL2/SDL_config.h"
mkdir -p "$T/libs"; cp "$EMU_CACHE/out/sdl2_projeto/libSDL2-2.0.so.0" "$T/libs/"
"$CC" $CFLAGS -std=gnu99 -Wall -Werror -include "$SDLCFG" -I"$R" -I"$T" -I"$EMU_INC/SDL2" -D_REENTRANT \
    -o "$T/prog_arm" "$D/fontes/prog_roda.c" "$R/roda.c" "$R/roda_sdl.c" $LDFLAGS -L"$EMU_LIB_CARTAO" -lSDL2 -lm \
    > "$T/arm_cc.log" 2>&1
r=$?; [ $r -eq 0 ] || cat "$T/arm_cc.log"
conta $r "programa de teste ARM (compilador do projeto, -Werror, sem funcao implicita)"

cat > "$T/teste.roda" <<'RODA'
rapido = nao
[Ações]
Pegar  | Pegar o que está no chão | ,
Rezar  | Rezar aos deuses          | #pray
Chutar | Chutar numa direção       | ^D
Lançar | Lançar uma magia          | Z
[Teclas]
Ctrl   | Ctrl+D                    | ^D
Duas   | A maiúscula e b           | Ab
F5     | A tecla F5                | <F5>
[Última]
Só     | Uma fatia só              | x
RODA
# roda NOME ROTEIRO RAPIDO [injetar] [qemu]
roda() {
    local n=$1 rot=$2 rap=$3 inj=${4:-} q=${5:-}
    printf '%s' "$rot" > "$T/$n.rot"
    local exe=("$T/prog_pc")
    [ -n "$q" ] && exe=(qemu-arm-static -L "$EMU_ROOTFS" "$T/prog_arm")
    env SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software SDL_AUDIODRIVER=dummy LD_LIBRARY_PATH="$T/libs" \
        M17_RODA_ROTEIRO="$T/$n.rot" M17_RODA_TELA="$T/$n.bmp" \
        timeout -k 5 60 "${exe[@]}" "$T/teste.roda" "$rap" $inj > "$T/$n.out" 2> "$T/$n.err"
}
for q in "" qemu; do
    o=${q:-pc}
    roda "${o}_lancar" "p3 A" 0 "" $q
    grep -qx 'resultado=1 acao=\[Z\] logico=320x240' "$T/${o}_lancar.out" && LC_ALL=C grep -q '\[M17\] roda: escolheu Lan.ar (Z)' "$T/${o}_lancar.err" \
      && [ "$(od -An -tu4 -j18 -N8 "$T/${o}_lancar.bmp" | tr -s ' ')" = " 480 272" ]
    conta $? "$o: apontar a 4a fatia e A -> acao Z; tamanho logico do jogo restaurado; tela 480x272 ($(cat "$T/${o}_lancar.out" | head -1))"
    roda "${o}_pagina" "R1 R1 p0 A" 0 "" $q
    grep -qx 'resultado=1 acao=\[x\] logico=320x240' "$T/${o}_pagina.out"
    conta $? "$o: R1 duas vezes -> 3a pagina, fatia unica"
    roda "${o}_cancelar" "p1 B" 0 "" $q
    roda "${o}_r3" "p1 R3" 0 "" $q
    grep -qx 'resultado=0 acao=\[\] logico=320x240' "$T/${o}_cancelar.out" && grep -q '\[M17\] roda: cancelada' "$T/${o}_cancelar.err" \
      && grep -qx 'resultado=0 acao=\[\] logico=320x240' "$T/${o}_r3.out"
    conta $? "$o: B e R3 cancelam"
    roda "${o}_rapido" "p1 p1 c" 1 "" $q
    roda "${o}_lento" "p1 p1 c B" 0 "" $q
    roda "${o}_fica" "p2 c A" 0 "" $q
    grep -qx 'resultado=1 acao=\[#pray\] logico=320x240' "$T/${o}_rapido.out" && grep -qx 'resultado=0 acao=\[\] logico=320x240' "$T/${o}_lento.out" \
      && grep -qx 'resultado=1 acao=\[^D\] logico=320x240' "$T/${o}_fica.out"
    conta $? "$o: gatilho rapido: soltar confirma (#pray); desligado, soltar nao confirma e a fatia fica escolhida para o A (^D)"
    roda "${o}_quit" "p1 Q" 0 "" $q
    grep -qx 'resultado=-1 acao=\[\] logico=320x240' "$T/${o}_quit.out" && grep -qx 'quit_na_fila=1' "$T/${o}_quit.out"
    conta $? "$o: SDL_QUIT com a roda aberta -> -1 e o evento volta para a fila"
    roda "${o}_ctrl" "R1 p0 A" 0 injetar $q
    roda "${o}_f5" "R1 p2 A" 0 injetar $q
    grep -qx 'KEYDOWN Ctrl+D' "$T/${o}_ctrl.out" && grep -qx 'KEYDOWN F5' "$T/${o}_f5.out"
    conta $? "$o: injetor: ^D = Ctrl+D, <F5> = F5"
    # o caso com texto (SDL_TEXTINPUT) so no qemu, com o SDL 2.28 que vai para o aparelho: no PC o libSDL2 e o
    # sdl2-compat (SDL3), que cai no SDL_PushEvent de qualquer SDL_TEXTINPUT (visto no 2.32.72, programa minimo)
    if [ -n "$q" ]; then
        roda "${o}_duas" "R1 p1 A" 0 injetar $q
        grep -qx 'injetadas=2' "$T/${o}_duas.out" \
          && [ "$(grep -E '^(KEYDOWN|TEXT)' "$T/${o}_duas.out" | tr '\n' ' ')" = "KEYDOWN A TEXT A KEYDOWN B TEXT b " ]
        conta $? "$o: injetor: Ab = duas teclas com texto (A maiuscula)"
    fi
done

# --- 3. as rodas do produto e o exemplo do guia do usuario (cartao/tutu8bits/docs/rodas.md) leem sem erro
RODAS=$(ls "$EMU_RAIZ"/cartao/tutu8bits/dados/rodas/*.roda 2>/dev/null)
awk '/^```text$/ { dentro = 1; next } /^```$/ { if (dentro) exit } dentro' "$EMU_RAIZ/cartao/tutu8bits/docs/rodas.md" \
    > "$T/exemplo_do_guia.roda"
# shellcheck disable=SC2086
"$T/arnes" $RODAS "$T/exemplo_do_guia.roda" > "$T/produto.log" 2>&1; r=$?
sed 's/^/      /' "$T/produto.log" | grep -v 'falhas:'
[ -n "$RODAS" ] && [ -s "$T/exemplo_do_guia.roda" ]
conta $(( r + $? )) "rodas do produto ($(echo "$RODAS" | wc -w)) e o exemplo do rodas.md leem sem erro"

echo "falhas: $F"
[ "$F" -eq 0 ]
