#!/usr/bin/env bash
# Spec 010 (T01-T05): nucleos e programas do lote 2. Para cada um: auditoria de ELF e execucao
# no qemu-arm-static com o nosso RetroArch e drivers nulos.
#   esperado: carrega = o nucleo inicia e carrega o jogo ("Geometry:" no log); o video por
#             hardware (PSP, N64) nao existe no qemu, entao o que vem depois nao e conferido aqui
#             imagem   = roda N quadros e a captura tem imagem (nucleos de video por software)
#             sem_captura = roda, mas o nucleo nao desenha com o video nulo (avisado pelo RetroArch
#             que o video esta desligado): desenhados=0, como o snes9x2005_plus na 009
# ROMs fora do repositorio. Nada e gravado fora de .cache/emu/testes. Uso: test_lote2.sh [nucleo...]
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
. "$D/../../src/emu/ambiente.sh"
MAN="${ROMS_MANTENEDOR:-$HOME/m17/roms}"
FAB="${ROMS_FABRICA:-$HOME/m17/emuelec/original/sistema/roms}"
T="$EMU_CACHE/testes/lote2"
RA="$EMU_CACHE/out/retroarch/retroarch"
TELAS="$EMU_CACHE/telas/010"   # spec 053 (D-09): regeneradas a cada suite, fora do git
F=0
conta() { if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FALHA $2"; F=$((F + 1)); fi; }

# nucleo|rom|quadros|esperado
LISTA="ppsspp|$MAN/psp/Indiana Jones and the Staff of Kings.iso|300|carrega
mupen64plus_next|$MAN/n64/Conker's Bad Fur Day (USA).z64|300|carrega
parallel_n64|$MAN/n64/Conker's Bad Fur Day (USA).z64|300|carrega
mupen64plus|$FAB/n64/Super Smash Bros. (USA).n64|300|carrega
fbneo|$FAB/arcade/mslug.zip|1200|sem_captura
fbneo|$FAB/fbneo/ddsom.zip|1200|sem_captura
mame2003_plus|$FAB/arcade/dino.zip|1200|imagem
mame2003_plus|$FAB/arcade/dkong.zip|600|imagem
fake08|$EMU_CACHE/conteudo/pico8/celeste.p8.png|900|imagem"

mkdir -p "$TELAS"
ulimit -c 0
SEL=" $* "
while IFS='|' read -r n rom q esp; do
    [ -n "$n" ] || continue
    [ $# -eq 0 ] || case "$SEL" in *" $n "*) ;; *) continue;; esac
    so="$EMU_CACHE/out/cores/${n}_libretro.so"
    "$D/../../src/emu/testes/auditar_elf.sh" "$so" > /dev/null 2>&1; conta $? "$n: auditoria de ELF"
    if [ ! -f "$rom" ]; then conta 1 "$n: ROM existe ($rom)"; continue; fi
    tag=$(basename "$rom" | sed 's/\.[^.]*$//' | tr -c 'A-Za-z0-9' '_' | cut -c1-20)
    d="$T/$n-$tag"; rm -rf "$d"; mkdir -p "$d/home" "$d/system"
    [ -d "$EMU_CACHE/out/system" ] && cp -r "$EMU_CACHE/out/system/." "$d/system/"
    cat > "$d/nulo.cfg" <<CFG
video_driver = "null"
audio_driver = "null"
input_driver = "null"
input_joypad_driver = "null"
config_save_on_exit = "false"
system_directory = "$d/system"
savefile_directory = "$d"
savestate_directory = "$d"
playlist_directory = "$d/home"
cache_directory = "$d"
screenshot_directory = "$d"
core_options_path = "$d/opcoes.cfg"
global_core_options = "true"
CFG
    cp "$EMU_RAIZ/cartao/tutu8bits/retroarch/config/retroarch-core-options.cfg" "$d/opcoes.cfg"
    HOME="$d/home" XDG_CONFIG_HOME="$d/home/.config" LD_LIBRARY_PATH="$EMU_LIB_CARTAO" timeout 300 \
        qemu-arm-static -L "$EMU_ROOTFS" "$RA" --config "$d/nulo.cfg" -L "$so" "$rom" \
        --max-frames="$q" --max-frames-ss --max-frames-ss-path="$d/tela.png" --verbose > "$d/log.txt" 2>&1
    rc=$?
    case "$esp" in
        carrega)
            grep -q 'Geometry:' "$d/log.txt"; conta $? "$n: inicia e carrega '$(basename "$rom")' (rc=$rc; o video por hardware fica para o aparelho)" ;;
        sem_captura)
            conta $rc "$n: roda $q quadros de '$(basename "$rom")'"
            grep -q 'No missing files\|Geometry:' "$d/log.txt"; conta $? "$n: carregou o jogo (sem arquivos faltando)"
            grep -q '\[M17\].* desenhados=0 ' "$d/log.txt"; conta $? "$n: desenhados=0 com video nulo, como esperado" ;;
        imagem)
            conta $rc "$n: roda $q quadros de '$(basename "$rom")'"
            if [ -s "$d/tela.png" ]; then cp "$d/tela.png" "$TELAS/qemu_${n}_$tag.png"; conta 0 "$n: captura em .cache/emu/telas/010/qemu_${n}_$tag.png"
            else conta 1 "$n: captura gerada"; fi ;;
    esac
