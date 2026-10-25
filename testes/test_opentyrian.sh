#!/usr/bin/env bash
# Spec 034 (T05, CA-01/CA-04/CA-05/CA-06): o OpenTyrian do projeto (Tyrian) no PC.
#   1. auditoria de ELF; os dois patches (saida e nomes) conferidos no texto e no binario;
#   2. arnes do m17_nomes.c no gcc do PC (lista valida/vazia/ausente/com lixo, corte, sorteio);
#   2b. (spec 042) o campo de nome pelo teclado virtual, no qemu, pelo gancho M17_TESTE_NOME (save e placar) com o
#      roteiro do teclado: nome pronto da lista, editado, OK; cancelar;
#   3. o jogo no qemu-arm-static com video/audio dummy, os dados do Tyrian 2.1 do .cache e a configuracao inicial do
#      produto: espera o fim da inicializacao (por condicao), manda UM SIGTERM e confere rc 0, "[M17] saida", os tres
#      arquivos gravados e as chaves do produto iguais no opentyrian.cfg regravado;
#   4. sem os dados: sai sozinho com erro, sem travar.
# Os dados ficam fora do repositorio (licenca da Epic): ports/baixar_conteudo.sh tyrian (sem eles, FALHA).
# Nada e gravado fora de .cache/emu/testes/opentyrian.
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
. "$D/../../src/emu/ambiente.sh"
B="$EMU_CACHE/out/opentyrian/opentyrian"
ZIP="$EMU_CACHE/conteudo/tyrian/tyrian21.zip"
CFG="$EMU_RAIZ/ports/config/opentyrian/opentyrian.cfg"
P01="$EMU_RAIZ/ports/patches/opentyrian-m17-01-sair.patch"
P02="$EMU_RAIZ/ports/patches/opentyrian-m17-02-nomes.patch"
T="$EMU_CACHE/testes/opentyrian"
F=0
conta() { if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FALHA $2"; F=$((F + 1)); fi; }
ulimit -c 0

rm -rf "$T"; mkdir -p "$T/libs" "$T/dados"
cp "$EMU_CACHE/out/sdl2_projeto/libSDL2-2.0.so.0" "$T/libs/"
conta $? "libSDL2 do projeto copiada"

# --- 1. binario e patches
out=$("$D/../../src/emu/testes/auditar_elf.sh" "$B" "$T/libs"); r=$?
conta $r "auditoria de ELF: opentyrian"; [ $r -eq 0 ] || echo "$out" | grep FALHA
"$READELF" -d "$B" > "$T/dinamico.txt"
! grep -qiE 'NEEDED.*(X11|xcb|wayland|libGL\.so|SDL2_net)' "$T/dinamico.txt"
conta $? "opentyrian sem X11/Wayland/OpenGL de PC/SDL2_net"
grep -q '^+				JE_tyrianHalt(0);$' "$P01" && grep -q '^+	logInfo("\[M17\] saida");' "$P01"
conta $? "patch 01: SDL_QUIT sai pelo JE_tyrianHalt e escreve [M17] saida"
[ "$(grep -c '^+.*temp = m17_nome_preencher(stemp, 0, ' "$P02")" = 2 ] && [ "$(grep -c '^+.*m17_nome_teclado("' "$P02")" = 2 ] \
  && ! grep -q 'm17_alt_x\|rk29' "$P02"
conta $? "patch 02: nome pronto da lista e teclado virtual nos dois campos (save 14, placar 28), sem ALT+X (042)"
strings "$B" > "$T/strings.txt"   # para arquivo: grep -q num pipe com pipefail falha ao matar o strings (SIGPIPE)
grep -q '\[M17\] saida' "$T/strings.txt" && grep -q '\[M17\] teclado: aberto' "$T/strings.txt" && ! grep -q 'rk29-keypad' "$T/strings.txt"
conta $? "binario com os dois patches ([M17] saida, teclado virtual; sem leitura do rk29-keypad)"

# --- 2. arnes do m17_nomes.c (gcc do PC, sem SDL)
NOMES_C="$EMU_CACHE/src/opentyrian/src/m17_nomes.c"
gcc -std=c99 -Wall -Wextra -Werror -DM17_NOMES_TESTE -I"$(dirname "$NOMES_C")" -o "$T/arnes" \
    "$D/fontes/arnes_m17_nomes.c" "$NOMES_C" > "$T/arnes_cc.log" 2>&1
conta $? "arnes compilado (gcc do PC, -Werror)"
mkdir -p "$T/arnes_tmp"
"$T/arnes" "$T/arnes_tmp" > "$T/arnes.log" 2>&1; r=$?
sed 's/^/      /' "$T/arnes.log" | grep -v 'falhas:'
conta $r "arnes do m17_nomes.c ($(grep -c '^ok' "$T/arnes.log") casos verdes)"

# --- 3. o jogo
if [ ! -f "$ZIP" ] || ! echo "7790d09a2a3addcd33c66ef063d5900eb81cc9c342f4807eb8356364dd1d9277  $ZIP" | sha256sum --quiet -c 2>/dev/null; then
    conta 1 "Tyrian 2.1 em $ZIP (rode: ports/baixar_conteudo.sh tyrian)"
    echo "falhas: $F"; exit 1
fi
python3 -I -c 'import os, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
for n in z.namelist():
    if not n.endswith("/"):
        open(os.path.join(sys.argv[2], os.path.basename(n).lower()), "wb").write(z.read(n))' "$ZIP" "$T/dados"
conta $? "dados do Tyrian 2.1 extraidos ($(ls "$T/dados" | wc -l) arquivos)"
mkdir -p "$T/cfg/opentyrian"; cp "$CFG" "$T/cfg/opentyrian/"
L="$T/jogo.log"
( cd "$T" && exec env SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software SDL_AUDIODRIVER=dummy \
    XDG_CONFIG_HOME="$T/cfg" LD_LIBRARY_PATH="$T/libs" \
    timeout -k 10 300 qemu-arm-static -L "$EMU_ROOTFS" "$B" --data="$T/dados" ) > "$L" 2>&1 &
P=$!
i=0
while [ $i -lt 240 ] && ! grep -q 'Initializing SDL audio' "$L" 2>/dev/null && kill -0 "$P" 2>/dev/null; do
    sleep 1; i=$((i + 1))
done
grep -q 'Initializing SDL audio' "$L"; conta $? "opentyrian iniciou com os dados (${i} s no qemu)"
! grep -qiE 'ERROR|FATAL' "$L"; conta $? "sem ERROR/FATAL no log"
sleep 3   # deixa o titulo comecar a desenhar
case "$P" in ''|*[!0-9]*) conta 1 "PID do jogo valido"; echo "falhas: $F"; exit 1 ;; esac
kill -TERM "$P" 2>/dev/null
wait "$P"; r=$?
conta $r "UM SIGTERM: opentyrian sai com rc 0 (rc=$r)"
grep -q '\[M17\] saida' "$L"; conta $? "SIGTERM: [M17] saida (fim normal do lancador)"
for a in opentyrian.cfg tyrian.cfg tyrian.sav; do
    [ -s "$T/cfg/opentyrian/$a" ]; conta $? "SIGTERM: $a gravado em XDG_CONFIG_HOME/opentyrian"
done
_d=0
while IFS= read -r linha; do
    case "$linha" in ''|section*) continue ;; esac
    grep -qxF "$linha" "$T/cfg/opentyrian/opentyrian.cfg" || { echo "      falta: $linha"; _d=$((_d + 1)); }
