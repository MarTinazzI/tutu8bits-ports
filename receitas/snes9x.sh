# SNES, comparacao com o snes9x2005_plus (plano D-04).
RECEITA_OPCOES="platform=unix"
receita_compilar() { make -C libretro -j"$NPROC" $RECEITA_OPCOES CC="$CC" CXX="$CXX" AR="$AR"; }
receita_instalar() { "$STRIP" -o "$OUT/cores/snes9x_libretro.so" libretro/snes9x_libretro.so; }
