#!/usr/bin/env bash
# ==============================================================================
# tutu8bits — confere a licenca de cada arquivo do pacote (spec 053, D-06; RF-07, RF-13). Roda no PC.
#
#   ports/conferir_licencas.sh <tutu8bits/>     (padrao: cartao/tutu8bits do repositorio)
#
# Pela tabela ports/licencas.tsv, falha se (a) um arquivo de cores/ bin/ lib/ jogos/ gametank/ ppsspp/ retroarch/
# midi/ nao casar com nenhuma linha, (b) um arquivo de licenca citado faltar ou estiver vazio, (c) o componente nao
# aparecer em LICENCAS/LEIA-ME.md ou (d) um componente da coluna fonte nao existir em src/emu/versoes.txt.
# Saida: "  ok"/"  FALHA <arquivo>: <motivo>" e "falhas: N"; sai 1 se N > 0. Variavel: LICENCAS_TSV (outra tabela).
# ==============================================================================
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
G="${1:-$REPO/cartao/tutu8bits}"
TSV="${LICENCAS_TSV:-$REPO/ports/licencas.tsv}"
VERSOES="$REPO/src/emu/versoes.txt"; VERSOES_P="$REPO/ports/versoes.txt"   # os dois catalogos (spec 053, emenda 1)
PASTAS="cores bin lib jogos gametank ppsspp retroarch midi"
cl_falhas=0
cl_falha() { echo "  FALHA $1"; cl_falhas=$((cl_falhas + 1)); }

[ -d "$G/LICENCAS" ] || { echo "  FALHA $G/LICENCAS: nao existe (rode ports/completar_cartao.sh)"; echo "falhas: 1"; exit 1; }
[ -f "$TSV" ] || { echo "  FALHA $TSV: nao existe"; echo "falhas: 1"; exit 1; }

cl_pad=(); cl_comp=(); cl_lic=(); cl_fon=()
while IFS='|' read -r c1 c2 c3 c4; do
    case "$c1" in ''|\#*) continue ;; esac
    cl_pad+=("$c1"); cl_comp+=("$c2"); cl_lic+=("$c3"); cl_fon+=("$c4")
done < "$TSV"

# (b), (c), (d): por linha da tabela
cl_usada=()
for i in "${!cl_pad[@]}"; do
    cl_usada[$i]=0
    IFS=',' read -ra cl_arqs <<< "${cl_lic[$i]}"
    for a in "${cl_arqs[@]}"; do
        [ -s "$G/LICENCAS/$a" ] || cl_falha "LICENCAS/$a: licenca de ${cl_comp[$i]} faltando ou vazia"
    done
    grep -qF -- "${cl_comp[$i]}" "$G/LICENCAS/LEIA-ME.md" 2>/dev/null \
        || cl_falha "${cl_comp[$i]}: nao aparece em LICENCAS/LEIA-ME.md"
    if [ "${cl_fon[$i]}" != "-" ]; then
        IFS=',' read -ra cl_fs <<< "${cl_fon[$i]}"
        for f in "${cl_fs[@]}"; do
            grep -q "^$f|" "$VERSOES" "$VERSOES_P" || cl_falha "$f: componente de fonte de ${cl_comp[$i]} sem linha em src/emu/versoes.txt"
        done
    fi
done

# (a): cada arquivo das pastas do pacote casa com alguma linha
cl_n=0
while IFS= read -r -d '' f; do
    r="${f#"$G"/}"; cl_n=$((cl_n + 1)); achou=""
    for i in "${!cl_pad[@]}"; do
        # shellcheck disable=SC2254
        case "$r" in ${cl_pad[$i]}) achou=1; cl_usada[$i]=1; break ;; esac
    done
    [ -n "$achou" ] || cl_falha "$r: sem licenca em ports/licencas.tsv"
done < <(cd "$G" && for p in $PASTAS; do [ -d "$p" ] && find "$G/$p" \( -type f -o -type l \) -print0; done)

for i in "${!cl_pad[@]}"; do
    [ "${cl_usada[$i]}" = 1 ] || echo "  aviso linha sem arquivo no pacote: ${cl_pad[$i]}"
done
[ "$cl_falhas" = 0 ] && echo "  ok    $cl_n arquivos do pacote com licenca (${#cl_pad[@]} linhas em licencas.tsv)"
echo "falhas: $cl_falhas"
[ "$cl_falhas" = 0 ]
