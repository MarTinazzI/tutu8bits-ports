#!/usr/bin/env bash
# T07 (spec 009, plano D-07/D-10): retroarch.cfg gerado do keymap.json.
# Confere cada botao contra o keymap (mapa por posicao), os atalhos (so ALT e MENU), os
# caminhos no cartao, e que o RetroArch (qemu) aceita o arquivo: ele o carrega e o regrava
# (config_save_on_exit numa copia), e cada chave nossa tem de voltar com o mesmo valor —
# chave com nome errado sumiria ou voltaria com o padrao. Termina com "falhas: N".
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
. "$D/../../src/emu/ambiente.sh"
T="$EMU_CACHE/testes/gerar_cfg"; rm -rf "$T"; mkdir -p "$T/home" "$T/raiz"
F=0
conta() { if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FALHA $2"; F=$((F + 1)); fi; }
val() { sed -n "s/^$1 = \"\(.*\)\"$/\1/p" "$2" | tail -1; }

CFG="$T/retroarch.cfg"
python3 "$EMU_RAIZ/ports/gerar_cfg.py" --raiz "$T/raiz" --saida "$CFG"; conta $? "gera o cfg"

# botoes: RetroPad <- keycode do keymap.json (por posicao)
KM="$EMU_RAIZ/ports/config/keymap.json"
km() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' "$KM" "$1"; }
declare -A NOME=([19]=r [21]=y [28]=enter [30]=a [38]=l [44]=z [45]=x [46]=c [48]=b [54]=rshift
                 [103]=up [105]=left [106]=right [108]=down [114]=volumedown [115]=volumeup)
for par in b:A a:B y:X x:Y l:L1 r:R1 l2:L2 r2:R2 select:SELECT start:START up:UP down:DOWN left:LEFT right:RIGHT; do
    rp=${par%%:*}; ac=${par#*:}; esp=${NOME[$(km "$ac")]}
    [ "$(val "input_player1_$rp" "$CFG")" = "$esp" ]; conta $? "RetroPad $rp <- $ac ($(km "$ac") = $esp)"
done
[ "$(val input_player1_l3 "$CFG")" = nul ] && [ "$(val input_player1_r3 "$CFG")" = nul ]
conta $? "L3/R3 (BTN_*) sem tecla de teclado: nul"
[ "$(val input_player1_b "$CFG")" = a ]; conta $? "botao de baixo (rotulo A, 30) = B do RetroPad"

[ "$(val input_enable_hotkey "$CFG")" = volumedown ]; conta $? "ALT = VOL- (input_enable_hotkey)"
[ "$(val input_menu_toggle "$CFG")" = volumeup ]; conta $? "MENU = VOL+ (input_menu_toggle)"
[ "$(val input_save_state "$CFG")" = "${NOME[$(km A)]}" ]; conta $? "ALT + A = salvar estado ($(val input_save_state "$CFG"))"
[ "$(val input_load_state "$CFG")" = "${NOME[$(km B)]}" ]; conta $? "ALT + B = carregar estado ($(val input_load_state "$CFG"))"
[ "$(val input_state_slot_increase "$CFG")" = "${NOME[$(km R1)]}" ]; conta $? "ALT + R1 = proximo slot ($(val input_state_slot_increase "$CFG"))"
[ "$(val input_state_slot_decrease "$CFG")" = "${NOME[$(km L1)]}" ]; conta $? "ALT + L1 = slot anterior ($(val input_state_slot_decrease "$CFG"))"
[ "$(val input_screenshot "$CFG")" = "${NOME[$(km Y)]}" ]; conta $? "ALT + Y = captura de tela ($(val input_screenshot "$CFG"))"
[ "$(val video_gpu_screenshot "$CFG")" = false ]; conta $? "captura do quadro cru (video_gpu_screenshot = false)"
n=$(grep -E '^input_[a-z0-9_]+ = ' "$CFG" | grep -v '^input_player\|^input_enable_hotkey\|^input_menu_toggle\|^input_save_state\|^input_load_state\|^input_state_slot_increase\|^input_state_slot_decrease\|^input_screenshot\|^input_driver\|^input_joypad_driver\|^input_autodetect\|^input_hotkey_block\|^input_remapping' | grep -vc '"nul"')
[ "$n" -eq 0 ]; conta $? "todos os outros atalhos = nul (sobraram $n)"
! grep -q '@RAIZ@' "$CFG"; conta $? "caminhos resolvidos (@RAIZ@ trocado)"
[ "$(val savefile_directory "$CFG")" = "$T/raiz/saves" ]; conta $? "saves no cartao"

# o RetroArch aceita e regrava: cada chave volta igual
# o RetroArch ignora savefile/savestate/screenshot_directory se a pasta nao existir (o
# preparar_cartao.sh cria todas): aqui tambem
for d in saves states screenshots system cache cores roms config/playlists config/remaps config/autoconfig config/assets; do
    mkdir -p "$T/raiz/$d"
done
SALVO="$T/salvo.cfg"
cp "$CFG" "$SALVO"
cat > "$T/nulo.cfg" <<CFG
video_driver = "null"
audio_driver = "null"
input_driver = "null"
input_joypad_driver = "null"
config_save_on_exit = "true"
CFG
HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config" LD_LIBRARY_PATH="$EMU_LIB_CARTAO" timeout 120 qemu-arm-static -L "$EMU_ROOTFS" \
    "$EMU_CACHE/out/retroarch/retroarch" --config "$SALVO" --appendconfig "$T/nulo.cfg" \
    --menu --max-frames=30 --verbose > "$T/log.txt" 2>&1
conta $? "RetroArch abre com o cfg (qemu)"
falt=0
while IFS= read -r l; do
    k=${l%% = *}
    case "$k" in video_driver|audio_driver|input_driver|input_joypad_driver|config_save_on_exit) continue;; esac
    [ "$(val "$k" "$SALVO")" = "$(val "$k" "$CFG")" ] || { echo "      chave diferente ao regravar: $k ($(val "$k" "$CFG") -> $(val "$k" "$SALVO"))"; falt=$((falt + 1)); }
done < <(grep -E '^[a-z0-9_]+ = ' "$CFG")
[ "$falt" -eq 0 ]; conta $? "todas as $(grep -cE '^[a-z0-9_]+ = ' "$CFG") chaves aceitas e regravadas iguais"

echo "falhas: $F"
[ "$F" -eq 0 ]
