# RetroArch (plano D-01): mesmo conjunto de drivers do RetroArch de fabrica que roda no aparelho
# (gl/GLES2 + contexto mali_fbdev, udev, alsa/alsathread, rgui), o resto desligado.
# Reserva de video (1a sessao da T10: o gl nao abriu): "sdl2" pela libSDL2 (a do projeto desde a spec 053; antes a de fabrica).
# Sem o visualizador de imagens embutido: ele tomava os cartuchos .p8.png do PICO-8 (spec 010).
RA_CONF="--enable-opengles --enable-egl --enable-mali_fbdev --enable-udev --enable-alsa --enable-rgui --enable-neon --enable-floatsoftfp --enable-threads --enable-builtinzlib --enable-7zip --disable-x11 --disable-wayland --disable-kms --disable-vulkan --disable-sdl --enable-sdl2 --disable-ffmpeg --disable-networking --disable-ssl --disable-qt --disable-xmb --disable-ozone --disable-materialui --disable-freetype --disable-slang --disable-glslang --disable-spirv_cross --disable-cheevos --disable-discord --disable-v4l2 --disable-libusb --disable-oss --disable-pulse --disable-pipewire --disable-jack --disable-tinyalsa --disable-opengl1 --disable-opengl_core --disable-online_updater --disable-update_cores --disable-update_assets --disable-update_core_info --disable-systemd --disable-dbus --disable-microphone --disable-accessibility --disable-translate --disable-imageviewer"
RECEITA_OPCOES="-DM17 $RA_CONF"

receita_compilar() {
    # -DM17 liga os patches do projeto (ports/patches/retroarch-01-*: menu sem ALT, ALT+menu bloqueado, FPS no log;
    # retroarch-02-*: menu basico no jogo, "Advanced Menu" e remap por jogo, spec 025)
    # Cabecalhos fixados MENOS o zlib (posto la na spec 010 para o mupen64plus antigo): com o
    # --enable-builtinzlib, o zlib.h de la passava na frente do deps/libz e o build quebrava
    # (visto na spec 025, T04). Os mesmos cabecalhos do build de 2026-10-05, no -I global e no do GLES.
    RA_INC="$EMU_CACHE/include_retroarch"
    rm -rf "$RA_INC"; mkdir -p "$RA_INC"
    for e in "$EMU_INC"/*; do
        case "${e##*/}" in zlib.h|zconf.h) ;; *) ln -s "$e" "$RA_INC/" ;; esac
    done
    CFLAGS="${CFLAGS//-I$EMU_INC/-I$RA_INC} -DM17" CXXFLAGS="${CXXFLAGS//-I$EMU_INC/-I$RA_INC} -DM17" PKG_CONFIG=/bin/false \
    ./configure --host="$EMU_HOST" --prefix=/usr $RA_CONF \
        --with-opengles_cflags="-I$RA_INC" --with-opengles_libs="-lGLESv2"
    # Sem pkg-config, o configure acha o ALSA pelo /usr/include/alsa do PC; troca pelos cabecalhos fixados
    sed -i "s#^ALSA_CFLAGS = .*#ALSA_CFLAGS = -I$EMU_INC/alsa#" config.mk
    sed -i "s#^SDL2_CFLAGS = .*#SDL2_CFLAGS = -I$EMU_INC/SDL2 -D_REENTRANT#" config.mk
    grep -q '^HAVE_SDL2 = 1' config.mk
    ! grep -n '/usr/include\|-L/usr/lib' config.mk
    make -j"$NPROC"
}

receita_instalar() {
    "$STRIP" -o "$OUT/retroarch/retroarch" retroarch
}
