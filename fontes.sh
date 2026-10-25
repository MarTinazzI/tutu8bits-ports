#!/usr/bin/env bash
# ==============================================================================
# tutu8bits — o codigo-fonte correspondente a uma versao do pacote (spec 053, D-05; RF-09). Roda no PC.
#
#   .cache/pacote/tutu8bits-<versao>-fontes/
#       tutu8bits-<versao>-fontes-<componente>.tar.xz     um por componente de terceiros do pacote, no ref fixado
#       tutu8bits-<versao>-fontes-<componente>.tar.gz     (FreeDink, Lua: o tarball original da versao, conferido)
#       tutu8bits-<versao>-fontes-patches-e-receitas.tar.xz   patches, receitas, versoes.txt e as interfaces do projeto
#       FONTES.txt                                        indice: arquivo|componente|ref|origem|licenca|sha256|bytes
#
# Os componentes saem da coluna "fonte" de ports/licencas.tsv; origem e ref, de src/emu/versoes.txt. O fonte vai
# SEM os patches do projeto (eles vao a parte, como o src/emu/build.sh os aplica). Para um repositorio git, o
# conteudo e o "git archive" do ref e de cada submodulo, tirado do fonte ja baixado pelo build (.cache/emu/src/<n>,
# se estiver no ref) ou de um clone raso novo. Saida deterministica: o mesmo commit gera os mesmos bytes
# (tar --sort=name --mtime=@0, dono 0, xz -T1). Arquivo acima de 1900 MiB e dividido em partes .parte-NN
# (o GitHub aceita ate 2 GiB por arquivo); o FONTES.txt diz como juntar.
#
# Uso: ports/fontes.sh [--so <componente> | --so patches-e-receitas]   (o 2o so refaz esse arquivo e a linha dele
#      no FONTES.txt, depois de um commit que so mexeu no projeto)
# ==============================================================================
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
V="$REPO/src/emu/versoes.txt"; VP="$REPO/ports/versoes.txt"   # os dois catalogos (spec 053, emenda 1)
TSV="$REPO/ports/licencas.tsv"
VERSAO=$(sed -n 's/^#define TUTU_VERSAO "\(.*\)"/\1/p' "$REPO/src/motor/motor.h")
[ -n "$VERSAO" ] || { echo "ERRO: versao nao encontrada em src/motor/motor.h" >&2; exit 1; }
PRE="tutu8bits-$VERSAO-fontes"
SAIDA="$REPO/.cache/pacote/$PRE"
TRAB="$REPO/.cache/pacote/fontes-trabalho"
SO=""
[ "${1:-}" = --so ] && { SO="${2:?uso: ports/fontes.sh [--so <componente>]}"; }
LIMITE=$((1900 * 1024 * 1024))
# componentes de que so uma parte do repositorio e fonte de algo do pacote (o resto sao dados livres ja no pacote)
declare -A SO_PASTAS=([librequake_qc]="qcsrc docs")

campo() { awk -F'|' -v n="$1" -v c="$2" '!/^#/ && $1==n {print $c; exit}' "$V" "$VP"; }
tar_det() {   # destino.tar.xz diretorio-pai nome
    tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner --mode='u+rwX,go+rX,go-w' \
        --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime --format=posix \
        -cf - -C "$2" "$3" | xz -6 -T1 > "$1.tmp"
    mv "$1.tmp" "$1"
}

