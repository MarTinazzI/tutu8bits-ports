# Neo Geo Pocket Color (spec 049, D-01): Beetle NeoPop, o outro candidato (decide a medida no aparelho).
RECEITA_OPCOES="platform=unix"
receita_compilar() { make -j"$NPROC" $RECEITA_OPCOES CC="$CC" CXX="$CXX" AR="$AR"; }
receita_instalar() { "$STRIP" -o "$OUT/cores/mednafen_ngp_libretro.so" mednafen_ngp_libretro.so; }
