#!/usr/bin/env bash
# ==============================================================================
# tutu8bits — monta o pacote publicavel (spec 011, RF-22..RF-24; plano D-16; spec 028). Roda no PC.
#
#   .cache/pacote/tutu8bits-<versao>/      copia do cartao/ completo (a raiz do cartao)
#   .cache/pacote/tutu8bits-<versao>.zip   o mesmo, compactado
#
# Spec 028: o cartao/ do repositorio E a raiz do cartao. Este script so (1) completa o cartao/ com o
# que e compilado ou gerado (ports/completar_cartao.sh), (2) copia o cartao/ para a area de montagem,
# sem o que e criado em uso (D-09), (3) audita contra a fabrica e (4) compacta.
# Nada de fabrica: todo binario de terceiros e compilado pelo projeto; a auditoria compara o
# sha256 de cada arquivo com a copia do cartao de fabrica (FABRICA) e falha se algum bater.
#
# Antes: src/emu/build.sh (RetroArch, nucleos, sdl2_projeto), src/motor/build.sh e
#        src/nativos/build.sh (bootscreen, m17atalhos, lebateria, medir013).
# Depois, para publicar a versao: ports/fontes.sh (o codigo-fonte de cada componente, spec 053).
# Uso: ports/montar.sh [--sem-zip]
# Variaveis: FABRICA (padrao ~/m17/emuelec/original/sistema), TUTU_REPOSITORIO (endereco publico
#            do codigo, citado no LEIA-ME das licencas).
# ==============================================================================
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
CARTAO="$REPO/cartao"
OUT="$REPO/.cache/emu/out"
FABRICA="${FABRICA:-$HOME/m17/emuelec/original/sistema}"
VERSAO=$(sed -n 's/^#define TUTU_VERSAO "\(.*\)"/\1/p' "$REPO/src/motor/motor.h")
NOME="tutu8bits-$VERSAO"
BASE="$REPO/.cache/pacote"
S="$BASE/$NOME"
ZIP=1
[ "${1:-}" = --sem-zip ] && ZIP=0
[ -n "$VERSAO" ] || { echo "ERRO: versao nao encontrada em src/motor/motor.h" >&2; exit 1; }

"$REPO/ports/completar_cartao.sh"

# area de montagem limpa (so dentro de .cache/pacote)
case "$S" in "$REPO/.cache/pacote/tutu8bits-"*) ;; *) echo "ERRO: caminho de montagem inesperado: $S" >&2; exit 1 ;; esac
rm -rf "$S"
mkdir -p "$S"
# o cartao/ inteiro, menos o que e do usuario ou criado em uso (D-09, pacote/cartao.filtro)
rsync -r --filter="merge $REPO/pacote/cartao.filtro" "$CARTAO/" "$S/"

# ---------------------------------------------------------------- licencas: todo arquivo com a sua (spec 053, D-06)
"$REPO/ports/conferir_licencas.sh" "$S/tutu8bits" > "$BASE/licencas.txt" 2>&1 \
    || { echo "ERRO: arquivo(s) do pacote sem licenca (ports/licencas.tsv):" >&2; grep -v '^  ok' "$BASE/licencas.txt" >&2; exit 1; }
echo "  ok  licencas: $(sed -n 's/^  ok    //p' "$BASE/licencas.txt")"

# ---------------------------------------------------------------- auditoria: nada de fabrica
if [ -d "$FABRICA" ]; then
    find "$FABRICA" -type f -size +0 -print0 | xargs -0 sha256sum 2>/dev/null | cut -d' ' -f1 | sort -u > "$BASE/fabrica.todos.sha256"
    # Arquivos de origem publica que o fabricante tambem copiou (spec 023, plano D-13): os assets do
    # PPSSPP (fontes da flash0, shaders, atlas) que o NOSSO build baixou do repositorio do PPSSPP
    # (src/emu/versoes.txt, ref fixada) sao byte a byte iguais aos do PPSSPP de fabrica. A procedencia vem
    # do build, entao esses hashes saem da lista da fabrica; qualquer outro arquivo igual segue barrado.
    # Spec 049: o mesmo vale para os textos de licenca que o completar_cartao.sh copia dos fontes fixados para
    # LICENCAS/ (o LICENSE do Geargrafx, que entrou e saiu na 049, era o texto oficial da GPL-3, igual ao
    # doc/gpl-3.0.txt do SDLPoP de fabrica).
    { find "$OUT/system/PPSSPP" -type f -size +0 -print0 | xargs -0 sha256sum | cut -d' ' -f1
      for f in "$CARTAO"/tutu8bits/LICENCAS/*; do [ -f "$f" ] && sha256sum "$f" | cut -d' ' -f1; done
    } | sort -u > "$BASE/publicos.sha256"
    comm -23 "$BASE/fabrica.todos.sha256" "$BASE/publicos.sha256" > "$BASE/fabrica.sha256"
    echo "  ok  auditoria: $(comm -12 "$BASE/fabrica.todos.sha256" "$BASE/publicos.sha256" | wc -l) arquivos publicos (PPSSPP ppsspp@$(awk -F'|' '$1=="ppsspp" {print substr($4,1,7)}' "$REPO/ports/versoes.txt") e textos de licenca) iguais aos da fabrica aceitos pela procedencia"
    find "$S" -type f -size +0 -print0 | xargs -0 sha256sum | sort > "$BASE/pacote.sha256"
    if cut -d' ' -f1 "$BASE/pacote.sha256" | sort -u | comm -12 - "$BASE/fabrica.sha256" | grep -q .; then
        echo "ERRO: arquivo(s) do sistema de fabrica no pacote:" >&2
        cut -d' ' -f1 "$BASE/pacote.sha256" | sort -u | comm -12 - "$BASE/fabrica.sha256" | while read -r h; do grep "^$h" "$BASE/pacote.sha256"; done >&2
        exit 1
    fi
    echo "  ok  auditoria: nenhum dos $(wc -l < "$BASE/pacote.sha256") arquivos bate com os $(wc -l < "$BASE/fabrica.sha256") da fabrica"
else
    echo "  AVISO: sem a copia de fabrica em $FABRICA; auditoria por sha256 nao rodou"
fi
if find "$S" \( -name 'lib_3168' -o -name 'PPSSPPSDL' -o -name 'emulationstation' \) | grep -q .; then
    echo "ERRO: nome de arquivo de fabrica no pacote" >&2; exit 1
fi

# ---------------------------------------------------------------- zip
if [ "$ZIP" = 1 ]; then
    rm -f "$BASE/$NOME.zip"
    ( cd "$S" && zip -qr -X "$BASE/$NOME.zip" . )
    echo "  ok  $BASE/$NOME.zip ($(du -h "$BASE/$NOME.zip" | cut -f1))"
fi
echo "  ok  $S ($(find "$S" -type f | wc -l) arquivos)"
