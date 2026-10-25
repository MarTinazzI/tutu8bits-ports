# Atari 7800 (spec 049, D-01, D-03): a BIOS do 7800 e opcional.
RECEITA_OPCOES="platform=unix"
receita_compilar() { make -j"$NPROC" $RECEITA_OPCOES CC="$CC" CXX="$CXX" AR="$AR"; }
receita_instalar() { "$STRIP" -o "$OUT/cores/prosystem_libretro.so" prosystem_libretro.so; }
