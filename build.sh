#!/usr/bin/env bash
# ==============================================================================
# tutu8bits-ports — compila os emuladores, ports e bibliotecas e completa o cartao/ do tutu8bits (spec 053, emenda 1).
#
#   ports/build.sh                     menu: 1) todos, depois cada componente; escolha "3 5 8", "3-7" ou "1"
#   ports/build.sh todos               tudo, sem perguntar
#   ports/build.sh nethack crispy_doom so esses, sem perguntar
#   ports/build.sh --lista             so mostra o menu
#   ports/build.sh --sem-completar ... nao roda o completar_cartao.sh no fim
#
# Este repositorio fica dentro do tutu8bits, em <tutu8bits>/ports/ (o ./ports.sh do tutu8bits clona aqui); outro lugar:
# TUTU8BITS=<pasta do tutu8bits>. Usa a maquina de build do tutu8bits (src/emu/build.sh: baixa o fonte na versao de
# ports/versoes.txt, aplica ports/patches/, compila pela ports/receitas/). Nada e instalado no sistema.
# "todos" tambem baixa os cabecalhos e o conteudo livre (ports/baixar_conteudo.sh) e a SDL2 do tutu8bits.
# Variaveis para testes: PORTS_BUILD, PORTS_CABECALHOS, PORTS_CONTEUDO, PORTS_COMPLETAR (os comandos chamados).
# ==============================================================================
set -uo pipefail
PB_DIR="$(cd "$(dirname "$0")" && pwd)"
TUTU="${TUTU8BITS:-$(cd "$PB_DIR/.." && pwd)}"
[ -f "$TUTU/src/emu/build.sh" ] || { echo "ERRO: tutu8bits nao encontrado em $TUTU (TUTU8BITS=<pasta>)" >&2; exit 2; }
PB_BUILD="${PORTS_BUILD:-$TUTU/src/emu/build.sh}"
PB_CABECALHOS="${PORTS_CABECALHOS:-$TUTU/src/emu/cabecalhos.sh}"
PB_CONTEUDO="${PORTS_CONTEUDO:-$PB_DIR/baixar_conteudo.sh}"
PB_COMPLETAR="${PORTS_COMPLETAR:-$PB_DIR/completar_cartao.sh}"
export TUTU_PORTS="$PB_DIR"

# a lista: grupo|nome|descricao, na ordem em que "todos" compila (bibliotecas antes de quem as usa)
pb_desc() {   # receita -> 1a linha de comentario, sem as referencias internas "(spec ..)" / "(plano ..)"
    sed -n '1s/^# *//p' "$1" | sed -E 's/ *\([^)]*(spec|plano|SP-)[^)]*\)//g; s/[:.]$//' | cut -c1-70
}
pb_lista() {
    echo "Bibliotecas|sdl2_projeto|$(pb_desc "$TUTU/src/emu/receitas/sdl2_projeto.sh")"
    local grupo tipos t n
    for grupo in "Bibliotecas:biblioteca" "RetroArch e nucleos:frontend nucleo" "Ports e programas:programa"; do
        tipos="${grupo#*:}"
        for t in $tipos; do
            for n in $(awk -F'|' -v t="$t" '!/^#/ && $2==t {print $1}' "$PB_DIR/versoes.txt"); do
                [ -f "$PB_DIR/receitas/$n.sh" ] && echo "${grupo%%:*}|$n|$(pb_desc "$PB_DIR/receitas/$n.sh")"
            done
        done
    done
}
mapfile -t PB_ITENS < <(pb_lista)

pb_menu() {
    local i=1 g="" item grupo nome desc
    printf '  %3d) %s\n' 1 "todos (cabecalhos, conteudo livre e tudo abaixo)"
    for item in "${PB_ITENS[@]}"; do
        IFS='|' read -r grupo nome desc <<< "$item"
        [ "$grupo" != "$g" ] && { printf '\n  %s\n' "$grupo"; g="$grupo"; }
        i=$((i + 1))
        printf '  %3d) %-20s %s\n' "$i" "$nome" "$desc"
    done
}

pb_nome() { local item="${PB_ITENS[$(($1 - 2))]}"; item="${item#*|}"; echo "${item%%|*}"; }

# "3 5 8", "3-7", "1" -> nomes (ou TODOS); devolve 1 se algo nao for valido
pb_escolha() {
    local tok a b i max=$((${#PB_ITENS[@]} + 1)) saida=""
    for tok in $(echo "$1" | tr ',' ' '); do
        case "$tok" in
            1) echo TODOS; return 0 ;;
            *-*) a="${tok%-*}"; b="${tok#*-}" ;;
            *) a="$tok"; b="$tok" ;;
        esac
        case "$a$b" in *[!0-9]*|'') return 1 ;; esac
        { [ "$a" -ge 2 ] && [ "$b" -le "$max" ] && [ "$a" -le "$b" ]; } || return 1
        for ((i = a; i <= b; i++)); do saida="$saida $(pb_nome "$i")"; done
    done
    [ -n "$saida" ] || return 1
    echo "$saida"
}

COMPLETAR=1; ESCOLHA=""
while [ $# -gt 0 ]; do
    case "$1" in
        --lista) pb_menu; exit 0 ;;
        --sem-completar) COMPLETAR=0 ;;
        -h|--help) sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        todos) ESCOLHA=TODOS ;;
        -*) echo "opcao desconhecida: $1" >&2; exit 2 ;;
        *) printf '%s\n' "${PB_ITENS[@]}" | cut -d'|' -f2 | grep -qx "$1" || { echo "componente desconhecido: $1 (veja --lista)" >&2; exit 2; }
           ESCOLHA="$ESCOLHA $1" ;;
    esac
    shift
done

if [ -z "$ESCOLHA" ]; then
    echo "tutu8bits-ports: o que compilar?"
    pb_menu
    while :; do
        printf '\nNumeros (ex.: 1 | 3 5 8 | 3-7), ou q para sair: '
        read -r resp || { echo; exit 1; }
        [ "$resp" = q ] && exit 0
        ESCOLHA=$(pb_escolha "$resp") && break
        echo "  escolha invalida: \"$resp\""
    done
fi

if [ "$ESCOLHA" = TODOS ]; then
    NOMES=$(printf '%s\n' "${PB_ITENS[@]}" | cut -d'|' -f2 | tr '\n' ' ')
    echo "==> cabecalhos e conteudo livre"
    "$PB_CABECALHOS" || exit 1
    "$PB_CONTEUDO" || exit 1
else
    NOMES="$ESCOLHA"
fi
echo "==> compilar:$(printf ' %s' $NOMES)"
# shellcheck disable=SC2086
"$PB_BUILD" $NOMES || { echo "ERRO: o build parou (logs em $TUTU/.cache/emu/logs/)" >&2; exit 1; }

if [ "$COMPLETAR" = 1 ]; then
    echo "==> completar o cartao/ do tutu8bits"
    if ! "$PB_COMPLETAR"; then
        echo "AVISO: o cartao/ nao foi completado (falta algum componente; para tudo: ports/build.sh todos)" >&2
        exit 1
    fi
fi
echo "  ok"
