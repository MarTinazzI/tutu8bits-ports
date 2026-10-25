# NES (plano D-04).
RECEITA_OPCOES="platform=unix"
receita_compilar() { make -j"$NPROC" $RECEITA_OPCOES CC="$CC" CXX="$CXX" AR="$AR"; }
receita_instalar() { "$STRIP" -o "$OUT/cores/fceumm_libretro.so" fceumm_libretro.so; }
