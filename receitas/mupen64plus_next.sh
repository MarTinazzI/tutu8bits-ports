# N64 (spec 010, plano D-02): mupen64plus-next (GLideN64) em GLES2, dynarec ARM, NEON, softfp.
RECEITA_OPCOES="platform=unix-armv-cortexa9-neon-softfloat FORCE_GLES=1 HAVE_PARALLEL_RSP=0 HAVE_PARALLEL_RDP=0 HAVE_THR_AL=0 LLE=0"
# Patch M17: cache de uniforms do glsm de 80 MB para ~2,6 MB (ports/patches/glsm_m17.py; sessao 1 da T08)
receita_compilar() { python3 "$EMU_RAIZ/ports/patches/glsm_m17.py" libretro-common/glsm/glsm.c || return 1; make -j"$NPROC" $RECEITA_OPCOES; }
receita_instalar() { "$STRIP" -o "$OUT/cores/mupen64plus_next_libretro.so" mupen64plus_next_libretro.so; }
