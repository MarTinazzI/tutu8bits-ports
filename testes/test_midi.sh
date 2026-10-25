#!/usr/bin/env bash
# Spec 047 (T01; plano D-01, D-10; RF-12): a SDL2_mixer do projeto toca MIDI pelo Timidity embutido, com o FreePats
# e o crude.cfg (escolha do mantenedor), no qemu-arm-static com o SDL 2.28 do aparelho:
#   1. a SDL2_mixer lista o decodificador MIDI e o programa de teste (fontes/midi_wav.c) liga so contra as libs do
#      projeto;
#   2. um MIDI gerado aqui (piano + bateria, 4 s) vira som: os 3 s gravados nao sao mudos, e o trecho da bateria
#      (canal 10) tambem soa;
#   3. o .cfg pelo TIMIDITY_CFG do ambiente (como o lancador passa ao FreeDink) tambem toca;
#   4. com um .cfg que nao existe, o Mix_LoadMUS falha com a mensagem do arquivo (nao cai).
# Conteudo: ports/baixar_conteudo.sh freepats. Nada e gravado fora de .cache/emu/testes/midi.
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
. "$D/../../src/emu/ambiente.sh"
T="$EMU_CACHE/testes/midi"
F=0
conta() { if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FALHA $2"; F=$((F + 1)); fi; }

rm -rf "$T"; mkdir -p "$T/libs" "$T/freepats"
TAR="$EMU_CACHE/conteudo/freepats/freepats_20060219.orig.tar.gz"
[ -f "$TAR" ] && tar -xzf "$TAR" -O freepats-20060219/upstream/freepats-20060219.tar.bz2 | tar -xjf - -C "$T/freepats"
CFG="$T/freepats/freepats/crude.cfg"
[ -f "$CFG" ] && [ -d "$T/freepats/freepats/Tone_000" ] && [ -d "$T/freepats/freepats/Drum_000" ]
conta $? "FreePats extraido (crude.cfg, Tone_000, Drum_000; baixar_conteudo.sh freepats)"

cp "$EMU_CACHE/out/sdl2_projeto/libSDL2-2.0.so.0" "$EMU_CACHE/out/sdl2_mixer/libSDL2_mixer-2.0.so.0" "$T/libs/"
ln -sf libSDL2_mixer-2.0.so.0 "$T/libs/libSDL2_mixer.so"
SDLCFG="$EMU_CACHE/src/sdl2_projeto/build-m17/include-config-release/SDL2/SDL_config.h"
"$CC" $CFLAGS -std=gnu99 -Wall -Werror -include "$SDLCFG" -I"$EMU_INC/SDL2" -I"$EMU_CACHE/src/sdl2_mixer/include" \
    -D_REENTRANT -o "$T/midi_wav" "$D/fontes/midi_wav.c" $LDFLAGS -L"$EMU_LIB_CARTAO" -L"$T/libs" -lSDL2_mixer -lSDL2 \
    > "$T/cc.log" 2>&1
r=$?; [ $r -eq 0 ] || cat "$T/cc.log"
conta $r "programa de teste ARM (compilador do projeto, -Werror) contra a SDL2_mixer do projeto"

# MIDI de formato 0: piano (programa 0) em do-mi-sol por 2 s e bateria (canal 10: bumbo, caixa, prato) por 2 s
python3 -I - "$T/teste.mid" <<'PY'
import struct, sys
def vlq(n):
    b = [n & 0x7f]; n >>= 7
    while n: b.insert(0, (n & 0x7f) | 0x80); n >>= 7
    return bytes(b)
ev = bytearray()
def e(dt, *bs): ev.extend(vlq(dt) + bytes(bs))
e(0, 0xff, 0x51, 3, 0x07, 0xa1, 0x20)          # 120 bpm
e(0, 0xc0, 0)                                    # piano
for n in (60, 64, 67, 72):
    e(0, 0x90, n, 100); e(240, 0x80, n, 0)       # 4 notas de meio tempo (1/4 s cada a 480 tpq)
e(0, 0x90, 60, 100); e(0, 0x90, 64, 100); e(0, 0x90, 67, 100); e(960, 0x80, 60, 0); e(0, 0x80, 64, 0); e(0, 0x80, 67, 0)
for n in (36, 38, 36, 38, 49, 36, 38, 42):
    e(0, 0x99, n, 110); e(240, 0x89, n, 0)       # bateria, 2 s
e(0, 0xff, 0x2f, 0)
trk = b"MTrk" + struct.pack(">I", len(ev)) + ev
open(sys.argv[1], "wb").write(b"MThd" + struct.pack(">IHHH", 6, 0, 1, 480) + trk)
PY
conta $? "MIDI de teste gerado (piano + bateria, 4 s)"

qemu() {   # NOME CFG [TIMIDITY_CFG] -- roda o programa no qemu; saida em $T/NOME.out/.err, som em $T/NOME.raw
    env ${3:+TIMIDITY_CFG=$3} SDL_AUDIODRIVER=disk SDL_DISKAUDIOFILE=/dev/null SDL_DISKAUDIODELAY=0 LD_LIBRARY_PATH="$T/libs" \
        timeout -k 5 120 qemu-arm-static -L "$EMU_ROOTFS" "$T/midi_wav" "$2" "$T/teste.mid" "$T/$1.raw" 4 \
        > "$T/$1.out" 2> "$T/$1.err"
}
qemu crude "$CFG"; r=$?
grep -qx 'decoder MIDI' "$T/crude.out" && grep -q '^ok: ' "$T/crude.out" && [ $r -eq 0 ]
conta $? "qemu: a SDL2_mixer lista o decodificador MIDI e toca o arquivo ($(grep '^decoder' "$T/crude.out" | cut -d' ' -f2 | tr '\n' ' '))"
# RMS (dB) dos 2 primeiros segundos (piano) e dos 2 ultimos (bateria)
python3 -I - "$T/crude.raw" > "$T/rms.txt" <<'PY'
import array, math, sys
a = array.array("h"); a.frombytes(open(sys.argv[1], "rb").read())
seg = 44100 * 2 * 2
def db(x):
    if not x: return -999.0
    return 20 * math.log10(math.sqrt(sum(v * v for v in x) / len(x)) / 32768 + 1e-12)
print("%.1f %.1f %d" % (db(a[:seg]), db(a[seg:2 * seg]), len(a)))
PY
read -r piano bateria amostras < "$T/rms.txt"
python3 -I -c 'import sys; p, b, n = map(float, sys.argv[1:]); sys.exit(0 if p > -40 and b > -40 and n >= 44100 * 2 * 4 else 1)' \
    "$piano" "$bateria" "$amostras"
conta $? "qemu: o som nao e mudo (piano ${piano} dB, bateria ${bateria} dB; 4 s gravados)"

qemu ambiente - "$CFG"; r=$?
grep -qx 'decoder MIDI' "$T/ambiente.out" && [ $r -eq 0 ] && [ "$(stat -c %s "$T/ambiente.raw")" -eq "$(stat -c %s "$T/crude.raw")" ]
conta $? "qemu: o .cfg pelo TIMIDITY_CFG do ambiente tambem toca (o caminho do FreeDink)"
qemu semcfg "$T/nao_existe.cfg"; r=$?
[ $r -eq 1 ] && grep -q "Mix_LoadMUS: Couldn't open .*nao_existe.cfg" "$T/semcfg.err"
conta $? "qemu: com um .cfg que nao existe, o Mix_LoadMUS falha com o nome do arquivo (rc 1, sem cair)"

echo "falhas: $F"
[ "$F" -eq 0 ]
