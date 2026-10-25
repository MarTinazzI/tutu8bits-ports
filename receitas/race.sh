# Neo Geo Pocket Color (spec 049, D-01): RACE, candidato a padrao (decide a medida no aparelho).
RECEITA_OPCOES="platform=unix"
receita_compilar() { make -j"$NPROC" $RECEITA_OPCOES CC="$CC" CXX="$CXX" AR="$AR"; }
receita_instalar() { "$STRIP" -o "$OUT/cores/race_libretro.so" race_libretro.so; }
