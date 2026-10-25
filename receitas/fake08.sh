# PICO-8 (spec 010, plano D-04): fake-08 (codigo aberto, MIT; nao e o PICO-8 oficial).
RECEITA_OPCOES="platform=unix"
receita_compilar() { make -C platform/libretro -j"$NPROC" $RECEITA_OPCOES; }
receita_instalar() { "$STRIP" -o "$OUT/cores/fake08_libretro.so" platform/libretro/fake08_libretro.so; }
