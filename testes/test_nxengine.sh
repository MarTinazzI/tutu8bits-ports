#!/usr/bin/env bash
# Spec 030 (T06, CA-01): o NXEngine-evo do projeto (Cave Story) no PC.
#   1. auditoria de ELF de nx, extract e das libs SDL2_mixer/SDL2_image do projeto;
#   2. extract no qemu-arm-static sobre uma copia do freeware (rc 0, stage.dat e pxt gerados);
#   3. nx no qemu com video dummy (renderer por software) e audio dummy, dados pelo NX_DADOS e saves
#      pelo XDG_DATA_HOME isolados em .cache: espera o "Entering main loop" (por condicao, nao por
#      tempo fixo), manda SIGTERM e confere o fechamento em ordem (o fim normal do lancar.sh, D-09).
# O freeware fica fora do repositorio: ports/baixar_conteudo.sh cavestory (sem ele, FALHA, como as
# ROMs do test_lote2). Nada e gravado fora de .cache/emu/testes/nxengine.
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
. "$D/../../src/emu/ambiente.sh"
OUTN="$EMU_CACHE/out/nxengine"
ZIP="$EMU_CACHE/conteudo/cavestory/cavestoryen.zip"
T="$EMU_CACHE/testes/nxengine"
F=0
conta() { if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FALHA $2"; F=$((F + 1)); fi; }
ulimit -c 0

# libs como no cartao (tutu8bits/lib): a libSDL2 do projeto e as duas novas
rm -rf "$T"; mkdir -p "$T/libs" "$T/saves"
cp "$EMU_CACHE/out/sdl2_projeto/libSDL2-2.0.so.0" "$EMU_CACHE/out/sdl2_mixer/libSDL2_mixer-2.0.so.0" \
    "$EMU_CACHE/out/sdl2_image/libSDL2_image-2.0.so.0" "$T/libs/"
conta $? "libs do projeto copiadas (sdl2_projeto, sdl2_mixer, sdl2_image)"

for b in "$OUTN/nx" "$OUTN/extract" "$T/libs/libSDL2_mixer-2.0.so.0" "$T/libs/libSDL2_image-2.0.so.0"; do
    out=$("$D/../../src/emu/testes/auditar_elf.sh" "$b" "$T/libs"); r=$?
    conta $r "auditoria de ELF: $(basename "$b")"
    [ $r -eq 0 ] || echo "$out" | grep FALHA
done
"$READELF" -d "$OUTN/nx" | grep -qiE 'NEEDED.*(X11|xcb|wayland|libGL\.so|jpeg)'
conta $((1 - $?)) "nx sem X11/Wayland/OpenGL de PC/JPEG"
# padroes do aparelho (patch nxengine-m17-01, D-04): botoes do i2c-keys (KB §11k) e o log de cada botao
P01="$EMU_RAIZ/ports/patches/nxengine-m17-01-padroes.patch"
_b=$(grep -cE '^\+  mappings\[(UPKEY|DOWNKEY|LEFTKEY|RIGHTKEY|JUMPKEY|FIREKEY|INVENTORYKEY|ESCKEY|MAPSYSTEMKEY|PREVWPNKEY|NEXTWPNKEY)\]\.jbut += (13|16|14|15|6|11|9|5|4|7|3);' "$P01")
[ "$_b" -eq 11 ]; conta $? "patch 01: 11 botoes do i2c-keys ($_b)"
_s=$(strings "$OUTN/nx" | grep -c '\[M17\] botao'); [ "$_s" -ge 1 ]; conta $? "nx anota no log cada botao apertado ([M17] botao N)"
[ -f "$OUTN/data/sprites.sif" ] && [ -f "$OUTN/data/system.json" ]
conta $? "data/ do motor ao lado do binario"

# --- 2. extract
if [ ! -f "$ZIP" ] || ! echo "aa87fa30bee9b4980640c7e104791354e0f1f6411ee0d45a70af70046aa0685f  $ZIP" | sha256sum --quiet -c 2>/dev/null; then
    conta 1 "freeware em $ZIP (rode: ports/baixar_conteudo.sh cavestory)"
    echo "falhas: $F"; exit 1
fi
python3 -I -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$ZIP" "$T"
conta $? "freeware descompactado"
J="$T/CaveStory"
[ ! -e "$J/data/stage.dat" ]; conta $? "antes do extract nao ha data/stage.dat"
( cd "$J" && LD_LIBRARY_PATH="$T/libs" timeout 120 qemu-arm-static -L "$EMU_ROOTFS" "$OUTN/extract" ) > "$T/extract.log" 2>&1
conta $? "extract rc 0 ($(du -sk "$J/data" 2>/dev/null | cut -f1) KB em data/ depois)"
grep -q 'Sucessfully extracted' "$T/extract.log"; conta $? "extract: 'Sucessfully extracted.'"
[ -s "$J/data/stage.dat" ]; conta $? "extract gerou data/stage.dat"
n=$(ls "$J/data/pxt" 2>/dev/null | wc -l); [ "$n" -gt 50 ]; conta $? "extract gerou os efeitos (data/pxt: $n)"

# --- 3. o jogo
L="$T/nx.log"
( cd "$OUTN" && exec env SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software SDL_AUDIODRIVER=dummy \
    XDG_DATA_HOME="$T/saves" NX_DADOS="$J/data/" LD_LIBRARY_PATH="$T/libs" \
    timeout -k 10 300 qemu-arm-static -L "$EMU_ROOTFS" ./nx ) > "$L" 2>&1 &
P=$!
i=0
while [ $i -lt 240 ] && ! grep -q 'Entering stage' "$L" 2>/dev/null && kill -0 "$P" 2>/dev/null; do
    sleep 1; i=$((i + 1))
done
grep -q 'Entering main loop' "$L"; conta $? "nx chegou ao laco principal (fase em ${i} s no qemu)"
grep -q 'using: software renderer' "$L"; conta $? "nx abriu o renderer"
grep -q 'Organya init done' "$L"; conta $? "nx iniciou a musica (Organya)"
grep -q "Entering stage" "$L"; conta $? "nx carregou uma fase dos dados do jogo (NX_DADOS)"
grep -E '\[(critical|error)\]' "$L" | grep -v 'settings.dat' > "$T/erros.txt"
[ ! -s "$T/erros.txt" ]; conta $? "sem [critical]/[error] alem do settings.dat ausente ($(wc -l < "$T/erros.txt"))"
[ -f "$T/saves/nxengine/debug.log" ]; conta $? "pasta do usuario em XDG_DATA_HOME/nxengine"
case "$P" in ''|*[!0-9]*) conta 1 "PID do jogo valido"; echo "falhas: $F"; exit 1 ;; esac
kill -TERM "$P" 2>/dev/null
wait "$P"; r=$?
conta $r "SIGTERM: nx sai com rc 0 (rc=$r)"
grep -q 'Script engine shutdown' "$L" && grep -q 'Renderer::Close()' "$L"
conta $? "SIGTERM: fechamento em ordem no log (fim normal do lancador)"

# --- 4. sem NX_DADOS (patch nxengine-m17-02): o motor nao acha o jogo e sai com erro, sem travar
L2="$T/sem_dados.log"
( cd "$OUTN" && exec env SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software SDL_AUDIODRIVER=dummy \
    XDG_DATA_HOME="$T/saves_sem" LD_LIBRARY_PATH="$T/libs" \
    timeout -k 10 120 qemu-arm-static -L "$EMU_ROOTFS" ./nx ) > "$L2" 2>&1
r=$?
[ "$r" -ne 0 ] && [ "$r" -ne 124 ] && [ "$r" -ne 137 ]; conta $? "sem NX_DADOS: sai sozinho com erro (rc=$r), sem travar"
! grep -q 'Entering stage' "$L2"; conta $? "sem NX_DADOS: nenhuma fase carregada (os dados vem so do NX_DADOS)"

echo "falhas: $F"
[ "$F" -eq 0 ]