done < "$CFG"
conta $_d "configuracao do produto volta igual no opentyrian.cfg regravado"
grep -qx "section 'joystick' 'i2c-keys'" "$T/cfg/opentyrian/opentyrian.cfg"
conta $? "secao do joystick do aparelho (i2c-keys) mantida"

# --- 3b. o campo de nome pelo teclado virtual (spec 042), sem os menus: M17_TESTE_NOME + roteiro do teclado
printf 'Valquiria\n' > "$T/nomes.txt"
nome_teste() {   # nome_teste QUAL ROTEIRO -> o log em $T/nome_QUAL.log
    printf '%s' "$2" > "$T/nome_$1.rot"
    ( cd "$T" && exec env SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software SDL_AUDIODRIVER=dummy \
        XDG_CONFIG_HOME="$T/cfg_nome" LD_LIBRARY_PATH="$T/libs" M17_NOMES="$T/nomes.txt" M17_TESTE_NOME="$1" \
        M17_TECLADO_ROTEIRO="$T/nome_$1.rot" timeout -k 10 240 qemu-arm-static -L "$EMU_ROOTFS" "$B" --data="$T/dados" ) \
        > "$T/nome_$1.log" 2>&1
}
nome_teste save 'BAS'; r=$?
[ $r -eq 0 ] && grep -q '\[M17\] teclado: aberto \[Valquiria\] (max 14)' "$T/nome_save.log" \
  && grep -q '\[M17\] teste nome: ok \[ValquiriA\]' "$T/nome_save.log"
conta $? "save: o teclado abre com o nome da lista (max 14); B apaga, A digita, START grava (rc=$r)"
nome_teste placar 's'; r=$?
[ $r -eq 0 ] && grep -q '\[M17\] teclado: aberto \[Valquiria\] (max 28)' "$T/nome_placar.log" \
  && grep -q '\[M17\] teste nome: cancelado' "$T/nome_placar.log"
conta $? "placar: o teclado abre com o nome da lista (max 28); SELECT cancela (rc=$r)"

# --- 4. sem os dados
L2="$T/sem_dados.log"
( cd "$T" && exec env SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software SDL_AUDIODRIVER=dummy \
    XDG_CONFIG_HOME="$T/cfg_sem" LD_LIBRARY_PATH="$T/libs" \
    timeout -k 10 120 qemu-arm-static -L "$EMU_ROOTFS" "$B" --data="$T/nao_existe" ) > "$L2" 2>&1
r=$?
[ "$r" -ne 0 ] && [ "$r" -ne 124 ] && [ "$r" -ne 137 ]; conta $? "sem os dados: sai sozinho com erro (rc=$r), sem travar"

echo "falhas: $F"
[ "$F" -eq 0 ]
