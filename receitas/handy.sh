# Atari Lynx (spec 049, D-01, D-03): sem o lynxboot.img em bios/, a BIOS e emulada (HLE).
RECEITA_OPCOES="platform=unix"
receita_compilar() { make -j"$NPROC" $RECEITA_OPCOES CC="$CC" CXX="$CXX" AR="$AR"; }
receita_instalar() { "$STRIP" -o "$OUT/cores/handy_libretro.so" handy_libretro.so; }
