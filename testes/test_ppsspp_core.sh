#!/usr/bin/env bash
# T04 (spec 023, candidato A): o nucleo libretro do PPSSPP leva o FFmpeg minimo do projeto (D-02) e o
# patch da velocidade no log (D-05). A carga da ISO no qemu fica no test_lote2.sh (spec 010); a
# auditoria de ELF (so bibliotecas do aparelho) no test_nucleos.sh. Termina com "falhas: N".
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
. "$D/../../src/emu/ambiente.sh"
F=0
conta() { if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FALHA $2"; F=$((F + 1)); fi; }

SO="$EMU_CACHE/out/cores/ppsspp_libretro.so"
if [ ! -f "$SO" ]; then conta 1 "nucleo existe ($SO)"; echo "falhas: $F"; exit 1; fi
TXT=$(strings "$SO")
grep -q '^Lavf[0-9]' <<< "$TXT"; conta $? "FFmpeg (libavformat) ligado ao nucleo"
grep -q 'atrac3plus' <<< "$TXT"; conta $? "FFmpeg com o decodificador ATRAC3+"
grep -q '^\[M17\] %s vps=%.2f fps=%.2f desenhado=%.2f segundos=%.1f' <<< "$TXT"; conta $? "patch ppsspp-m17-01-fps (linha [M17] psp no log)"
! grep -qE 'libav|libsw' <<< "$("$READELF" -d "$SO")"; conta $? "FFmpeg estatico (sem libav*/libsw* no NEEDED)"
grep -q "^cores/ppsspp_libretro.so|$(sha256sum "$SO" | cut -d' ' -f1)|.*-DUSE_FFMPEG=ON" "$EMU_RAIZ/ports/manifesto.txt"
conta $? "manifesto com o sha256 do nucleo e USE_FFMPEG=ON"

echo "falhas: $F"
[ "$F" -eq 0 ]