done <<< "$LISTA"
# GameTank (programa proprio com SDL2; spec 012): auditoria com a libSDL2 do cartao; no qemu com o
# SDL "dummy" (--softrender: o dummy nao tem renderer acelerado; no aparelho fica o acelerado do
# mali), SEM --nojoystick e com o mapeamento de game controller (gamecontrollerdb, gerado do
# GUID+layout+keymap.json), sem X11; SIGTERM depois de 8 s tem de sair limpo (rc=0), que e o caminho
# do m17atalhos (VOL+ segurado 2 s).
if [ $# -eq 0 ] || case "$SEL" in *" gametank "*) true ;; *) false ;; esac; then
    GT="$EMU_CACHE/out/gametank/GameTankEmulator"
    "$D/../../src/emu/testes/auditar_elf.sh" "$GT" "$EMU_LIB_CARTAO" > /dev/null 2>&1; conta $? "gametank: auditoria de ELF (libSDL2 do cartao)"
    "$READELF" -d "$GT" 2>/dev/null | grep -qiE 'libX11|libxcb|libwayland'; [ $? -ne 0 ]; conta $? "gametank: sem X11/XCB/Wayland"
    d="$T/gametank"; rm -rf "$d"; mkdir -p "$d/home"
    # mapeamento de game controller (GUID/layout de exemplo; o real sai da captura do spike 012)
    echo '{ "UP":"b4","DOWN":"b5","LEFT":"b6","RIGHT":"b7","A":"b0","B":"b1","X":"b2","START":"b3" }' > "$d/layout.json"
    python3 "$EMU_RAIZ/ports/gerar_gamecontrollerdb.py" --guid 03000000111122223333444455556666 \
        --layout "$d/layout.json" --saida "$d/gamecontrollerdb.txt"; conta $? "gametank: gamecontrollerdb gerado"
    grep -q ',a:b0,.*,dpup:b4,.*platform:Linux,$' "$d/gamecontrollerdb.txt"; conta $? "gametank: mapeamento SDL (a:b0 ... dpup:b4 ... platform:Linux)"
    ROM_GT="$EMU_CACHE/src/gametank/roms/tetris.gtr"
    ( cd "$d" && exec env HOME="$d/home" XDG_DATA_HOME="$d/home" SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
        SDL_GAMECONTROLLERCONFIG_FILE="$d/gamecontrollerdb.txt" \
        LD_LIBRARY_PATH="$EMU_LIB_CARTAO" qemu-arm-static -L "$EMU_ROOTFS" "$GT" --softrender "$ROM_GT" \
        > "$d/log.txt" 2>&1 ) &
    P=$!
    sleep 8
    kill -0 "$P" 2>/dev/null; conta $? "gametank: roda o tetris.gtr por 8 s (sem --nojoystick)"
    kill -TERM "$P"; wait "$P"; rc=$?
    [ "$rc" -eq 0 ]; conta $? "gametank: SIGTERM sai limpo (rc=$rc)"
    grep -q '^loading .*tetris.gtr' "$d/log.txt"; conta $? "gametank: carregou a ROM"
    grep -qiE 'x11|xcb|cannot open display' "$d/log.txt"; [ $? -ne 0 ]; conta $? "gametank: nao tentou X11 em runtime"
fi

echo "falhas: $F"
[ "$F" -eq 0 ]
