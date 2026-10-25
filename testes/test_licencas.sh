#!/bin/sh
# ==============================================================================
# tutu8bits — teste da licenca de cada arquivo do pacote (spec 053, T03; CA-05): o ports/conferir_licencas.sh passa
# no cartao/tutu8bits completo e pega, numa copia por hardlink, um nucleo sem licenca, um texto de licenca apagado e
# um componente que sumiu do LEIA-ME.
# Uso: sh ports/testes/test_licencas.sh   (antes: ports/completar_cartao.sh)
# ==============================================================================
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
G="$REPO/cartao/tutu8bits"
CL="$REPO/ports/conferir_licencas.sh"
mkdir -p "$REPO/.cache/testes"
TMP="$(mktemp -d "$REPO/.cache/testes/licencas.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
FALHAS=0
ok()    { echo "  ok    $1"; }
falha() { echo "  FALHA $1"; FALHAS=$((FALHAS + 1)); }

echo "test_licencas.sh"
# o completar_cartao.sh (chamado pelo test_pacote e pelo test_levar no -j) troca arquivos do cartao/ por rsync: le sob
# a trava dele, compartilhada, para nunca pegar um temporario no meio
exec 9> "$REPO/.cache/completar_cartao.trava"
flock -s 9
"$CL" "$G" > "$TMP/real.txt" 2>&1 \
    && ok "pacote real: $(sed -n 's/^  ok    //p' "$TMP/real.txt")" || { falha "pacote real"; cat "$TMP/real.txt"; }

# copia por hardlink: arquivo novo e rm sao seguros; nunca escrever por cima de um arquivo copiado
C="$TMP/tutu8bits"
cp -al "$G" "$C"

echo x > "$C/cores/novo_libretro.so"
"$CL" "$C" > "$TMP/novo.txt" 2>&1
[ $? -ne 0 ] && grep -q 'FALHA cores/novo_libretro.so: sem licenca' "$TMP/novo.txt" \
    && ok "nucleo sem licenca plantado: barrado com o nome do arquivo" || { falha "nucleo plantado"; cat "$TMP/novo.txt"; }
rm "$C/cores/novo_libretro.so"

rm "$C/LICENCAS/parallel_n64-angrylion-MAME-nao-comercial.txt"
"$CL" "$C" > "$TMP/apagada.txt" 2>&1
[ $? -ne 0 ] && grep -q 'FALHA LICENCAS/parallel_n64-angrylion-MAME-nao-comercial.txt' "$TMP/apagada.txt" \
    && ok "texto de licenca apagado: barrado" || { falha "licenca apagada"; cat "$TMP/apagada.txt"; }
cp "$G/LICENCAS/parallel_n64-angrylion-MAME-nao-comercial.txt" "$C/LICENCAS/"

sed 's/Beetle NeoPop/Beetle XXX/g' "$G/LICENCAS/LEIA-ME.md" > "$TMP/leia.md"
rm "$C/LICENCAS/LEIA-ME.md"; cp "$TMP/leia.md" "$C/LICENCAS/LEIA-ME.md"
"$CL" "$C" > "$TMP/leiame.txt" 2>&1
[ $? -ne 0 ] && grep -q 'FALHA Beetle NeoPop: nao aparece' "$TMP/leiame.txt" \
    && ok "componente fora do LEIA-ME: barrado" || { falha "LEIA-ME"; cat "$TMP/leiame.txt"; }

echo "falhas: $FALHAS"
[ "$FALHAS" -eq 0 ]
