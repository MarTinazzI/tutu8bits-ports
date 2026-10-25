# SDL2_mixer do projeto (spec 030, plano D-02): para o NXEngine-evo, que abre o mixer com OGG
# (Mix_Init(MIX_INIT_OGG)) e toca os efeitos e a musica Organya que ele mesmo sintetiza.
# So WAV, OGG (stb_vorbis embutido, sem libvorbis) e, desde a spec 047 (plano D-01), MIDI pelo Timidity
# embutido (codecs/timidity; os instrumentos GUS vem do FreePats, TIMIDITY_CFG no lancador); nada de
# FLAC/MOD/MP3/Opus/WavPack/GME, nem FluidSynth, e nenhuma biblioteca externa. Ligada contra os cabecalhos fixados do SDL2 2.28.5 e o soname
# libSDL2-2.0.so.0 (como o GameTank); em runtime usa a libSDL2 do projeto, no cartao.
MIX_CMAKE="-DSDL2MIXER_VENDORED=OFF -DSDL2MIXER_SAMPLES=OFF -DSDL2MIXER_INSTALL=OFF -DSDL2MIXER_DEPS_SHARED=OFF -DSDL2MIXER_CMD=OFF -DSDL2MIXER_FLAC=OFF -DSDL2MIXER_GME=OFF -DSDL2MIXER_MOD=OFF -DSDL2MIXER_MP3=OFF -DSDL2MIXER_MIDI=ON -DSDL2MIXER_MIDI_TIMIDITY=ON -DSDL2MIXER_MIDI_FLUIDSYNTH=OFF -DSDL2MIXER_MIDI_NATIVE=OFF -DSDL2MIXER_OPUS=OFF -DSDL2MIXER_VORBIS=STB -DSDL2MIXER_WAVE=ON -DSDL2MIXER_WAVPACK=OFF"
RECEITA_OPCOES="cmake $MIX_CMAKE"

receita_compilar() {
    rm -rf build-m17
    cmake -S . -B build-m17 -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=arm \
        -DCMAKE_C_COMPILER="$CC" -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS" \
        -DCMAKE_FIND_ROOT_PATH="$EMU_TC/$EMU_HOST/sysroot" \
        -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
        -DPKG_CONFIG_EXECUTABLE=/bin/false \
        -DSDL2_INCLUDE_DIR="$EMU_INC/SDL2" -DSDL2_LIBRARY="$EMU_LIB_CARTAO/libSDL2.so" \
        $MIX_CMAKE || return 1
    # nenhuma biblioteca ou cabecalho achado no PC
    if grep -E '(_LIBRARY|_LIB|_INCLUDE_DIR)[A-Z_]*:[A-Z]+=/usr/' build-m17/CMakeCache.txt; then return 1; fi
    cmake --build build-m17 -j"$NPROC" || return 1
}

receita_instalar() {
    mkdir -p "$OUT/sdl2_mixer"
    "$STRIP" -o "$OUT/sdl2_mixer/libSDL2_mixer-2.0.so.0" build-m17/libSDL2_mixer-2.0.so.0.*
}
