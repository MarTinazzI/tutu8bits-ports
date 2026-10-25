#!/usr/bin/env bash
# T05/T06 (spec 023, candidato B): o PPSSPP standalone do projeto (ppsspp_sdl/PPSSPPSDLTUTU).
# - ELF: so bibliotecas do aparelho ou do cartao (libSDL2), soft-float, sem X11/glslang/SPIRV
#   (o de fabrica liga libX11/libXext/libglslang) e com o FFmpeg estatico;
# - o patch da velocidade (ppsspp-m17-01-fps) e o --state=ARQ do arnes;
# - no qemu: --help roda; com uma ISO e o video "dummy" (sem GL) o memory stick vai para
#   $XDG_CONFIG_HOME/ppsspp (plano D-11; no Linux o PPSSPP nao le memstick_dir.txt), os assets ao
#   lado do programa sao registrados, e o programa SAI sozinho (nao prende sem video; P4).
# O SIGTERM -> SDL_QUIT -> fechamento limpo e o ALT+A/B nao rodam no qemu (sem GL o jogo nao inicia):
# ficam para o aparelho (T18). Termina com "falhas: N".
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
. "$D/../../src/emu/ambiente.sh"
F=0
conta() { if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FALHA $2"; F=$((F + 1)); fi; }

B="$EMU_CACHE/out/ppsspp_sdl/PPSSPPSDLTUTU"
SDL="$EMU_CACHE/out/sdl2_projeto/libSDL2-2.0.so.0"
ISO="${ROMS_MANTENEDOR:-$HOME/m17/roms}/psp/Indiana Jones and the Staff of Kings.iso"
if [ ! -f "$B" ]; then conta 1 "standalone existe ($B)"; echo "falhas: $F"; exit 1; fi

"$D/../../src/emu/testes/auditar_elf.sh" "$B" "$EMU_LIB_CARTAO" > /dev/null 2>&1; conta $? "auditoria de ELF (libSDL2 do cartao)"
DIN=$("$READELF" -d "$B")
! grep -qiE 'libX11|libXext|libxcb|libwayland|libglslang|libSPIRV|libav|libsw' <<< "$DIN"; conta $? "sem X11/Wayland/glslang/SPIRV e FFmpeg estatico"
grep -q 'libSDL2-2.0.so.0' <<< "$DIN"; conta $? "liga a libSDL2 (soname do cartao)"
! grep -q 'Tag_ABI_VFP_args: VFP registers' <<< "$("$READELF" -A "$B")"; conta $? "soft-float"
TXT=$(strings "$B")
grep -q '^\[M17\] %s vps=%.2f fps=%.2f desenhado=%.2f segundos=%.1f' <<< "$TXT"; conta $? "patch ppsspp-m17-01-fps"
grep -q '^Lavf[0-9]' <<< "$TXT"; conta $? "FFmpeg (libavformat) dentro do programa"
grep -q '^\[M17\] GL: tentando cor %d/%d/%d, profundidade %d, stencil %d' <<< "$TXT"; conta $? "patch ppsspp_sdl-m17-02-cor565 (configs 565 do EGL da SGX540; sessao 1)"
grep -q "^ppsspp_sdl/PPSSPPSDLTUTU|$(sha256sum "$B" | cut -d' ' -f1)|.*|ppsspp_sdl|[0-9a-f]\{40\}|GPL-2.0+|.*-DUSING_EGL=OFF" "$EMU_RAIZ/ports/manifesto.txt"
conta $? "manifesto com o sha256, ref, licenca e USING_EGL=OFF"

T="$EMU_CACHE/testes/ppsspp_sdl"; rm -rf "$T"; mkdir -p "$T/pp" "$T/xdg" "$T/home" "$T/lib"
cp "$B" "$T/pp/"; cp -r "$EMU_CACHE/out/system/PPSSPP" "$T/pp/assets"; cp "$SDL" "$T/lib/"
ulimit -c 0
LD_LIBRARY_PATH="$T/lib" timeout 60 qemu-arm-static -L "$EMU_ROOTFS" "$T/pp/PPSSPPSDLTUTU" --help > "$T/help.txt" 2>&1
conta $? "qemu: --help roda"
grep -q -- '--state=FILE' "$T/help.txt"; conta $? "aceita --state=ARQ (cena de jogo do arnes, D-06)"

if [ ! -f "$ISO" ]; then conta 1 "ISO de teste existe ($ISO)"; else
    mkdir -p "$T/xdg/ppsspp/PSP/SYSTEM"
    cp "$EMU_RAIZ/cartao/tutu8bits/opcoes/psp.ini" "$T/xdg/ppsspp/PSP/SYSTEM/ppsspp.ini"
    cp "$EMU_RAIZ/cartao/tutu8bits/opcoes/psp_controls.ini" "$T/xdg/ppsspp/PSP/SYSTEM/controls.ini"
    ( cd "$T/pp" && exec env HOME="$T/home" XDG_CONFIG_HOME="$T/xdg" SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
        LD_LIBRARY_PATH="$T/lib" timeout 90 qemu-arm-static -L "$EMU_ROOTFS" ./PPSSPPSDLTUTU \
        --fullscreen --escape-exit --pause-menu-exit "$ISO" ) > "$T/log.txt" 2>&1
    rc=$?
    [ "$rc" -ne 124 ]; conta $? "sem video (dummy): sai sozinho, nao prende (rc=$rc)"
    for p in SYSTEM SAVEDATA PPSSPP_STATE; do
        [ -d "$T/xdg/ppsspp/PSP/$p" ]; conta $? "memory stick em \$XDG_CONFIG_HOME/ppsspp/PSP/$p"
    done
    # o PPSSPP registra o caminho resolvido (com links simbolicos no caminho, ex.: .cache ligado, eles diferem)
    _tr=$(cd "$T" && pwd -P)
    grep -q -e "Registered VFS for prefix : $T/pp/assets\$" -e "Registered VFS for prefix : $_tr/pp/assets\$" "$T/log.txt"
    conta $? "assets ao lado do programa registrados"
    ! grep -qiE 'XOpenDisplay|cannot open display|libX11' "$T/log.txt"; conta $? "nao tentou X11 em runtime"
fi

echo "falhas: $F"
[ "$F" -eq 0 ]
