#!/usr/bin/env bash
# Spec 035 (T07; CA-01, CA-02, CA-05, CA-07, CA-08): o Rogue do projeto no PC.
#   1. auditoria do ELF ARM; o patch de ganchos conferido no texto;
#   2. arnes da entrada (parte pura do m17entrada.c, gcc do PC): acorde, setores, giro, repeticao, correr, traducao
#      por pergunta, rogue.cfg;
#   3. build do PC (gcc + SDL2 do sistema, o mesmo fonte da receita) e um roteiro nele;
#   4. o binario ARM no qemu-arm-static, por roteiros (M17_ROTEIRO, com os botoes do controle): tela 80x24 com a
#      linha de estado; UM SIGTERM salva (rc 0, [M17] salvo) e reabrir com o save continua a mesma partida; o seletor
#      escolhe a arma certa; o "call it" cancelado pelo B; o ! desligado; o nome do ROGUEOPTS no placar e o fim pelo
#      jogo ([M17] fim); depois do placar o SIGTERM nao salva; rogue.cfg com lixo vira aviso.
# Espera por condicao ("[M17] roteiro: fim" no log), nunca por tempo fixo. Nada e gravado fora de
# .cache/emu/testes/rogue.
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
. "$D/../../src/emu/ambiente.sh"
B="$EMU_CACHE/out/rogue/rogue"
FONTE="$EMU_CACHE/src/rogue"
P01="$EMU_RAIZ/ports/patches/rogue-m17-01-ganchos.patch"
T="$EMU_CACHE/testes/rogue"
F=0
conta() { if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FALHA $2"; F=$((F + 1)); fi; }
ulimit -c 0

rm -rf "$T"; mkdir -p "$T/libs" "$T/pc"
cp "$EMU_CACHE/out/sdl2_projeto/libSDL2-2.0.so.0" "$T/libs/"

# --- 1. binario e patch
out=$("$D/../../src/emu/testes/auditar_elf.sh" "$B" "$T/libs"); r=$?
conta $r "auditoria de ELF: rogue"; [ $r -eq 0 ] || echo "$out" | grep FALHA
"$READELF" -d "$B" > "$T/dinamico.txt"
! grep -qiE 'NEEDED.*(ncurses|tinfo|X11|xcb|wayland|libGL\.so)' "$T/dinamico.txt"
conta $? "rogue sem ncurses/X11/OpenGL de PC (curses propria sobre o SDL2)"
[ "$(grep -c '^+.*m17_contexto(M17_\(SIMNAO\|DIRECAO\|TEXTO\|OPCOES\))' "$P01")" -ge 6 ] \
  && grep -q '^+	    m17_contexto_item(type);' "$P01" && grep -q '^+    m17_contexto_mais(ch);' "$P01" \
  && grep -q '^+#if defined(DUMP) || defined(M17)' "$P01" && grep -q '^+    return m17_tecla();' "$P01" \
  && grep -q 'no shell on this console' "$P01" && grep -q '^+    m17_partida_encerrada = 1;' "$P01"
conta $? "patch: perguntas marcadas (objeto, direcao, sim/nao, texto, opcoes, --More--), save no SIGTERM, fim de partida, sem shell"

# --- 2. arnes da entrada
gcc -std=c99 -Wall -Wextra -Werror -DM17E_TESTE -I"$EMU_RAIZ/ports/rogue_m17" -o "$T/arnes" \
    "$D/fontes/arnes_m17entrada.c" "$EMU_RAIZ/ports/rogue_m17/m17entrada.c" -lm > "$T/arnes_cc.log" 2>&1
conta $? "arnes da entrada compilado (gcc do PC, -Werror)"
mkdir -p "$T/arnes_tmp"
"$T/arnes" "$T/arnes_tmp" > "$T/arnes.log" 2>&1; r=$?
sed 's/^/      /' "$T/arnes.log" | grep -v 'falhas:'
conta $r "arnes da entrada ($(grep -c '^ok' "$T/arnes.log") casos verdes)"

# --- 3. build do PC (o fonte da receita: patch aplicado e camada copiada pelo build.sh)
_pc_ok=0
for f in "$FONTE"/*.c; do
    gcc -std=gnu99 -O1 -DM17 -DHAVE_CONFIG_H -I"$FONTE" -I/usr/include/SDL2 -D_REENTRANT -c "$f" \
        -o "$T/pc/$(basename "${f%.c}").o" 2>> "$T/pc/avisos.txt" || _pc_ok=1
done
[ $_pc_ok -eq 0 ] && gcc -o "$T/pc/rogue" "$T/pc"/*.o -lSDL2 -lm 2>> "$T/pc/avisos.txt"
r=$?; ! grep -q 'implicit declaration' "$T/pc/avisos.txt" || r=1
conta $r "build do PC (gcc + SDL2 do sistema), sem funcao implicita"

# rodar NOME ROTEIRO [args...]: roda no qemu (ou no PC com PC=1) numa pasta propria ate o fim do roteiro e, se
# ainda estiver rodando, manda UM SIGTERM; deixa rc em $T/<nome>/rc
rodar() {
    local n=$1 rot=$2; shift 2
    local d="$T/$n"; mkdir -p "$d"
    printf '%s' "$rot" > "$d/rot.txt"
    local exe=(qemu-arm-static -L "$EMU_ROOTFS" "$B")
    [ "${PC:-0}" = 1 ] && exe=("$T/pc/rogue")
    ( cd "$d" && exec env SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software SDL_AUDIODRIVER=dummy \
        LD_LIBRARY_PATH="$T/libs" M17_ROTEIRO="$d/rot.txt" M17_TELA_TXT="$d/tela.txt" M17_TELA="$d/tela.bmp" \
        ROGUEOPTS="name=${NOME:-Tutu},file=rogue.save" M17_ROGUE_CFG="${CFG:-}" \
        timeout -k 5 180 "${exe[@]}" "$@" ) > "$d/log.txt" 2>&1 &
    local p=$! i=0
    while [ $i -lt 900 ] && ! grep -q 'roteiro: fim' "$d/log.txt" 2>/dev/null && kill -0 $p 2>/dev/null; do
        sleep 0.2; i=$((i + 1))
    done
    sleep 0.5   # a ultima tecla do roteiro ainda e processada antes da espera
    case "$p" in ''|*[!0-9]*) echo 99 > "$d/rc"; return ;; esac
    kill -0 $p 2>/dev/null && kill -TERM $p 2>/dev/null
    wait $p; echo $? > "$d/rc"
}
linha() { sed -n "${2}p" "$T/$1/tela.txt" | sed 's/ *$//'; }

PC=1 rodar pc ''
[ "$(cat "$T/pc/rc")" = 0 ] && grep -q '\[M17\] salvo' "$T/pc/log.txt" && linha pc 24 | grep -q '^Level: 1 ' \
    && ok=0 || ok=1
conta $ok "PC: roteiro, linha de estado na tela, UM SIGTERM salva (rc 0)"

if ! command -v qemu-arm-static > /dev/null; then conta 1 "qemu-arm-static"; echo "falhas: $F"; exit 1; fi
# --- 4. qemu (o binario do aparelho)
# sem gastar turnos: o mapa e sorteado e um monstro poderia agir (tela diferente = teste instavel)
rodar salvar ''
[ "$(wc -l < "$T/salvar/tela.txt")" = 24 ] && linha salvar 24 | grep -q '^Level: 1  Gold: 0 .*Hp: 12(12)'
conta $? "tela 80x24 com a linha de estado ($(linha salvar 24 | cut -c1-40)...)"
[ "$(cat "$T/salvar/rc")" = 0 ] && grep -q '\[M17\] salvo' "$T/salvar/log.txt" && [ -s "$T/salvar/rogue.save" ]
conta $? "UM SIGTERM: salva a partida e sai com rc 0 ($(stat -c %s "$T/salvar/rogue.save" 2>/dev/null) bytes)"
python3 -I -c 'import sys; from PIL import Image; im = Image.open(sys.argv[1]); sys.exit(0 if im.size == (480, 272) else 1)' \
    "$T/salvar/tela.bmp" 2>/dev/null
conta $? "captura da tela em 480x272"
cp "$T/salvar/tela.txt" "$T/tela_antes.txt"
mkdir -p "$T/continuar"; cp "$T/salvar/rogue.save" "$T/continuar/"
rodar continuar '' rogue.save
# linha 1 = mensagens (ao restaurar o jogo mostra "File name: rogue.save"); 2..24 = o mapa e a linha de estado
cmp -s <(sed -n '2,24p' "$T/tela_antes.txt") <(sed -n '2,24p' "$T/continuar/tela.txt") && linha continuar 1 | grep -q 'rogue.save' \
  && [ "$(cat "$T/continuar/rc")" = 0 ] && grep -q '\[M17\] salvo' "$T/continuar/log.txt"
conta $? "reabrir com o save: a mesma partida (o mesmo mapa) e o SIGTERM salva de novo"

rodar seletor 'w{baixo}{A}'
linha seletor 1 | grep -q '^You are now wielding a .*short bow'
conta $? "seletor de objeto: w abre a lista, baixo + A escolhe o arco ($(linha seletor 1))"
rodar callit 'c{A}{B}!'
linha callit 1 | grep -q 'No shell on this console'
conta $? "\"call it\": B cancela e o jogo segue; ! desligado ($(linha callit 1))"
rodar versao '{START}{baixo}{baixo}{baixo}{A}'
linha versao 1 | grep -q '^Version 5.4.4'
conta $? "START: o menu do jogo manda o comando (versao)"

NOME=Martinazzi rodar placar 'Qy\n'
# (com 0 de ouro a partida nao entra no top 10: o nome se confere na abertura, "Hello <nome>")
[ "$(cat "$T/placar/rc")" = 0 ] && grep -q '\[M17\] fim' "$T/placar/log.txt" && grep -q '^Hello Martinazzi, ' "$T/placar/log.txt" \
  && grep -q 'Top Ten Scores' "$T/placar/log.txt" && [ -e "$T/placar/rogue.scr" ] && [ ! -e "$T/placar/rogue.save" ]
conta $? "desistir (Q, y, Enter): nome do ROGUEOPTS, placar em rogue.scr na pasta, fim pelo jogo ([M17] fim), sem save"
rodar morto 'Qy'
[ "$(cat "$T/morto/rc")" = 0 ] && grep -q '\[M17\] fim' "$T/morto/log.txt" && [ ! -e "$T/morto/rogue.save" ]
conta $? "SIGTERM depois do placar: nao salva a partida encerrada"

printf 'acorde_ms=9999\nlixo\n' > "$T/rogue.cfg"
CFG="$T/rogue.cfg" rodar cfg ''
grep -q '\[M17\] rogue.cfg: acorde_ms invalida, usando o padrao 60' "$T/cfg/log.txt" \
  && grep -q '\[M17\] entrada: acorde 60 ms' "$T/cfg/log.txt" && [ "$(cat "$T/cfg/rc")" = 0 ]
conta $? "rogue.cfg com lixo: o jogo abre com o padrao e avisa no log"

echo "falhas: $F"
[ "$F" -eq 0 ]
