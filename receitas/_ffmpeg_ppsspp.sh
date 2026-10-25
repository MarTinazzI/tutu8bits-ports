# FFmpeg minimo do PPSSPP (spec 023, plano D-02). Carregado pelas receitas ppsspp.sh e ppsspp_sdl.sh
# (nao e um componente do versoes.txt). Compila o submodulo ffmpeg/ do proprio PPSSPP com a lista de
# decodificadores/demuxers do ffmpeg/linux_arm.sh (o que o PSP usa: video PMF h264, ATRAC3/3+, AAC, MP3),
# com o nosso toolchain soft-float (NEON), estatico. O pronto em ffmpeg/linux/armv7 e hard-float
# (Tag_ABI_VFP_args: VFP registers) e nao liga aqui.
# O resultado fica em cache por commit do submodulo + sha256 deste arquivo (o obter_fonte do build.sh
# limpa o submodulo a cada compilacao) e e copiado por cima de ffmpeg/linux/armv7.
# Uso, dentro do fonte do PPSSPP: ffmpeg_ppsspp_preparar   (precisa de EMU_*, CC e NPROC do build.sh)

FFP_OPCOES="--disable-everything --disable-shared --enable-static --enable-zlib --disable-programs \
--disable-doc --disable-avdevice --disable-avfilter --disable-filters --disable-postproc --disable-network \
--disable-protocols --disable-hwaccels --disable-encoders \
--enable-decoder=h264 --enable-decoder=mpeg4 --enable-decoder=mpeg2video --enable-decoder=mjpeg --enable-decoder=mjpegb \
--enable-decoder=aac --enable-decoder=aac_latm --enable-decoder=atrac3 --enable-decoder=atrac3p --enable-decoder=mp3 \
--enable-decoder=pcm_s16le --enable-decoder=pcm_s8 \
--enable-demuxer=h264 --enable-demuxer=m4v --enable-demuxer=mpegvideo --enable-demuxer=mpegps --enable-demuxer=mp3 \
--enable-demuxer=avi --enable-demuxer=aac --enable-demuxer=pmp --enable-demuxer=oma --enable-demuxer=pcm_s16le \
--enable-demuxer=pcm_s8 --enable-demuxer=wav \
--enable-encoder=huffyuv --enable-encoder=ffv1 --enable-encoder=mjpeg --enable-encoder=pcm_s16le --enable-muxer=avi \
--enable-parser=h264 --enable-parser=mpeg4video --enable-parser=mpegaudio --enable-parser=mpegvideo \
--enable-parser=aac --enable-parser=aac_latm"
# flags do linux_arm.sh (build_ARMv7), mais o tune do A9 e os cabecalhos fixados (zlib.h)
FFP_CFLAGS="-O3 -fasm -Wno-psabi -fno-short-enums -fno-strict-aliasing -finline-limit=300 -marm $EMU_CPU -I$EMU_INC"

ffmpeg_ppsspp_dir() {   # -> pasta do cache para o submodulo atual
    local sub chave
    sub=$(git -C ffmpeg rev-parse HEAD) || return 1
    chave=$(cat "$EMU_RAIZ/ports/receitas/_ffmpeg_ppsspp.sh" | sha256sum | cut -c1-12)
    echo "$EMU_CACHE/ffmpeg_ppsspp/${sub:0:12}-$chave"
}

ffmpeg_ppsspp_preparar() {
    local c b fonte
    c=$(ffmpeg_ppsspp_dir) || return 1
    fonte="$PWD/ffmpeg"
    if [ ! -f "$c/pronto" ]; then
        echo "  ffmpeg: compilando em $c"
        b="$c.build"
        rm -rf "$b" "$c"; mkdir -p "$b"
        # shellcheck disable=SC2086
        ( cd "$b" && "$fonte/configure" --prefix="$c" --enable-cross-compile --target-os=linux \
            --arch=arm --cpu=cortex-a9 --enable-neon --cross-prefix="$EMU_TC/bin/$EMU_HOST-" --cc="$CC" \
            --extra-cflags="$FFP_CFLAGS" --extra-ldflags="-L$EMU_LIBS" --extra-libs="-lgcc" \
            $FFP_OPCOES ) || return 1
        make -C "$b" -j"$NPROC" || return 1
        make -C "$b" install || return 1
        cp "$b/config.h" "$c/config.h" || return 1
        rm -rf "$b"
        : > "$c/pronto"
    fi
    rm -rf ffmpeg/linux/armv7/include ffmpeg/linux/armv7/lib
    mkdir -p ffmpeg/linux/armv7
    cp -r "$c/include" "$c/lib" ffmpeg/linux/armv7/ || return 1
    rm -rf ffmpeg/linux/armv7/lib/pkgconfig
    echo "  ffmpeg: $(basename "$c") -> ffmpeg/linux/armv7"
}
