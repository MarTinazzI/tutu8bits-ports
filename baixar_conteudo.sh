#!/usr/bin/env bash
# Baixa o conteudo de teste listado em ports/conteudo/<sistema>.txt para .cache/emu/conteudo/<sistema>/
# e confere o sha256 (spec 010, plano D-08). Cartuchos e ROMs nunca vao para o git.
# Uso: ports/baixar_conteudo.sh [sistema...]   (padrao: todos os arquivos de ports/conteudo/)
set -euo pipefail
. "$(dirname "$0")/../src/emu/ambiente.sh"
LISTAS=("$@"); [ ${#LISTAS[@]} -gt 0 ] || LISTAS=($(cd "$EMU_RAIZ/ports/conteudo" && ls *.txt | sed 's/\.txt$//'))
falhas=0
for s in "${LISTAS[@]}"; do
    d="$EMU_CACHE/conteudo/$s"; mkdir -p "$d"
    while IFS='|' read -r arq url autor lic sha; do
        case "$arq" in ''|\#*) continue ;; esac
        if [ ! -f "$d/$arq" ] || ! echo "$sha  $d/$arq" | sha256sum --quiet -c 2>/dev/null; then
            curl -fsSL --retry 3 -o "$d/$arq.tmp" "$url" && mv "$d/$arq.tmp" "$d/$arq"
        fi
        if echo "$sha  $d/$arq" | sha256sum --quiet -c 2>/dev/null; then echo "  ok  $s/$arq ($lic)"
        else echo "  FALHA  $s/$arq: sha256 diferente"; falhas=$((falhas + 1)); fi
    done < "$EMU_RAIZ/ports/conteudo/$s.txt"
done
[ "$falhas" -eq 0 ]
