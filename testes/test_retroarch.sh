#!/usr/bin/env bash
# T02 (spec 009): RetroArch compilado — auditoria de ELF, recursos esperados, patch M17 presente
# e abertura no qemu-arm-static com drivers nulos. Nada e gravado fora de .cache/emu/testes
# (HOME e XDG_CONFIG_HOME isolados). Termina com "falhas: N".
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
. "$D/../../src/emu/ambiente.sh"
RA="$EMU_CACHE/out/retroarch/retroarch"
T="$EMU_CACHE/testes/retroarch"
F=0
conta() { if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FALHA $2"; F=$((F + 1)); fi; }

[ -x "$RA" ]; conta $? "binario existe ($RA)"
"$D/../../src/emu/testes/auditar_elf.sh" "$RA" "$EMU_LIB_CARTAO" > "$EMU_CACHE/testes/auditoria_retroarch.txt"; conta $? "auditoria de ELF (libSDL2 vem do cartao)"
"$D/../../src/emu/testes/auditar_elf.sh" "$EMU_LIB_CARTAO/libSDL2-2.0.so.0" > /dev/null 2>&1
grep -q 'NEEDED libSDL2-2.0.so.0 (cartao)' "$EMU_CACHE/testes/auditoria_retroarch.txt"; conta $? "libSDL2 de fabrica ao lado (m17emu/lib)"

rm -rf "$T"; mkdir -p "$T/home" "$T/system" "$T/saves" "$T/states"
qa() { HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config" LD_LIBRARY_PATH="$EMU_LIB_CARTAO" qemu-arm-static -L "$EMU_ROOTFS" "$RA" "$@"; }

v=$(qa --version 2>&1 | head -2 | tail -1)
case "$v" in *"1.22.2"*) r=0;; *) r=1;; esac; conta $r "versao: $v"

feat=$(qa --features 2>&1)
for f in "UDEV" "OpenGLES" "EGL" "ALSA" "7zip" "zlib" "Threads" "SDL2"; do
    echo "$feat" | grep -qE "^ +$f +- .*: yes"; conta $? "recurso $f"
done
for f in "X11" "Wayland" "KMS" "Vulkan" "FFmpeg" "Network Command"; do
    if echo "$feat" | grep -qE "^ +$f +- .*: yes"; then r=1; else r=0; fi; conta $r "sem $f"
done
TXT=$(strings "$RA")   # capturado antes: grep -q num pipe com pipefail acusa SIGPIPE do strings
grep -qx 'fbdev_mali' <<< "$TXT"; conta $? "contexto fbdev_mali compilado"
grep -q '\[M17\] quadros=.*desenhados=.*fps_desenhado=' <<< "$TXT"; conta $? "patch M17 (FPS e quadros desenhados no log) presente"
grep -q '\[M17\] menu: basico' <<< "$TXT" && grep -qx 'Advanced Menu' <<< "$TXT"; conta $? "patch M17 da 025 (menu basico e Advanced Menu) presente"
grep -q 'EGL_RED_SIZE, 5' "$EMU_CACHE/src/retroarch/gfx/drivers_context/mali_fbdev_ctx.c"; conta $? "patch M17: EGL pede RGB565 (fb de 16 bits do aparelho)"

cat > "$T/nulo.cfg" <<CFG
video_driver = "null"
audio_driver = "null"
input_driver = "null"
input_joypad_driver = "null"
menu_driver = "rgui"
config_save_on_exit = "false"
system_directory = "$T/system"
savefile_directory = "$T/saves"
savestate_directory = "$T/states"
playlist_directory = "$T/home/playlists"
CFG
timeout 120 env HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config" LD_LIBRARY_PATH="$EMU_LIB_CARTAO" \
    qemu-arm-static -L "$EMU_ROOTFS" "$RA" --config "$T/nulo.cfg" --menu --max-frames=120 --verbose \
    > "$T/log.txt" 2>&1
