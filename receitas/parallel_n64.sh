# N64, comparacao (spec 010/015): parallel-n64 em GLES2. Plugins GLES2 LEVES (gln64/glide64/rice) para
# a PowerVR SGX; o GLideN64 pesado nao desenha certo neste GLES2 (spec 015, sessao 1).
# Dieta de memoria (spec 015, T07a): HAVE_THR_AL NAO pode ser 0 (o angrylion e dependencia de link
# obrigatoria do HLE/RDP). Em vez disso, o patch n64mem_m17.py ENCOLHE 3 buffers estaticos que nao
# servem ao nosso uso: disco do 64DD (67 MB), workers do angrylion (35 MB) e a textura do glide2gl
# (32 MB). Com isso o BSS cai de ~206 MB para caber em 256 MB. HAVE_PARALLEL*/RSP ja desligados.
# dynarec ARM, NEON, softfp (perfil Cortex-A9 webOS), com as opcoes de CPU do projeto (ambiente.sh).
RECEITA_OPCOES="platform=unix FORCE_GLES=1 GLES=1 GL_LIB=-lGLESv2 WITH_DYNAREC=arm HAVE_NEON=1 HAVE_PARALLEL=0 HAVE_PARALLEL_RSP=0 CPUFLAGS=-DARM_-D__arm__-D__NEON_OPT_-DNOSSE_-marm"
# Patches M17: glsm (cache de uniforms 80 MB -> 2,6 MB) + n64mem (dieta de 134 MB; spec 015).
receita_compilar() {
    python3 "$EMU_RAIZ/ports/patches/glsm_m17.py" libretro-common/glsm/glsm.c || return 1
    python3 "$EMU_RAIZ/ports/patches/n64mem_m17.py" . || return 1
    # DIAGNOSTICO do analogico (spec 015, remover depois): loga os eixos crus
    [ -n "${N64_ANALOG_DIAG:-}" ] && { python3 "$EMU_RAIZ/ports/patches/n64analog_diag_m17.py" . || return 1; }
    make -j"$NPROC" platform=unix FORCE_GLES=1 GLES=1 GL_LIB=-lGLESv2 WITH_DYNAREC=arm HAVE_NEON=1 \
        HAVE_PARALLEL=0 HAVE_PARALLEL_RSP=0 CPUFLAGS="-DARM -D__arm__ -D__NEON_OPT -DNOSSE -marm"
}
receita_instalar() { "$STRIP" -o "$OUT/cores/parallel_n64_libretro.so" parallel_n64_libretro.so; }
