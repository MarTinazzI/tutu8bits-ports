# SNES (plano D-04): snes9x2005 com o APU do blargg ("plus"), o mais leve com audio bom.
RECEITA_OPCOES="platform=unix USE_BLARGG_APU=1"
receita_compilar() { make -j"$NPROC" $RECEITA_OPCOES CC="$CC" CXX="$CXX" AR="$AR"; }
receita_instalar() { "$STRIP" -o "$OUT/cores/snes9x2005_plus_libretro.so" snes9x2005_plus_libretro.so; }