conta $? "qemu: abre o menu e sai com rc=0 (log: $T/log.txt)"

# SIGTERM (m17atalhos, VOL+ segurado 2 s) sai limpo: salva a SRAM, grava o FPS, rc=0 (patch M17;
# 2a sessao da T10: sem isso o RetroArch morria e nao salvava)
S="$T/sigterm"; mkdir -p "$S/home"
sed "s#$T/#$S/#g" "$T/nulo.cfg" > "$S/nulo.cfg"
ROM_SIG="${ROMS_FABRICA:-$HOME/m17/emuelec/original/sistema/roms}/gba/F-Zero - Maximum Velocity (USAEurope).zip"
if [ -f "$ROM_SIG" ]; then
    ( ulimit -c 0; HOME="$S/home" XDG_CONFIG_HOME="$S/home/.config" LD_LIBRARY_PATH="$EMU_LIB_CARTAO" exec qemu-arm-static \
        -L "$EMU_ROOTFS" "$RA" --config "$S/nulo.cfg" -L "$EMU_CACHE/out/cores/gpsp_libretro.so" "$ROM_SIG" --verbose \
        > "$S/log.txt" 2>&1 ) &
    P=$!
    # espera o jogo rodar (o historico e gravado depois que o conteudo carrega), por condicao: o "sleep 6" fixo
    # falhava no paralelo (verde* na suite da 042), com o SIGTERM chegando antes do nucleo carregar
    _i=0
    while [ $_i -lt 120 ] && kill -0 "$P" 2>/dev/null && ! grep -q 'Written to file.*content_history' "$S/log.txt"; do
        sleep 0.5; _i=$((_i + 1))
    done
    sleep 2; kill -TERM "$P"; wait "$P"; rc=$?
    [ "$rc" -eq 0 ]; conta $? "SIGTERM: sai com rc=0"
    grep -q 'Salvo com sucesso\|Saved successfully' "$S/log.txt"; conta $? "SIGTERM: SRAM salva"
    grep -q '\[M17\] quadros=' "$S/log.txt" && grep -q 'Unloading core\.\.\.' "$S/log.txt"; conta $? "SIGTERM: FPS no log e nucleo descarregado"
else
    conta 1 "SIGTERM: ROM de teste existe ($ROM_SIG)"
fi

