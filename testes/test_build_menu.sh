#!/bin/sh
# ==============================================================================
# tutu8bits-ports — teste do build interativo (spec 053, emenda 1, TE04; CA-E07): o ports/build.sh com comandos falsos
# (PORTS_BUILD, PORTS_CABECALHOS, PORTS_CONTEUDO, PORTS_COMPLETAR so registram a chamada). Nada e compilado.
# Uso: sh ports/testes/test_build_menu.sh
# ==============================================================================
D=$(cd "$(dirname "$0")" && pwd)
B="$D/../build.sh"
REPO="$(cd "$D/../.." && pwd)"
mkdir -p "$REPO/.cache/testes"
TMP="$(mktemp -d "$REPO/.cache/testes/build_menu.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
FALHAS=0
ok()    { echo "  ok    $1"; }
falha() { echo "  FALHA $1"; FALHAS=$((FALHAS + 1)); }
echo "test_build_menu.sh"
L="$TMP/chamadas"
for c in build cabecalhos conteudo completar; do
    printf '#!/bin/sh\necho "%s $*" >> "%s"\n' "$c" "$L" > "$TMP/$c"; chmod +x "$TMP/$c"
done
export PORTS_BUILD="$TMP/build" PORTS_CABECALHOS="$TMP/cabecalhos" PORTS_CONTEUDO="$TMP/conteudo" PORTS_COMPLETAR="$TMP/completar"
roda() { : > "$L"; "$B" "$@" > "$TMP/saida" 2>&1; echo $? > "$TMP/rc"; }
rc() { cat "$TMP/rc"; }

"$B" --lista > "$TMP/lista"
[ "$(sed -n '1p' "$TMP/lista" | sed 's/^ *//')" = "1) todos (cabecalhos, conteudo livre e tudo abaixo)" ] \
  && grep -q ' 2) sdl2_projeto ' "$TMP/lista" && grep -q ') nethack ' "$TMP/lista" && grep -q ') retroarch ' "$TMP/lista" \
    && ok "--lista: \"1) todos\" primeiro, a SDL2 do tutu8bits como 2, nucleos e ports" || { falha "--lista"; head -5 "$TMP/lista"; }
N=$(grep -c '^ *[0-9]\+) ' "$TMP/lista")

roda todos
[ "$(rc)" = 0 ] && [ "$(sed -n 1p "$L")" = "cabecalhos " ] && [ "$(sed -n 2p "$L")" = "conteudo " ] \
  && sed -n 3p "$L" | grep -q '^build sdl2_projeto sdl2_mixer' && [ "$(sed -n 3p "$L" | wc -w)" = "$N" ] \
  && [ "$(sed -n 4p "$L")" = "completar " ] \
    && ok "todos: cabecalhos, conteudo, um build com os $((N - 1)) componentes (bibliotecas primeiro) e o completar" || { falha "todos"; cat "$L"; }

roda nethack crispy_doom
[ "$(rc)" = 0 ] && [ "$(sed -n 1p "$L")" = "build nethack crispy_doom" ] && [ "$(sed -n 2p "$L")" = "completar " ] && [ "$(wc -l < "$L")" = 2 ] \
    && ok "por argumento: so os escolhidos, sem cabecalhos/conteudo, e o completar" || { falha "argumentos"; cat "$L"; }

roda --sem-completar rogue
[ "$(rc)" = 0 ] && [ "$(cat "$L")" = "build rogue" ] && ok "--sem-completar: nao completa" || { falha "--sem-completar"; cat "$L"; }

roda nao_existe
[ "$(rc)" = 2 ] && [ ! -s "$L" ] && grep -q 'componente desconhecido: nao_existe' "$TMP/saida" \
    && ok "componente desconhecido: sai 2 sem compilar" || { falha "desconhecido ($(rc))"; cat "$TMP/saida"; }

: > "$L"; printf '3 5\n' | "$B" > "$TMP/saida" 2>&1
[ "$(sed -n 1p "$L")" = "build sdl2_mixer sdl2_ttf" ] && ok "menu: \"3 5\" compila os itens 3 e 5" || { falha "menu 3 5"; cat "$L"; }

: > "$L"; printf '2-4\n' | "$B" > "$TMP/saida" 2>&1
[ "$(sed -n 1p "$L")" = "build sdl2_projeto sdl2_mixer sdl2_image" ] && ok "menu: \"2-4\" compila a faixa" || { falha "menu 2-4"; cat "$L"; }

: > "$L"; printf '1\n' | "$B" > "$TMP/saida" 2>&1
[ "$(sed -n 1p "$L")" = "cabecalhos " ] && [ "$(sed -n 3p "$L" | wc -w)" = "$N" ] && ok "menu: \"1\" = todos" || { falha "menu 1"; cat "$L"; }

: > "$L"; printf '999\nabc\nq\n' | "$B" > "$TMP/saida" 2>&1; r=$?
[ "$r" = 0 ] && [ ! -s "$L" ] && [ "$(grep -c 'escolha invalida' "$TMP/saida")" = 2 ] \
    && ok "menu: escolhas invalidas pedem de novo; q sai sem compilar" || { falha "menu invalido ($r)"; cat "$TMP/saida"; }

echo "falhas: $FALHAS"
[ "$FALHAS" -eq 0 ]
