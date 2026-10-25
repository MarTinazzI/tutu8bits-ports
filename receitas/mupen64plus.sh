# N64, nucleo antigo (spec 010, sessao 1 da T08): mupen64plus-libretro (2019), da epoca do RetroArch
# de fabrica (1.7.4), que rodava N64 neste aparelho; GLideN64 antigo em GLES2, dynarec ARM, NEON.
# Patch M17: cache de uniforms do glsm de 80 MB para ~2,6 MB (ports/patches/glsm_m17.py).
RECEITA_OPCOES="platform=unix FORCE_GLES=1 WITH_DYNAREC=arm ARCH=arm HAVE_NEON=1 CPUFLAGS=-DARM_-marm"
receita_compilar() {
    python3 "$EMU_RAIZ/ports/patches/glsm_m17.py" custom/glsm/glsm.cpp || return 1
    # o gl2ext.h atual define GLdouble no bloco GL_NV_path_rendering e conflita com o glsm antigo;
    # definir a macro faz o cabecalho pular esse bloco (extensao que o N64 nao usa)
    # codigo de 2019 com o gcc 12: faltam #include <string>/<cstdint>/<stdexcept> (-include) e ha
    # variaveis globais definidas em dois arquivos (o gcc 10+ usa -fno-common por padrao: -fcommon)
    CFLAGS="$CFLAGS -DGL_NV_path_rendering=1 -fcommon" CXXFLAGS="$CXXFLAGS -DGL_NV_path_rendering=1 -include string -include cstdint -include stdexcept" make -j"$NPROC" platform=unix FORCE_GLES=1 WITH_DYNAREC=arm ARCH=arm HAVE_NEON=1 CPUFLAGS="-DARM -marm"
}
receita_instalar() { "$STRIP" -o "$OUT/cores/mupen64plus_libretro.so" mupen64plus_libretro.so; }
