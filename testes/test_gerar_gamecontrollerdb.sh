#!/usr/bin/env bash
# T02 (spec 012, plano D-01): gamecontrollerdb.txt gerado do GUID + layout + keymap.json.
# Confere o formato SDL2 (elemento_sdl:fisico por posicao/rotulo), a ordem, e que entradas
# invalidas (GUID, elemento fisico, controle desconhecido) sao recusadas. Termina com "falhas: N".
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
. "$D/../../src/emu/ambiente.sh"
T="$EMU_CACHE/testes/gerar_gcdb"; rm -rf "$T"; mkdir -p "$T"
GER="$EMU_RAIZ/ports/gerar_gamecontrollerdb.py"
GUID="03000000111122223333444455556666"   # 32 hex (o real sai da captura do spike 012)
F=0
conta() { if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FALHA $2"; F=$((F + 1)); fi; }

# layout de exemplo (sera trocado pelos indices reais da captura no T06)
cat > "$T/layout.json" <<'JSON'
{ "UP": "b4", "DOWN": "b5", "LEFT": "b6", "RIGHT": "b7",
  "A": "b0", "B": "b1", "X": "b2", "START": "b3" }
JSON

LINHA="$(python3 "$GER" --guid "$GUID" --nome i2c-keys --layout "$T/layout.json")"; conta $? "gera a linha"
echo "$LINHA" > "$T/db.txt"

# começa com GUID e nome
echo "$LINHA" | grep -q "^$GUID,i2c-keys,"; conta $? "começa com GUID,nome"
# faces por posicao/rotulo
echo "$LINHA" | grep -q ",a:b0,"; conta $? "A (baixo) -> a:b0"
echo "$LINHA" | grep -q ",b:b1,"; conta $? "B (direita) -> b:b1"
echo "$LINHA" | grep -q ",x:b2,"; conta $? "X (esquerda) -> x:b2"
echo "$LINHA" | grep -q ",start:b3,"; conta $? "START -> start:b3"
# dpad
echo "$LINHA" | grep -q ",dpup:b4,"; conta $? "UP -> dpup:b4"
echo "$LINHA" | grep -q ",dpdown:b5,"; conta $? "DOWN -> dpdown:b5"
echo "$LINHA" | grep -q ",dpleft:b6,"; conta $? "LEFT -> dpleft:b6"
echo "$LINHA" | grep -q ",dpright:b7,"; conta $? "RIGHT -> dpright:b7"
# termina com platform:Linux,
echo "$LINHA" | grep -q ",platform:Linux,$"; conta $? "termina com platform:Linux,"
# nao vaza controle sem elemento (VOL nao entra)
echo "$LINHA" | grep -qv 'VOL'; conta $? "VOL+/VOL- fora do mapeamento"

# aceita eixo e hat como elemento fisico
echo '{ "UP": "h0.1", "A": "+a2" }' > "$T/lay2.json"
L2="$(python3 "$GER" --guid "$GUID" --layout "$T/lay2.json")"
echo "$L2" | grep -q ",dpup:h0.1," && echo "$L2" | grep -q ",a:+a2," ; conta $? "aceita hat e eixo"

# recusa GUID invalido
python3 "$GER" --guid "xyz" --layout "$T/layout.json" >/dev/null 2>&1; [ $? -ne 0 ]; conta $? "recusa GUID invalido"
# recusa elemento fisico invalido
echo '{ "A": "botao0" }' > "$T/lay3.json"
python3 "$GER" --guid "$GUID" --layout "$T/lay3.json" >/dev/null 2>&1; [ $? -ne 0 ]; conta $? "recusa elemento fisico invalido"
# recusa controle desconhecido
echo '{ "TURBO": "b0" }' > "$T/lay4.json"
python3 "$GER" --guid "$GUID" --layout "$T/lay4.json" >/dev/null 2>&1; [ $? -ne 0 ]; conta $? "recusa controle desconhecido"
# recusa layout vazio
echo '{}' > "$T/lay5.json"
python3 "$GER" --guid "$GUID" --layout "$T/lay5.json" >/dev/null 2>&1; [ $? -ne 0 ]; conta $? "recusa layout vazio"

# o dado medido no aparelho (spec 012, sessao 1) gera o mapeamento do produto
REAL="$(python3 "$GER" --controle "$EMU_RAIZ/ports/config/gametank_controle.json")"; conta $? "gera do gametank_controle.json"
[ "$REAL" = "19001e5a010000001200000000010000,i2c-keys,a:b6,b:b11,x:b9,dpup:b13,dpdown:b16,dpleft:b14,dpright:b15,start:b5,platform:Linux," ]
conta $? "mapeamento do i2c-keys medido (GUID e indices da captura)"
echo "$REAL" | grep -q 'back:'; [ $? -ne 0 ]; conta $? "SELECT fora do mapeamento (back abre o menu do emulador)"
python3 "$GER" >/dev/null 2>&1; [ $? -ne 0 ]; conta $? "recusa chamada sem --controle nem --guid/--layout"

# PSP (spec 023): todos os botoes + os dois analogicos (eixos nao precisam estar no keymap)
PSP="$(python3 "$GER" --controle "$EMU_RAIZ/ports/config/psp_controle.json")"; conta $? "gera do psp_controle.json"
[ "$PSP" = "19001e5a010000001200000000010000,i2c-keys,a:b6,b:b11,x:b9,y:b4,dpup:b13,dpdown:b16,dpleft:b14,dpright:b15,start:b5,back:b12,leftshoulder:b7,rightshoulder:b3,lefttrigger:b8,righttrigger:b10,leftstick:b1,rightstick:b2,leftx:a0,lefty:a1,rightx:a2,righty:a3,platform:Linux," ]
conta $? "mapeamento do PSP (botoes medidos + deduzidos, eixos a0..a3)"
# os 9 medidos na 012 sao os mesmos nos dois arquivos
for c in A B X UP DOWN LEFT RIGHT START; do
    g=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['layout']['$c'])" "$EMU_RAIZ/ports/config/gametank_controle.json")
    p=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['layout']['$c'])" "$EMU_RAIZ/ports/config/psp_controle.json")
    [ "$g" = "$p" ]; conta $? "PSP e GameTank iguais em $c ($g)"
done

# Duke 3D (spec 040): o mesmo mapeamento do PSP (analogicos e gatilhos), com arquivo proprio
DK="$(python3 "$GER" --controle "$EMU_RAIZ/ports/config/duke3d_controle.json")"; conta $? "gera do duke3d_controle.json"
[ "$DK" = "$PSP" ]; conta $? "Duke 3D com o mesmo mapeamento do PSP (botoes, gatilhos L2/R2, eixos a0..a3)"

echo "falhas: $F"
[ "$F" -eq 0 ]
