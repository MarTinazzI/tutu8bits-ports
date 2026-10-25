#!/bin/sh
# ==============================================================================
# tutu8bits-ports — teste da licenca dos patches (spec 053, emenda 1, TE06; CA-E05): cada arquivo de ports/patches/ tem
# a linha "Licenca:" no comeco, aparece na tabela de ports/patches/LEIA-ME.md e continua um patch legivel pelo git.
# Uso: sh ports/testes/test_patches_licenca.sh
# ==============================================================================
D=$(cd "$(dirname "$0")" && pwd)
P="$D/../patches"
FALHAS=0
ok()    { echo "  ok    $1"; }
falha() { echo "  FALHA $1"; FALHAS=$((FALHAS + 1)); }
echo "test_patches_licenca.sh"
sem_linha=""; fora=""; ilegivel=""; n=0
for f in "$P"/*.patch "$P"/*.py; do
    [ -e "$f" ] || continue
    b=$(basename "$f"); n=$((n + 1))
    head -3 "$f" | grep -q 'Licença: ' || sem_linha="$sem_linha $b"
    case "$b" in
        *.patch) pre="${b%%-*}"; grep -q "\`$pre-\*\`" "$P/LEIA-ME.md" || fora="$fora $b"
                 git apply --stat "$f" > /dev/null 2>&1 || ilegivel="$ilegivel $b" ;;
        *.py)    grep -q "\`$b\`" "$P/LEIA-ME.md" || fora="$fora $b" ;;
    esac
done
[ "$n" -gt 0 ] && [ -z "$sem_linha" ] && ok "$n arquivos com a linha Licença:" || falha "sem a linha Licença:$sem_linha"
[ -z "$fora" ] && ok "todos na tabela do LEIA-ME" || falha "fora da tabela:$fora"
[ -z "$ilegivel" ] && ok "todos os .patch legiveis pelo git apply" || falha "ilegiveis:$ilegivel"
echo "falhas: $FALHAS"
[ "$FALHAS" -eq 0 ]