# Comandos pelo stdin (spec 025, T01): o arnes dos testes do menu. O FIFO vai NAO bloqueante
# (stdin_nao_bloqueante.py); o enable_hotkey ganha uma tecla que ninguem aperta, senao o D-10 da 009
# le o ALT como segurado e cancela o menu; sair com um QUIT so e OK/voltar trocados, como no produto
# (e o padrao do 1.22.2: OK = MENU_B, voltar = MENU_A); a cache fica no teste (senao o .zip e descompactado na
# pasta das ROMs). Um comando por vez: varios na mesma leitura cairiam no mesmo quadro.
ra_iniciar() {   # pasta [linhas extras do cfg] -> roda o gpSP com a ROM_SIG (ou RA_ROM); fd 7 = comandos
    RD="$1"; rm -rf "$RD"; mkdir -p "$RD/home" "$RD/system" "$RD/saves" "$RD/states" "$RD/cache"
    sed "s#$T/#$RD/#g" "$T/nulo.cfg" > "$RD/c.cfg"
    printf 'stdin_cmd_enable = "true"\ninput_enable_hotkey = "f12"\nquit_press_twice = "false"\nmenu_swap_ok_cancel_buttons = "true"\ncache_directory = "%s"\n%s\n' "$RD/cache" "${2:-}" >> "$RD/c.cfg"
    mkfifo "$RD/fifo"
    ( ulimit -c 0; LC_ALL=C LANG=C HOME="$RD/home" XDG_CONFIG_HOME="$RD/home/.config" LD_LIBRARY_PATH="$EMU_LIB_CARTAO" \
        exec python3 -I "$D/stdin_nao_bloqueante.py" "$RD/fifo" qemu-arm-static -L "$EMU_ROOTFS" "$RA" \
        --config "$RD/c.cfg" -L "$EMU_CACHE/out/cores/gpsp_libretro.so" "${RA_ROM:-$ROM_SIG}" --verbose > "$RD/log.txt" 2>&1 ) &
    RP=$!
    exec 7>"$RD/fifo"
    ra_espera '\[Core\] Geometry:' 90 || return 1
    # aperto de mao: o 1o comando logo apos o Geometry se perdia com a CPU carregada (todos.sh -j);
    # so com a resposta do VERSION no log o laco esta lendo os comandos de verdade
    _ri_fim=$((SECONDS + 60))
    while [ $SECONDS -lt $_ri_fim ] && kill -0 "$RP" 2>/dev/null; do
        echo VERSION >&7; sleep 0.5
        grep -qx '1\.22\.2' "$RD/log.txt" && return 0
    done
    return 1
}
ra_espera() {    # regex [segundos] -> 0 quando a linha aparece no log
    _re_fim=$((SECONDS + ${2:-30}))
    while [ $SECONDS -lt $_re_fim ]; do
        grep -q -- "$1" "$RD/log.txt" 2>/dev/null && return 0
        kill -0 "$RP" 2>/dev/null || { grep -q -- "$1" "$RD/log.txt" 2>/dev/null; return; }
        sleep 0.2
    done
    return 1
}
ra_cmd() { for _rc_c in "$@"; do echo "$_rc_c" >&7; sleep 1; done; }
ra_fim() {       # espera sair sozinho (ate 30 s); senao TERM e falha. rc do RetroArch em RC
    _rf_fim=$((SECONDS + 30))
    while kill -0 "$RP" 2>/dev/null && [ $SECONDS -lt $_rf_fim ]; do sleep 0.2; done
    if kill -0 "$RP" 2>/dev/null; then kill -TERM "$RP"; wait "$RP"; RC=124; else wait "$RP"; RC=$?; fi
    exec 7>&-
}
if [ -f "$ROM_SIG" ]; then
    ra_iniciar "$T/comandos"; conta $? "comandos: o jogo abre com o stdin ligado (log: $RD/log.txt)"
    ra_cmd SAVE_STATE
    ra_espera '\[State\] Saving' 30; conta $? "comandos: SAVE_STATE grava o estado"
    ra_cmd QUIT; ra_fim
    [ "$RC" -eq 0 ] && grep -q 'Saved successfully' "$RD/log.txt"; conta $? "comandos: QUIT sai sozinho com rc=0 e salva a SRAM"

    # Menu basico e "Advanced Menu" (spec 025, T04/T05). A lista basica, com savestate:
    # Resume, Save State, Load State, State Slot, Controls, Restart, Quit, Advanced Menu (7 descidas)
    ra_espera_n() {   # regex n [segundos] -> 0 quando a linha aparece n vezes no log
        _rn_fim=$((SECONDS + ${3:-20}))
        while [ $SECONDS -lt $_rn_fim ]; do
            [ "$(grep -c -- "$1" "$RD/log.txt")" -ge "$2" ] && return 0
            sleep 0.2
        done
        return 1
    }
    OK=MENU_B; VOLTAR=MENU_A
    AVANCADO="MENU_DOWN MENU_DOWN MENU_DOWN MENU_DOWN MENU_DOWN MENU_DOWN MENU_DOWN $OK"
    ra_iniciar "$T/menu"; conta $? "menu: o jogo abre (log: $RD/log.txt)"
    ra_cmd MENU_TOGGLE
    ra_espera_n '\[M17\] menu: basico (8 entradas)' 1; conta $? "CA-01: o menu abre na lista basica (8 entradas)"
    # shellcheck disable=SC2086
    ra_cmd $AVANCADO
    ra_espera_n '\[M17\] menu: avancado' 1; conta $? "CA-02: Advanced Menu troca a raiz pelo menu completo"
    ra_cmd $VOLTAR
    ra_espera_n '\[M17\] menu: basico' 2; conta $? "CA-02: B na raiz do avancado volta a lista basica"
    # shellcheck disable=SC2086
    ra_cmd $AVANCADO
    ra_espera_n '\[M17\] menu: avancado' 2
    ra_cmd MENU_TOGGLE MENU_TOGGLE
    ra_espera_n '\[M17\] menu: basico' 3 && [ "$(grep -c '\[M17\] menu: avancado' "$RD/log.txt")" -eq 2 ]
    conta $? "CA-03: fechar no avancado e reabrir comeca na lista basica"
    ra_cmd MENU_DOWN $OK
    ra_espera '\[State\] Saving' 20; conta $? "RF-04: Save State da lista basica grava o estado"
    ra_cmd QUIT; ra_fim
    [ "$RC" -eq 0 ]; conta $? "menu: QUIT sai com rc=0"

    # Remap por jogo ao sair (spec 025, T06/D-06), com a pasta de remaps e o remap_save_on_exit
    # do produto. Controls = 5a entrada da lista basica; Port 1 Controls = 3a de Controls; o 1o
    # botao = 4a de Port 1 Controls (antes: Device Type, Analog to Digital, Mapped Port).
    REMAPS="$T/remaps"; rm -rf "$REMAPS"
    RCFG="input_remapping_directory = \"$REMAPS\"
