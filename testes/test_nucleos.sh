#!/usr/bin/env bash
# T03 (spec 009): cada nucleo de versoes.txt existe em .cache/emu/out/cores, passa na auditoria
# de ELF e aparece no manifesto com sha256 igual ao do arquivo. Termina com "falhas: N".
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
. "$D/../../src/emu/ambiente.sh"
M="$EMU_RAIZ/ports/manifesto.txt"
F=0
conta() { if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FALHA $2"; F=$((F + 1)); fi; }

for n in $(awk -F'|' '!/^#/ && $2=="nucleo" {print $1}' "$EMU_RAIZ/ports/versoes.txt"); do
    so="$EMU_CACHE/out/cores/${n}_libretro.so"
    if [ ! -f "$so" ]; then conta 1 "$n: binario existe"; continue; fi
    out=$("$D/../../src/emu/testes/auditar_elf.sh" "$so"); r=$?
    conta $r "$n: auditoria de ELF ($(stat -c %s "$so") bytes)"
    [ $r -eq 0 ] || echo "$out" | grep FALHA
    sha=$(sha256sum "$so" | cut -d' ' -f1)
    grep -q "^cores/${n}_libretro.so|$sha|" "$M"; conta $? "$n: manifesto com o sha256 do arquivo"
    grep -q "^cores/${n}_libretro.so|.*|.*|$n|[0-9a-f]\{40\}|[^|]\+|" "$M"; conta $? "$n: manifesto com ref e licenca"
done
echo "falhas: $F"
[ "$F" -eq 0 ]