# fonte pristino de um repositorio git no ref (com submodulos) extraido em $2/<pasta>
extrair_git() {   # nome destino pasta
    local n=$1 dest=$2 pasta=$3 url ref d sub
    url=$(campo "$n" 3); url="${url%% *}"; ref=$(campo "$n" 4)
    d="$REPO/.cache/emu/src/$n"
    if [ -n "${SO_PASTAS[$n]:-}" ] || [ ! -d "$d/.git" ] || [ "$(git -C "$d" rev-parse -q --verify HEAD 2>/dev/null)" != "$ref" ]; then
        d="$TRAB/git/$n"
        if [ ! -d "$d/.git" ]; then git init -q "$d"; git -C "$d" remote add origin "$url"; fi
        if [ "$(git -C "$d" rev-parse -q --verify HEAD 2>/dev/null)" != "$ref" ]; then
            if [ -n "${SO_PASTAS[$n]:-}" ]; then
                git -C "$d" fetch -q --depth 1 --filter=blob:none origin "$ref"
                # shellcheck disable=SC2086
                git -C "$d" sparse-checkout set ${SO_PASTAS[$n]}
            else
                git -C "$d" fetch -q --depth 1 origin "$ref"
            fi
            git -C "$d" checkout -q -f "$ref"
        fi
        if [ -f "$d/.gitmodules" ] && [ -z "${SO_PASTAS[$n]:-}" ]; then
            git -C "$d" submodule -q update --init --recursive --depth 1 2>/dev/null \
                || git -C "$d" submodule -q update --init --recursive
        fi
    fi
    mkdir -p "$dest/$pasta"
    # shellcheck disable=SC2086
    git -C "$d" archive --format=tar HEAD -- ${SO_PASTAS[$n]:-.} | tar -xf - -C "$dest/$pasta"
    # submodulos: cada um no commit gravado pelo ref. "+"/"U" (outro commit no disco, conflito) = erro. "-" = nunca
    # baixado, nem pelo build (ex.: os testes de uma dependencia), entao nao entrou no binario: pula, com aviso. Nunca
    # um git -C numa pasta sem o .git do submodulo: cairia no repositorio de cima.
    git -C "$d" submodule status --recursive | while read -r h sub _r; do
        case "$h" in
            [+U]*) echo "ERRO: submodulo $n/$sub fora do commit gravado ($h)" >&2; exit 1 ;;
            -*) echo "  aviso $n/$sub: submodulo nao baixado (nao entrou no build), fora do arquivo" >&2; continue ;;
        esac
        [ -e "$d/$sub/.git" ] || { echo "ERRO: submodulo $n/$sub sem .git" >&2; exit 1; }
        mkdir -p "$dest/$pasta/$sub"
        git -C "$d/$sub" archive --format=tar HEAD | tar -xf - -C "$dest/$pasta/$sub"
    done
}

mkdir -p "$SAIDA" "$TRAB"
PATCHES_SO=""; [ "$SO" = patches-e-receitas ] && { PATCHES_SO=1; SO=""; }
COMPS=$(awk -F'|' '!/^#/ && NF==4 && $4!="-" {print $4}' "$TSV" | tr ',' '\n' | sort -u)
[ -z "$SO" ] || { echo "$COMPS" | grep -qx "$SO" || { echo "ERRO: $SO nao esta na coluna fonte de $TSV" >&2; exit 2; }; COMPS="$SO"; }
IDX="$SAIDA/FONTES.txt.novo"
[ -z "$SO" ] && { echo "# Fontes do tutu8bits $VERSAO (ports/fontes.sh). Partes .parte-NN: juntar com cat em ordem."; \
                  echo "# arquivo|componente|ref|origem|licenca|sha256|bytes"; } > "$IDX"

registrar() {   # arquivo componente
    local f=$1 n=$2 a
    if [ "$(stat -c %s "$f")" -gt "$LIMITE" ]; then
        split -b "$LIMITE" -d -a 2 "$f" "$f.parte-"
        rm "$f"
        for a in "$f".parte-*; do echo "$(basename "$a")|$n|$(campo "$n" 4)|$(campo "$n" 3)|$(campo "$n" 5)|$(sha256sum "$a" | cut -d' ' -f1)|$(stat -c %s "$a")"; done
    else
        echo "$(basename "$f")|$n|$(campo "$n" 4)|$(campo "$n" 3)|$(campo "$n" 5)|$(sha256sum "$f" | cut -d' ' -f1)|$(stat -c %s "$f")"
    fi
}

[ -n "$PATCHES_SO" ] && { [ -f "$SAIDA/FONTES.txt" ] || { echo "ERRO: sem $SAIDA/FONTES.txt (rode o fontes.sh inteiro)" >&2; exit 1; }
                         grep -v -- "-patches-e-receitas.tar.xz|" "$SAIDA/FONTES.txt" > "$IDX"; COMPS=""; }
