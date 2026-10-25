#!/usr/bin/env bash
# T02 (spec 023, plano D-02): o FFmpeg minimo do PPSSPP (ports/receitas/_ffmpeg_ppsspp.sh) existe no cache
# para o submodulo atual, e ARM soft-float (o pronto do PPSSPP e hard-float) e traz os decodificadores
# e demuxers que o PSP usa. Termina com "falhas: N".
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
. "$D/../../src/emu/ambiente.sh"
. "$EMU_RAIZ/ports/receitas/_ffmpeg_ppsspp.sh"
F=0
conta() { if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FALHA $2"; F=$((F + 1)); fi; }

FONTE="$EMU_CACHE/src/ppsspp"
if [ ! -d "$FONTE/ffmpeg/.git" ] && [ ! -f "$FONTE/ffmpeg/.git" ]; then
    conta 1 "fonte do PPSSPP com o submodulo ffmpeg (src/emu/build.sh ppsspp)"
    echo "falhas: $F"; exit 1
fi
C=$(cd "$FONTE" && ffmpeg_ppsspp_dir)
[ -f "$C/pronto" ]; conta $? "cache do FFmpeg para o submodulo e a receita atuais ($(basename "$C"))"
if [ ! -f "$C/pronto" ]; then echo "falhas: $F"; exit 1; fi

TMPD=$(mktemp -d); trap 'rm -rf "$TMPD"' EXIT
for lib in avcodec avformat avutil swresample swscale; do
    a="$C/lib/lib$lib.a"
    [ -f "$a" ]; conta $? "lib$lib.a existe"
    [ -f "$a" ] || continue
    o=$(cd "$TMPD" && "$AR" t "$a" | head -n 1)
    ( cd "$TMPD" && "$AR" x "$a" "$o" )
    attr=$("$READELF" -A "$TMPD/$o")
    echo "$attr" | grep -q 'Tag_CPU_arch: v7'; conta $? "lib$lib.a: ARMv7"
    ! echo "$attr" | grep -q 'Tag_ABI_VFP_args: VFP registers'; conta $? "lib$lib.a: soft-float (sem argumentos em registradores VFP)"
    rm -f "$TMPD/$o"
done

for item in H264_DECODER MPEG4_DECODER MPEG2VIDEO_DECODER ATRAC3_DECODER ATRAC3P_DECODER AAC_DECODER MP3_DECODER \
            PCM_S16LE_DECODER PMP_DEMUXER MPEGPS_DEMUXER OMA_DEMUXER H264_PARSER MPEGAUDIO_PARSER NEON; do
    grep -q "^#define \(CONFIG\|HAVE\)_$item 1" "$C/config.h"; conta $? "config.h: $item ligado"
done
# o minimo de verdade: nada de rede, protocolos ou decodificadores fora da lista
for item in NETWORK HEVC_DECODER VP9_DECODER FILE_PROTOCOL; do
    grep -q "^#define CONFIG_$item 0" "$C/config.h"; conta $? "config.h: $item desligado"
done

echo "falhas: $F"
[ "$F" -eq 0 ]