remap_save_on_exit = \"true\""
    CONTROLES="MENU_DOWN MENU_DOWN MENU_DOWN MENU_DOWN $OK MENU_DOWN MENU_DOWN $OK"
    ra_iniciar "$T/remap_olhar" "$RCFG"; ra_cmd MENU_TOGGLE; ra_espera_n '\[M17\] menu: basico' 1
    # shellcheck disable=SC2086
    ra_cmd $CONTROLES QUIT; ra_fim
    grep -q '\[M17\] remap: nada a gravar (igual ao padrao)' "$RD/log.txt" && [ -z "$(find "$REMAPS" -name '*.rmp' 2>/dev/null)" ]
    conta $? "CA-08: so abrir Controls e sair nao grava remap"
    ra_iniciar "$T/remap_mexer" "$RCFG"; ra_cmd MENU_TOGGLE; ra_espera_n '\[M17\] menu: basico' 1
    # shellcheck disable=SC2086
    ra_cmd $CONTROLES MENU_DOWN MENU_DOWN MENU_DOWN MENU_RIGHT QUIT; ra_fim
    RMP=$(find "$REMAPS" -name '*.rmp' 2>/dev/null)
    [ "$(printf '%s' "$RMP" | grep -c .)" -eq 1 ] && [ "$(basename "$(dirname "$RMP")")" = gpSP ] && grep -q '\[M17\] remap: gravado o do jogo' "$RD/log.txt"
    conta $? "CA-08: mexer num botao em Controls e sair grava o remap do jogo (${RMP#$T/})"
    ra_iniciar "$T/remap_reabrir" "$RCFG"; ra_cmd QUIT; ra_fim
    grep -q '\[Remap\] Game-specific remap found' "$RD/log.txt"; conta $? "CA-08: reabrir o jogo carrega o remap sozinho"
    ROM2="$(dirname "$ROM_SIG")/007 - NightFire (USAEurope) (En Fr De).zip"
    if [ -f "$ROM2" ]; then
        RA_ROM="$ROM2" ra_iniciar "$T/remap_outro" "$RCFG"; ra_cmd QUIT; ra_fim
        ! grep -q '\[Remap\]' "$RD/log.txt" && [ "$(find "$REMAPS" -name '*.rmp' | grep -c .)" -eq 1 ]
        conta $? "CA-08: outro jogo do mesmo nucleo nao pega o remap"
    else
        conta 1 "CA-08: 2a ROM de teste existe ($ROM2)"
    fi
fi

echo "falhas: $F"
[ "$F" -eq 0 ]