for n in $COMPS; do
    url=$(campo "$n" 3); ref=$(campo "$n" 4)
    [ -n "$url" ] || { echo "ERRO: $n sem linha em $V" >&2; exit 1; }
    case "$n" in
        lua)   # o tarball do motor, conferido pelo src/motor/deps.sha256
            t="$REPO/.cache/motor/dl/lua-$ref.tar.gz"
            [ -f "$t" ] || "$REPO/src/motor/deps.sh" > /dev/null
            ( cd "$REPO/.cache/motor" && grep " dl/lua-$ref.tar.gz\$" "$REPO/src/motor/deps.sha256" | sha256sum --quiet -c )
            f="$SAIDA/$PRE-$n.tar.gz"; cp "$t" "$f" ;;
        stb)   # o motor usa dois cabecalhos do stb, conferidos pelo src/motor/deps.sha256
            [ -f "$REPO/.cache/motor/stb/stb_image.h" ] || "$REPO/src/motor/deps.sh" > /dev/null
            ( cd "$REPO/.cache/motor" && grep " stb/" "$REPO/src/motor/deps.sha256" | sha256sum --quiet -c )
            rm -rf "$TRAB/x"; mkdir -p "$TRAB/x/stb-${ref:0:7}"
            cp "$REPO/.cache/motor/stb/stb_image.h" "$REPO/.cache/motor/stb/stb_truetype.h" "$TRAB/x/stb-${ref:0:7}/"
            f="$SAIDA/$PRE-$n.tar.xz"; tar_det "$f" "$TRAB/x" "stb-${ref:0:7}" ;;
        *)
            case "$url" in
                *.tar.gz|*.tar.bz2|*.tar.xz)   # ref = sha256 do tarball (src/emu/build.sh, obter_tarball)
                    t="$REPO/.cache/emu/tarballs/$(basename "$url")"
                    [ -f "$t" ] || { mkdir -p "$(dirname "$t")"; curl -fsSL --retry 3 -o "$t" "$url"; }
                    echo "$ref  $t" | sha256sum --quiet -c || { echo "ERRO: sha256 diferente: $t" >&2; exit 1; }
                    f="$SAIDA/$PRE-$n.tar.${url##*.tar.}"; cp "$t" "$f" ;;
                *)
                    rm -rf "$TRAB/x"; mkdir -p "$TRAB/x"
                    extrair_git "$n" "$TRAB/x" "$n-${ref:0:7}"
                    f="$SAIDA/$PRE-$n.tar.xz"; tar_det "$f" "$TRAB/x" "$n-${ref:0:7}" ;;
            esac ;;
    esac
    linha=$(registrar "$f" "$n")
    [ -z "$SO" ] && echo "$linha" >> "$IDX"
    echo "  ok  $linha"
done

if [ -z "$SO" ]; then
    rm -rf "$TRAB/x"; mkdir -p "$TRAB/x/tutu8bits-$VERSAO-patches-e-receitas"
    git -C "$REPO" archive --format=tar HEAD -- src/emu/patches src/emu/receitas src/emu/versoes.txt ports/licencas \
        src/emu/m17_alt ports/nethack_m17 src/emu/roda_m17 ports/rogue_m17 src/emu/teclado_m17 ports/licencas.tsv \
        | tar -xf - -C "$TRAB/x/tutu8bits-$VERSAO-patches-e-receitas"
    f="$SAIDA/$PRE-patches-e-receitas.tar.xz"; tar_det "$f" "$TRAB/x" "tutu8bits-$VERSAO-patches-e-receitas"
    echo "$(basename "$f")|tutu8bits|v$VERSAO|$(sed -n 's/^TUTU_REPOSITORIO="${TUTU_REPOSITORIO:-\(.*\)}"$/\1/p' "$REPO/ports/completar_cartao.sh")|MIT; patches e interfaces: a licenca do programa onde entram|$(sha256sum "$f" | cut -d' ' -f1)|$(stat -c %s "$f")" >> "$IDX"
    mv "$IDX" "$SAIDA/FONTES.txt"
    rm -rf "$TRAB/x"
    echo "  ok  $SAIDA ($(du -sh "$SAIDA" | cut -f1), $(grep -vc '^#' "$SAIDA/FONTES.txt") arquivos)"
fi
