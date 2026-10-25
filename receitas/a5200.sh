# Atari 5200 (spec 049, D-01, D-03): sem o 5200.rom em bios/, usa o Altirra OS embutido.
RECEITA_OPCOES="platform=unix"
receita_compilar() { make -j"$NPROC" $RECEITA_OPCOES CC="$CC" CXX="$CXX" AR="$AR"; }
receita_instalar() { "$STRIP" -o "$OUT/cores/a5200_libretro.so" a5200_libretro.so; }
