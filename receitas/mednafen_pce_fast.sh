# PC Engine (spec 049, D-01): Beetle PCE Fast, candidato a padrao (decide a medida no aparelho).
RECEITA_OPCOES="platform=unix"
receita_compilar() { make -j"$NPROC" $RECEITA_OPCOES CC="$CC" CXX="$CXX" AR="$AR"; }
receita_instalar() { "$STRIP" -o "$OUT/cores/mednafen_pce_fast_libretro.so" mednafen_pce_fast_libretro.so; }
